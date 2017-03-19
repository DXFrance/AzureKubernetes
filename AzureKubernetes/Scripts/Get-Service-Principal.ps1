#ad75912a-0087-4e03-9bb4-9b2f28a03ab4

#Add-AzureRmAccount
$app = Get-AzureRmADApplication -IdentifierUri "https://stephgou/kubernetes"
echo $app.ApplicationId.Guid

$role = Get-AzureRmRoleAssignment -ServicePrincipalName "https://stephgou/kubernetes"
echo $role.Capacity
#New-AzureRmADServicePrincipal -ApplicationId $app.ApplicationId
#New-AzureRmRoleAssignment -RoleDefinitionName Contributor -ServicePrincipalName $app.ApplicationId.Guid

Get-AzureRmRoleAssignment -Scope "/subscriptions/0459dbd5-b73e-4a5b-b052-250dc51ac622"