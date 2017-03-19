 Param(  
    # Name of the subscription to use for azure cmdlets
    $subscriptionName = "stephgou - External",
    $subscriptionId = "fb79eb46-411c-4097-86ba-801dca0ff5d5",
    #Paramètres du Azure Ressource Group
    $resourceGroupName = "AzKubernetes",
    $resourceLocation = "West Europe",
    $clusterName = "stephgouAzKub",
    $dnsPrefix = "azku",
    $orchestratorType = "kubernetes",
    $agentCount = 2,
	$sshKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDhdhD4JCfI50HPBrgg+mQyhhid9CvN3oqpSBiCMp9FsCkAeVwsROXxvgz4UTdStcWd3p/Qa/vkMy6hQvAPdMs+LS8ltsbt6qIgUTxRbNxi+y2heL5a6VqHVPpcqDOncT3NsyqqNXdEVjZGaSSkD5MDSGkxMuwFakG5XJ4PtKfWHAwBtQuesBIFM3wYGS6Ty5PfsFZqPkd96Nx/oPdCoLCjqzlTy1xi2Uhn8tv5nehWC7MXKzJbAxjfI15kIx7A9VfBL1qjQoZKKKBB2wbPMEMxbZGRxKVPgf807v6CyplpJ2DTPnZCQIxNqZF/APUUtdqGTWyJ+Wq3aisIjxnnZQKecu4YdbjNsIBlVkzaQCdPggxMn0d/MWcep4xKqp+xCrVrDrVzUmp2vrHzTMg1JOozRMB8vom05NczsNT8reB3IWe4S4iS527+zjwDM7TZWxrUb+xxEC0uKpQuJ+8va95VSIbhm7tJrdl4EjBiGuoK243/bgPVbkLxa1yHIq8OKgezGHdSb1KJzv2yFJZwQm/57gxfsSxsfqpVWoPlLmGLQFIT1NNUQtkuoJIxCLW/1OwAMkbclmDPXyaW5smAem9+MSM25wN8kU5OytzRcLyG58bdnZyuUuBbGeKDWZwhBuYJ3ib7vHFbetCEmAQhHDmFGnUQf0Kd+0R6BE5en8dswQ== stephgou@X1CARBONW10TP"
    )

#https://docs.microsoft.com/en-us/azure/container-service/container-service-create-acs-cluster-cli

Set-PSDebug -Strict

cls
$d = get-date
Write-Host "Starting Deployment $d"

$scriptFolder = Split-Path -Parent $MyInvocation.MyCommand.Definition
Write-Host "scriptFolder" $scriptFolder

set-location $scriptFolder

az login

az account set --subscription $subscriptionId

az group create --name $resourceGroupName --location $resourceLocation 

az acs create -n $clusterName --resource-group $resourceGroupName -d dnsPrefix  `
              -g $resourceGroupName -l $resourceLocation --ssh-key-value $sshKey  `
              --agent-count $agentCount --orchestrator-type $orchestratorType

$d = get-date
Write-Host "Stopping Deployment $d"


az acs kubernetes get-credentials --resource-group=$resourceGroupName --name=$clusterName