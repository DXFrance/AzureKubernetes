Param(  
    $subscriptionId = "fb79eb46-411c-4097-86ba-801dca0ff5d5",
    $resourceGroupName = "az-Kubernetes-VM-Cluster"
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

# Resource groupe create
Remove-AzureRmResourceGroup -Name $resourceGroupName

$d = get-date
Write-Host "Stopping Unprovisioning $d"
