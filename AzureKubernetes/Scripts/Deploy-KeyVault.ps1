Param( 
    # Name of the subscription to use for azure cmdlets
    $subscriptionName = "stephgou - External",
    $subscriptionId = "fb79eb46-411c-4097-86ba-801dca0ff5d5",
	$VaultName = 'stephgouKeyVault',
	$VaultLocation = 'West Europe',
	$ResourceGroupName = 'stephgouKeyVault',
	$ResourceGroupLocation = 'West Europe'
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

Login-AzureRmAccount -SubscriptionId $subscriptionId

#Requires -Module AzureRM.Profile
#Requires -Module AzureRM.KeyVault

#Login and Select the default subscription if needed
#Login-AzureRmAccount
#Select-AzureRmSubscription -SubscriptionName 'subscription name'

#Change the values below before running the script


New-AzureRmResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLocation -Force

New-AzureRmKeyVault -VaultName $VaultName -ResourceGroupName $ResourceGroupName -Location $VaultLocation -EnabledForTemplateDeployment