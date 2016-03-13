Param(  
    # Name of the subscription to use for azure cmdlets
    $subscriptionName = "stephgou - External",
    $subscriptionId = "fb79eb46-411c-4097-86ba-801dca0ff5d5",
    #Paramètres du Azure Ressource Group
    $resourceGroupName = "az-Kubernetes-VM-Cluster",
    $resourceLocation = "West Europe",
    $coreOSImageName = "CoreOs:CoreOS:Beta:899.6.0",
    $publisherName = "CoreOS",
    $offerName = "CoreOS",
    $skuName ="Beta",
    $skuVersion = "899.6.0",
    $prefix = "az-Kubernetes",
    $domainNameLabel = "azkubernetes",
    $frontendSubnet = "frontendSubnet",
    $vnetAddressPrefix = "172.16.0.0/12",
    $subnetAddressPrefix = "172.16.0.0/24",
    $dnsServer = "8.8.8.8",
    $etcd_node = 2,
    $kub_node = 3,
    $diskName="OSDisk",
    $storageAccountName = "vmkubernetes",
    $tagName = "Kubernetes_RG",
    $tagValue = "VM-Cluster"
    )

#region init
Set-PSDebug -Strict
$ErrorActionPreference = “Stop”

cls
$d = get-date
Write-Host "Starting Deployment $d"

$scriptFolder = Split-Path -Parent $MyInvocation.MyCommand.Definition
Write-Host "scriptFolder" $scriptFolder

set-location $scriptFolder
#endregion init

#Login-AzureRmAccount -SubscriptionId $subscriptionId

# Resource group create
New-AzureRmResourceGroup `
	-Name $resourceGroupName `
	-Location $resourceLocation `
    -Tag @{Name=$tagName;Value=$tagValue} `
    -Verbose

#region credentials
#$sshkey = New-AzureSSHKey -PublicKey -Path 'C:\DEV\keys\idrsa.pub'
$username = "devops"
$password = "VeL0c1RaPt0R#" | ConvertTo-SecureString -AsPlainText -Force
$credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $password 
#endregion credentials

# create availabilitySets
$etcdAS = New-AzureRmAvailabilitySet -Name $prefix-av-etcd -ResourceGroupName $resourceGroupName -Location $resourceLocation
$kubAS = New-AzureRmAvailabilitySet -Name $prefix-av-kub -ResourceGroupName $resourceGroupName -Location $resourceLocation

# create storageAccount
$storageAccount = New-AzureRmStorageAccount -AccountName $storageAccountName -ResourceGroupName $resourceGroupName `
    -Location $resourceLocation -Type “Standard_LRS”
$storageAccount=Get-AzureRmStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName

$osDiskUri = $storageAccount.PrimaryEndpoints.Blob.ToString() + "vhds/" + $diskName  + ".vhd"

#-------------------------------------------------- Network -----------------------------------------
# create vnet
$subnet = New-AzureRmVirtualNetworkSubnetConfig -Name $frontendSubnet -AddressPrefix $subnetAddressPrefix
$vnet = New-AzureRmVirtualNetwork -Name $prefix-vnet -ResourceGroupName $resourceGroupName -Location $resourceLocation `
         -AddressPrefix $vnetAddressPrefix -DnsServer $dnsServer -Subnet $subnet
#subnet value is updated with data related to vnet so it is required to get it back
$subnet = Get-AzureRmVirtualNetworkSubnetConfig -Name $subnet.Name -VirtualNetwork $vnet

# create Public IP
$pipetcd = New-AzureRmPublicIpAddress -Name $prefix-pip-etcd  -ResourceGroupName $resourceGroupName `
        -Location $resourceLocation -AllocationMethod Dynamic -DomainNameLabel $domainNameLabel-etcd 

# create front-ip etc / kub 
$fipetcd = New-AzureRmLoadBalancerFrontendIpConfig -Name $prefix-fip-etcd -PublicIpAddress $pipetcd

# create inbound nat rule for etcd  / ssh 

$etcdInboundNATRules = @()

for($i=0; $i -le $etcd_node-1; $i++)
{
    $inboundNatRuleName = "ssh-etcd" + $i
    $frontendPort = [convert]::ToInt32(2200+$i,10)

    $etcdInboundNATRule = New-AzureRmLoadBalancerInboundNatRuleConfig -Name $inboundNatRuleName `
         -FrontendIpConfiguration $fipetcd `
         -Protocol TCP -FrontendPort $frontendPort -BackendPort 22
    $etcdInboundNATRules += $etcdInboundNATRule
}

# Create Load balancer
$lbetcd = New-AzureRmLoadBalancer -Name $prefix-lb-etcd -ResourceGroupName $resourceGroupName `
    -Location $resourceLocation -FrontendIpConfiguration $fipetcd `
    -InboundNatRule $etcdInboundNATRules #[0], $etcdInboundNATRules[1] #,$etcdInboundNATRules[2]

$bpetcd = New-AzureRmLoadBalancerBackendAddressPoolConfig -Name $prefix-bp-etcd

#$lbetcd | Add-AzureRmLoadBalancerBackendAddressPoolConfig -Name $bpetcd.Name | Set-AzureRmLoadBalancer 
#empty id on lbetcd properties - It is required to call the Get-AzureRmLoadBalancer to have a full lbetcd
$ConfNull =  Add-AzureRmLoadBalancerBackendAddressPoolConfig -LoadBalancer $lbetcd -Name $bpetcd.Name | Set-AzureRmLoadBalancer 
$lbetcd = Get-AzureRmLoadBalancer | where { $_.Name -eq $lbetcd.Name}
$bpetcdConfig = $lbetcd.BackendAddressPools[0]
$etcdInboundNATRules = $lbetcd.InboundNatRules

# create etcd nics and virtual machines
Write-Host "create etcd nics and Vm"
for($i=0; $i -le $etcd_node-1; $i++)
{
    $nic = New-AzureRmNetworkInterface -Name $prefix-nic-etcd-$i -ResourceGroupName $resourceGroupName `
        -Location $resourceLocation -Subnet $subnet `
        -LoadBalancerBackendAddressPool $bpetcdConfig `
        -LoadBalancerInboundNatRule $etcdInboundNATRules[$i]

    $vmName = "$prefix-etcd-$i"
    $vm = New-AzureRmVMConfig -VMName $vmName -VMSize standard_a1 -AvailabilitySetId $etcdAS.Id
    $vm = Set-AzureRmVMOperatingSystem -VM $vm -Linux -ComputerName $vmName -Credential $credential

    <#
    For Windows
    $vm = Set-AzureRmVMOperatingSystem -VM $vm -Windows -ComputerName $vmName -Credential $credential `
          -ProvisionVMAgent -EnableAutoUpdate
    #>
    # -CustomData
    # Specifies a base-64 encoded string of custom data. 
    # This is decoded to a binary array that is saved as a file on the virtual machine. 
    # The maximum length of the binary array is 65535 bytes.
    # "..\..\init-static\custom-data\kubernetes-cluster-etcd-nodes.yml" 

    $vm = Set-AzureRmVMSourceImage -VM $vm -Skus $skuName -PublisherName $publisherName `
        -Offer $offerName -Version $skuVersion
    $vm = Add-AzureRmVMNetworkInterface -VM $vm -Id $nic.Id

    #$vm = Add-AzureRmVMSshPublicKey -VM $vm -SSHPublicKeys $sshKey

    $vm = Set-AzureRmVMOSDisk -VM $vm -Name $diskName -VhdUri $osDiskUri -CreateOption fromImage

    #Set-AzureRmVMExtension

    New-AzureRmVM -ResourceGroupName $resourceGroupName -Location $resourceLocation -VM $vm
}




