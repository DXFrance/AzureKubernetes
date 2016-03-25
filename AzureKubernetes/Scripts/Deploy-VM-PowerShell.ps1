Param(  
    # Name of the subscription to use for azure cmdlets
    $subscriptionName = "stephgou - External",
    $subscriptionId = "fb79eb46-411c-4097-86ba-801dca0ff5d5",
    #Paramètres du Azure Ressource Group
    $resourceGroupName = "Az-Kubernetes-VM-Cluster",
    $resourceLocation = "West Europe",
    $coreOSImageName = "CoreOs:CoreOS:Beta:899.6.0",
    $publisherName = "CoreOS",
    $offerName = "CoreOS",
    $skuName ="Beta",
    $skuVersion = "899.6.0",
    $prefix = "azKubernetes",
    $domainNameLabel = "azkubernetes",
    $frontendSubnet = "frontendSubnet",
    $vnetAddressPrefix = "172.16.0.0/12",
    $subnetAddressPrefix = "172.16.0.0/24",
    $dnsServer = "8.8.8.8",
    $etcd_node = 1,
    $kub_node = 3,
    $diskName="OSDisk",
    $customDataFile = "..\..\init-static\custom-data\kubernetes-cluster-etcd-nodes.yml",
    $storageAccountName = "azkubernetes",
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

#region credentials
$username = "devops"
$password = "VeL0c1RaPt0R#" | ConvertTo-SecureString -AsPlainText -Force
$credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $password 
#Generated key in 'C:\DEV\keys\idrsa.pub'
$sshKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDhdhD4JCfI50HPBrgg+mQyhhid9CvN3oqpSBiCMp9FsCkAeVwsROXxvgz4UTdStcWd3p/Qa/vkMy6hQvAPdMs+LS8ltsbt6qIgUTxRbNxi+y2heL5a6VqHVPpcqDOncT3NsyqqNXdEVjZGaSSkD5MDSGkxMuwFakG5XJ4PtKfWHAwBtQuesBIFM3wYGS6Ty5PfsFZqPkd96Nx/oPdCoLCjqzlTy1xi2Uhn8tv5nehWC7MXKzJbAxjfI15kIx7A9VfBL1qjQoZKKKBB2wbPMEMxbZGRxKVPgf807v6CyplpJ2DTPnZCQIxNqZF/APUUtdqGTWyJ+Wq3aisIjxnnZQKecu4YdbjNsIBlVkzaQCdPggxMn0d/MWcep4xKqp+xCrVrDrVzUmp2vrHzTMg1JOozRMB8vom05NczsNT8reB3IWe4S4iS527+zjwDM7TZWxrUb+xxEC0uKpQuJ+8va95VSIbhm7tJrdl4EjBiGuoK243/bgPVbkLxa1yHIq8OKgezGHdSb1KJzv2yFJZwQm/57gxfsSxsfqpVWoPlLmGLQFIT1NNUQtkuoJIxCLW/1OwAMkbclmDPXyaW5smAem9+MSM25wN8kU5OytzRcLyG58bdnZyuUuBbGeKDWZwhBuYJ3ib7vHFbetCEmAQhHDmFGnUQf0Kd+0R6BE5en8dswQ== stephgou@X1CARBONW10TP"
#From MinGW64 $ ssh -i "c/dev/keys/idrsa" -p 2200 devops@azkubernetes-etcd.westeurope.cloudapp.azure.com

$sshPathOnLinuxMachine = "/home/$username/.ssh/authorized_keys"
#endregion credentials
#Login-AzureRmAccount -SubscriptionId $subscriptionId

$customData = Get-Content $customDataFile -Raw 
$encodedcustomData = [System.Text.Encoding]::UTF8.GetBytes($customData)
$base64EncodedcustomData = [System.Convert]::ToBase64String($encodedcustomData)

# Resource group create
New-AzureRmResourceGroup `
	-Name $resourceGroupName `
	-Location $resourceLocation `
    -Tag @{Name=$tagName;Value=$tagValue} `
    -Verbose

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
      
    #$vm = Set-AzureRmVMOperatingSystem -VM $vm -Linux -ComputerName $vmName -Credential $credential `
    #    -CustomData $base64EncodedcustomData      

    $vm = Set-AzureRmVMOperatingSystem -VM $vm -Linux -ComputerName $vmName -Credential $credential `
        -CustomData $customData      
    
    # -CustomData must not be encoded in base64
    #-> Ask for a correction in https://msdn.microsoft.com/en-us/library/mt603843.aspx
    # Specifies a base-64 encoded string of custom data. 
    # This is decoded to a binary array that is saved as a file on the virtual machine. 
    # The maximum length of the binary array is 65535 bytes.
    # "..\..\init-static\custom-data\kubernetes-cluster-etcd-nodes.yml"

    <#
    For Windows
    $vm = Set-AzureRmVMOperatingSystem -VM $vm -Windows -ComputerName $vmName -Credential $credential `
          -ProvisionVMAgent -EnableAutoUpdate
    #>

    $vm = Set-AzureRmVMSourceImage -VM $vm -Skus $skuName -PublisherName $publisherName `
        -Offer $offerName -Version $skuVersion
    $vm = Add-AzureRmVMNetworkInterface -VM $vm -Id $nic.Id

    #Does not seem to work with a base64 encoded key
    #-> Ask for a correction in https://msdn.microsoft.com/en-us/library/mt603458.aspx
    #$vm = Add-AzureRmVMSshPublicKey -VM $vm -KeyData $base64EncodedSshKey -Path $sshPathOnLinuxMachine
    $vm = Add-AzureRmVMSshPublicKey -VM $vm -KeyData $sshKey -Path $sshPathOnLinuxMachine

    $vm = Set-AzureRmVMOSDisk -VM $vm -Name $diskName -VhdUri $osDiskUri -CreateOption fromImage

    #Set-AzureRmVMExtension

    New-AzureRmVM -ResourceGroupName $resourceGroupName -Location $resourceLocation -VM $vm

    Write-Host "$vmName has been created"

}

$d = get-date
Write-Host "Stopping Deployment $d"


