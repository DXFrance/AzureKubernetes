Param(  

    #Paramètres du Azure Ressource Group
    $resourceGroupName = "stephgou-Kubernetes-Ansible-Centos"
    )

#region init
Set-PSDebug -Strict

cls
$d = get-date
Write-Host "Starting Unprovisioning $d"

$scriptFolder = Split-Path -Parent $MyInvocation.MyCommand.Definition
Write-Host "scriptFolder" $scriptFolder

set-location $scriptFolder
#endregion init

#Login-AzureRmAccount -SubscriptionId $subscriptionId

# Resource group create
Remove-AzureRmResourceGroup -Name $resourceGroupName

$d = get-date
Write-Host "Stopping Unprovisioning $d"
