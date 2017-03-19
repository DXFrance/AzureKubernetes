<#
 .SYNOPSIS
    Deploys a template to Azure

 .DESCRIPTION
    Deploys an Azure Resource Manager template

 .PARAMETER subscriptionId
    The subscription id where the template will be deployed.

 .PARAMETER resourceGroupName
    The resource group where the template will be deployed. Can be the name of an existing or a new resource group.

 .PARAMETER resourceGroupLocation
    Optional, a resource group location. If specified, will try to create a new resource group in this location. If not specified, assumes resource group is existing.

 .PARAMETER deploymentName
    The deployment name.

 .PARAMETER templateFilePath
    Optional, path to the template file. Defaults to template.json.

 .PARAMETER parametersFilePath
    Optional, path to the parameters file. Defaults to parameters.json. If file is not found, will prompt for parameter values based on template.
#>

param(
 #[Parameter(Mandatory=$True)]
 [string]
 $subscriptionId = "0459dbd5-b73e-4a5b-b052-250dc51ac622",
 # Service Principal must match subscription !!!
 #[Parameter(Mandatory=$True)]
 [string]
 $resourceGroupName = "PSArmAcsKubernetes",

 [string]
 $resourceGroupLocation = "West Europe",

 #[Parameter(Mandatory=$True)]
 [string]
 $deploymentName = "AzKubernetesPowerShellDeploy",

 [string]
 $templateFilePath = "..\Templates\acskubernetesdeploy.json",

 [string]
 $parametersFilePath = "..\Templates\acskubernetes.parameters.json",

 [string]
 $clusterName = "containerservice-$resourceGroupName",

 [string]
 $sshKeyFile = "C:\DEV\keys\idrsa"
)

<#
.SYNOPSIS
    Registers RPs
#>
Function RegisterRP {
    Param(
        [string]$ResourceProviderNamespace
    )

    Write-Host "Registering resource provider '$ResourceProviderNamespace'";
    Register-AzureRmResourceProvider -ProviderNamespace $ResourceProviderNamespace;
}

#******************************************************************************
# Script body
# Execution begins here
#******************************************************************************
Set-PSDebug -Strict
$ErrorActionPreference = "Stop"

cls
$d = get-date
Write-Host "Starting Deployment $d"

$scriptFolder = Split-Path -Parent $MyInvocation.MyCommand.Definition
Write-Host "scriptFolder" $scriptFolder

set-location $scriptFolder

# sign in
Write-Host "Logging in...";
#Login-AzureRmAccount;

# select subscription
Write-Host "Selecting subscription '$subscriptionId'";
#Select-AzureRmSubscription -SubscriptionID $subscriptionId;

# Register RPs
$resourceProviders = @("microsoft.containerservice");
if($resourceProviders.length) {
    Write-Host "Registering resource providers"
    foreach($resourceProvider in $resourceProviders) {
        RegisterRP($resourceProvider);
    }
}

#Create or check for existing resource group
$resourceGroup = Get-AzureRmResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
if(!$resourceGroup)
{
    Write-Host "Resource group '$resourceGroupName' does not exist. To create a new resource group, please enter a location.";
    if(!$resourceGroupLocation) {
        $resourceGroupLocation = Read-Host "resourceGroupLocation";
    }
    Write-Host "Creating resource group '$resourceGroupName' in location '$resourceGroupLocation'";
    New-AzureRmResourceGroup -Name $resourceGroupName -Location $resourceGroupLocation
}
else{
    Write-Host "Using existing resource group '$resourceGroupName'";
}

# Start the deployment
Write-Host "Starting deployment...";
if(Test-Path $parametersFilePath) {
    New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile $templateFilePath -TemplateParameterFile $parametersFilePath;
} else {
    New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile $templateFilePath;
}

$d = get-date
Write-Host "Stopping Deployment $d"


az acs kubernetes get-credentials --resource-group=$resourceGroupName --name=$clusterName --ssh-key-file=$sshKeyFile

az acs kubernetes browse --resource-group=$resourceGroupName --name=$clusterName --ssh-key-file=$sshKeyFile

#ubuntu
az login
az account set --subscription "0459dbd5-b73e-4a5b-b052-250dc51ac622"
az acs kubernetes get-credentials --resource-group="PSArmAcsKubernetes" --name="containerservice-PSArmAcsKubernetes" --ssh-key-file="/mnt/c/DEV/keys/idrsa"
