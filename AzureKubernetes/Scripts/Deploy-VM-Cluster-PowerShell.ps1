Param( 
    # Name of the subscription to use for azure cmdlets
    $subscriptionName = "stephgou - External",
    $subscriptionId = "fb79eb46-411c-4097-86ba-801dca0ff5d5",
    #Paramètres du Azure Ressource Group
    $resourceGroupName = "AzKubernetesPowerShell",
    $resourceLocation = "West Europe",
    $coreOSImageName = "CoreOs:CoreOS:Beta:899.6.0",
    $publisherName = "CoreOS",
    $offerName = "CoreOS",
    $skuName ="Beta",
    $skuVersion = "899.6.0",
    $prefix = "azkubernetes",
    $defaultSubnet = "defaultSubnet",
    $vnetAddressPrefix = "172.16.0.0/12",
    $subnetAddressPrefix = "172.16.0.0/24",
    $dnsServer = "8.8.8.8",
    $etcd_node = 3,
    $kube_node = 3,
    $diskName="OSDisk",
    # Machines have to be named as in yml custom data (update for generating this yml in powershell
    # from parameters will come later
    # Hostname format should be aligned on "pokubernetes-kube02"
    $etcdCustomDataFile = "..\..\init-static\custom-data\azkubernetes-cluster-etcd-nodes.yml",
    $kubeCustomDataFile = "..\..\init-static\custom-data\azkubernetes-cluster-main-nodes-template.yml",
    $tagName = "Kubernetes_RG",
    $tagValue = "AzKubernetes"
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
#From MinGW64 $ ssh -i "c/dev/keys/idrsa" -p 2200 devops@pokubernetes-etcd.westeurope.cloudapp.azure.com

$sshPathOnLinuxMachine = "/home/$username/.ssh/authorized_keys"
#endregion credentials
Login-AzureRmAccount -SubscriptionId $subscriptionId

$etcdCustomData = Get-Content $etcdCustomDataFile -Raw 
$kubeCustomData = Get-Content $kubeCustomDataFile -Raw 

# Resource group create
New-AzureRmResourceGroup `
	-Name $resourceGroupName `
	-Location $resourceLocation `
    -Tag @{Name=$tagName;Value=$tagValue} `
    -Verbose

# create availabilitySets etcd / kube
$etcdAS = New-AzureRmAvailabilitySet -Name $prefix-av-etcd -ResourceGroupName $resourceGroupName -Location $resourceLocation
$kubeAS = New-AzureRmAvailabilitySet -Name $prefix-av-kube -ResourceGroupName $resourceGroupName -Location $resourceLocation

#-------------------------------------------------- Storage -----------------------------------------

# create storageAccount etcd / kube
$storageAccountName = $prefix + "etcd"
$etcdStorageAccount = New-AzureRmStorageAccount -AccountName $storageAccountName `
    -ResourceGroupName $resourceGroupName -Location $resourceLocation -Type “Standard_LRS”
$etcdStorageAccount = Get-AzureRmStorageAccount -ResourceGroupName $resourceGroupName `
    -Name $storageAccountName

$storageAccountName = $prefix + "kube"
$kubeStorageAccount = New-AzureRmStorageAccount -AccountName $storageAccountName `
    -ResourceGroupName $resourceGroupName -Location $resourceLocation -Type “Standard_LRS”
$kubeStorageAccount = Get-AzureRmStorageAccount -ResourceGroupName $resourceGroupName `
    -Name $storageAccountName

#-------------------------------------------------- Network -----------------------------------------
# create vnet
$subnet = New-AzureRmVirtualNetworkSubnetConfig -Name $defaultSubnet -AddressPrefix $subnetAddressPrefix
$vnet = New-AzureRmVirtualNetwork -Name $prefix-vnet -ResourceGroupName $resourceGroupName -Location $resourceLocation `
         -AddressPrefix $vnetAddressPrefix -DnsServer $dnsServer -Subnet $subnet
$subnet = Get-AzureRmVirtualNetworkSubnetConfig -Name $subnet.Name -VirtualNetwork $vnet

# create Public IP etcd / kube
$etcdPIP = New-AzureRmPublicIpAddress -Name $prefix-pip-etcd  -ResourceGroupName $resourceGroupName `
        -Location $resourceLocation -AllocationMethod Dynamic -DomainNameLabel $prefix-etcd 
$kubePIP = New-AzureRmPublicIpAddress -Name $prefix-pip-kube  -ResourceGroupName $resourceGroupName `
        -Location $resourceLocation -AllocationMethod Dynamic -DomainNameLabel $prefix-kube 

# create Front-ip etcd / kube 
$etcdFIP = New-AzureRmLoadBalancerFrontendIpConfig -Name $prefix-fip-etcd -PublicIpAddress $etcdPIP
$kubeFIP = New-AzureRmLoadBalancerFrontendIpConfig -Name $prefix-fip-etcd -PublicIpAddress $kubePIP

# create inbound ssh nat rule for etcd / kube 

$etcdInboundNATRules = @()

for($i=0; $i -le $etcd_node-1; $i++)
{
    $inboundNatRuleName = "ssh-etcd" + $i
    $frontendPort = [convert]::ToInt32(2200+$i,10)

    $etcdInboundNATRule = New-AzureRmLoadBalancerInboundNatRuleConfig -Name $inboundNatRuleName `
         -FrontendIpConfiguration $etcdFIP `
         -Protocol TCP -FrontendPort $frontendPort -BackendPort 22
    $etcdInboundNATRules += $etcdInboundNATRule
}

$kubeInboundNATRules = @()

for($i=0; $i -le $kube_node-1; $i++)
{
    $inboundNatRuleName = "ssh-kube" + $i
    $frontendPort = [convert]::ToInt32(2200+$i,10)

    $kubeInboundNATRule = New-AzureRmLoadBalancerInboundNatRuleConfig -Name $inboundNatRuleName `
         -FrontendIpConfiguration $kubeFIP `
         -Protocol TCP -FrontendPort $frontendPort -BackendPort 22
    $kubeInboundNATRules += $kubeInboundNATRule
}

# Create Load balancer etcd / kube
$etcdLB = New-AzureRmLoadBalancer -Name $prefix-lb-etcd -ResourceGroupName $resourceGroupName `
    -Location $resourceLocation -FrontendIpConfiguration $etcdFIP `
    -InboundNatRule $etcdInboundNATRules
$etcdBAP = New-AzureRmLoadBalancerBackendAddressPoolConfig -Name $prefix-bp-etcd
$ConfNull = Add-AzureRmLoadBalancerBackendAddressPoolConfig -LoadBalancer $etcdLB `
         -Name $etcdBAP.Name | Set-AzureRmLoadBalancer 
$etcdLB = Get-AzureRmLoadBalancer | where { $_.Name -eq $etcdLB.Name}
$etcdBAPConfig = $etcdLB.BackendAddressPools[0]
$etcdInboundNATRules = $etcdLB.InboundNatRules

$kubeLB = New-AzureRmLoadBalancer -Name $prefix-lb-kube -ResourceGroupName $resourceGroupName `
    -Location $resourceLocation -FrontendIpConfiguration $kubeFIP `
    -InboundNatRule $kubeInboundNATRules
$kubeBAP = New-AzureRmLoadBalancerBackendAddressPoolConfig -Name $prefix-bp-kube
$ConfNull = Add-AzureRmLoadBalancerBackendAddressPoolConfig -LoadBalancer $kubeLB `
         -Name $kubeBAP.Name | Set-AzureRmLoadBalancer 
$kubeLB = Get-AzureRmLoadBalancer | where { $_.Name -eq $kubeLB.Name}
$kubeBAPConfig = $kubeLB.BackendAddressPools[0]
$kubeInboundNATRules = $kubeLB.InboundNatRules

#-------------------------------------------------- Nics & VM -----------------------------------------

# create etcd & kube nics and virtual machines

Write-Host "Creating etcd Vm"
for($i=0; $i -le $etcd_node-1; $i++)
{
    $nic = New-AzureRmNetworkInterface -Name $prefix-nic-etcd-$i -ResourceGroupName $resourceGroupName `
        -Location $resourceLocation -Subnet $subnet `
        -LoadBalancerBackendAddressPool $etcdBAPConfig `
        -LoadBalancerInboundNatRule $etcdInboundNATRules[$i]

    $vmName = "$prefix-etcd0$i"
    Write-Host "Creating "$vmName
    $vm = New-AzureRmVMConfig -VMName $vmName -VMSize standard_a1 -AvailabilitySetId $etcdAS.Id  

    $vm = Set-AzureRmVMOperatingSystem -VM $vm -Linux -ComputerName $vmName -Credential $credential `
        -CustomData $etcdCustomData      

    $vm = Set-AzureRmVMSourceImage -VM $vm -Skus $skuName -PublisherName $publisherName `
        -Offer $offerName -Version $skuVersion
    $vm = Add-AzureRmVMNetworkInterface -VM $vm -Id $nic.Id
    $vm = Add-AzureRmVMSshPublicKey -VM $vm -KeyData $sshKey -Path $sshPathOnLinuxMachine

    $osDiskUri = $etcdStorageAccount.PrimaryEndpoints.Blob.ToString() + "vhds/$diskName" + "etcd-$i.vhd"

    $vm = Set-AzureRmVMOSDisk -VM $vm -Name $diskName -VhdUri $osDiskUri -CreateOption fromImage

    New-AzureRmVM -ResourceGroupName $resourceGroupName -Location $resourceLocation -VM $vm

    Write-Host "$vmName has been created"
}

Write-Host "Creating kube Vm"
for($i=0; $i -le $kube_node-1; $i++)
{
    $nic = New-AzureRmNetworkInterface -Name $prefix-nic-kube-$i -ResourceGroupName $resourceGroupName `
        -Location $resourceLocation -Subnet $subnet `
        -LoadBalancerBackendAddressPool $kubeBAPConfig `
        -LoadBalancerInboundNatRule $kubeInboundNATRules[$i]

    $vmName = "$prefix-kube0$i"
    Write-Host "Creating "$vmName
    $vm = New-AzureRmVMConfig -VMName $vmName -VMSize standard_a1 -AvailabilitySetId $kubeAS.Id  

    $vm = Set-AzureRmVMOperatingSystem -VM $vm -Linux -ComputerName $vmName -Credential $credential `
        -CustomData $kubeCustomData

    $vm = Set-AzureRmVMSourceImage -VM $vm -Skus $skuName -PublisherName $publisherName `
        -Offer $offerName -Version $skuVersion
    $vm = Add-AzureRmVMNetworkInterface -VM $vm -Id $nic.Id
    $vm = Add-AzureRmVMSshPublicKey -VM $vm -KeyData $sshKey -Path $sshPathOnLinuxMachine

    $osDiskUri = $kubeStorageAccount.PrimaryEndpoints.Blob.ToString() + "vhds/$diskName" + "kube-$i.vhd"

    $vm = Set-AzureRmVMOSDisk -VM $vm -Name $diskName -VhdUri $osDiskUri -CreateOption fromImage

    New-AzureRmVM -ResourceGroupName $resourceGroupName -Location $resourceLocation -VM $vm

    Write-Host "$vmName has been created"
}

$d = get-date
Write-Host "Stopping Deployment $d"


