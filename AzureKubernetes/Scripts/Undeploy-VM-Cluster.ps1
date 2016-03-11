Param(  

    #Paramètres du Azure Ressource Group
    $resourceGroupeName = "stephgou-Kubernetes-VM-Cluster"
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
Remove-AzureRmResourceGroup -Name $resourceGroupeName

$d = get-date
Write-Host "Stopping Unprovisioning $d"
