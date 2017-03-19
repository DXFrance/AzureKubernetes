 Param(  
    # Name of the subscription to use for azure cmdlets
    $subscriptionName = "stephgou - External",
    $subscriptionId = "fb79eb46-411c-4097-86ba-801dca0ff5d5",
    #Paramètres du Azure Ressource Group
    $resourceGroupName = "AzArmAcsKubernetes",
    $resourceLocation = "West Europe",
    $templateFile = "acskubernetesdeploy.json",
    $templateParameterFile = "acskubernetes.parameters.json",
    $templateFolder = "../Templates/"
    )

#region init
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

az group deployment create -g $resourceGroupName `
 --template-uri "$scriptFolder/$templatefolder/$templateFile"  `
 --parameters "$scriptFolder/$templatefolder/$templateParameterFile"


# set-location "$scriptFolder\$templatefolder"
# az group deployment create -g $resourceGroupName --template-uri "acskubernetesdeploy.json" --parameters "acskubernetes.parameters.json"

$d = get-date
Write-Host "Stopping Deployment $d"

