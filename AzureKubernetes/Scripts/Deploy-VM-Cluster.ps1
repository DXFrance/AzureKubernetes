Param(  
    # Name of the subscription to use for azure cmdlets
    $subscriptionName = "stephgou - External",
    $subscriptionId = "fb79eb46-411c-4097-86ba-801dca0ff5d5",
    #Paramètres du Azure Ressource Group
    $resourceGroupName = "stephgou-Kubernetes-VM-Cluster",
    $resourceGroupDeploymentName = "stephgou-Kubernetes-VM-Cluster-Deployed",
    $resourceLocation = "West Europe",
    $templateFile = "azuredeploy.json",
    $templateParameterFile = "azuredeploy.parameters.json",
    $templateFolder = "..\Templates\VM-Cluster",
    $tagName = "Kubernetes_RG",
    $tagValue = "VM-Cluster"
    )

#region init
Set-PSDebug -Strict

cls
$d = get-date
Write-Host "Starting Deployment $d"

$scriptFolder = Split-Path -Parent $MyInvocation.MyCommand.Definition
Write-Host "scriptFolder" $scriptFolder

set-location $scriptFolder
#endregion init

Login-AzureRmAccount -SubscriptionId $subscriptionId

# Resource group create
New-AzureRmResourceGroup `
	-Name $resourceGroupName `
	-Location $resourceLocation `
    -Tag @{Name=$tagName;Value=$tagValue} `
    -Verbose

# Resource group deploy
New-AzureRmResourceGroupDeployment `
    -Name $resourceGroupDeploymentName `
	-ResourceGroupName $resourceGroupName `
	-TemplateFile "$scriptFolder\$templatefolder\$templateFile" `
	-TemplateParameterFile "$scriptFolder\$templatefolder\$templateParameterFile" `
    -Verbose `

$d = get-date
Write-Host "Stopping Deployment $d"