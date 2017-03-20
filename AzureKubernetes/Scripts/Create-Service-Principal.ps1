param(
 #[Parameter(Mandatory=$True)]
 [string]
 $subscriptionId = "0459dbd5-b73e-4a5b-b052-250dc51ac622",
 # Service Principal must match subscription !!!
 #[Parameter(Mandatory=$True)]
 [string]
 $spName = "http://stephgou-Kubernetes",

 [string]
 $spPassword = "ToModify"
)

<#
Add-AzureRmAccount
$app = New-AzureRmADApplication -DisplayName "Kubernetes" -HomePage "https://stephgou/kubernetes" -IdentifierUris "https://stephgou/kubernetes" -Password "ToModify"
New-AzureRmADServicePrincipal -ApplicationId $app.ApplicationId
New-AzureRmRoleAssignment -RoleDefinitionName Contributor -ServicePrincipalName $app.ApplicationId.Guid

$creds = Get-Credential
#$tenant = (Get-AzureRmSubscription).TenantId
$tenant = (Get-AzureRmSubscription -SubscriptionName "stephgouInTheCloud").TenantId
Login-AzureRmAccount -Credential $creds -ServicePrincipal -TenantId $tenant

# Service principal client ID = Application ID
# Do not use Object ID 

#>

az login
az account set --subscription $subscriptionId
az ad sp create-for-rbac --name=$spName --password=$spPassword --role="Contributor" --scopes="/subscriptions/$subscriptionId"
#az login --service-principal -u yourClientID -p yourClientSecret --tenant yourTenant
#az vm list-sizes --location westus

#ssh-keygen -f "/home/stephgou/.ssh/known_hosts" -R kub-kube-masters.westeurope.cloudapp.azure.com
#ssh -p 22 -i /mnt/c/DEV/keys/idrsa devops@kub-ansible.westeurope.cloudapp.azure.com
#ssh -p 22 -i .ssh/idgen_rsa 10.0.8.4

#ssh -p 22 -i /mnt/c/DEV/keys/idrsa devops@kub-kube-masters.westeurope.cloudapp.azure.com
#ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDhdhD4JCfI50HPBrgg+mQyhhid9CvN3oqpSBiCMp9FsCkAeVwsROXxvgz4UTdStcWd3p/Qa/vkMy6hQvAPdMs+LS8ltsbt6qIgUTxRbNxi+y2heL5a6VqHVPpcqDOncT3NsyqqNXdEVjZGaSSkD5MDSGkxMuwFakG5XJ4PtKfWHAwBtQuesBIFM3wYGS6Ty5PfsFZqPkd96Nx/oPdCoLCjqzlTy1xi2Uhn8tv5nehWC7MXKzJbAxjfI15kIx7A9VfBL1qjQoZKKKBB2wbPMEMxbZGRxKVPgf807v6CyplpJ2DTPnZCQIxNqZF/APUUtdqGTWyJ+Wq3aisIjxnnZQKecu4YdbjNsIBlVkzaQCdPggxMn0d/MWcep4xKqp+xCrVrDrVzUmp2vrHzTMg1JOozRMB8vom05NczsNT8reB3IWe4S4iS527+zjwDM7TZWxrUb+xxEC0uKpQuJ+8va95VSIbhm7tJrdl4EjBiGuoK243/bgPVbkLxa1yHIq8OKgezGHdSb1KJzv2yFJZwQm/57gxfsSxsfqpVWoPlLmGLQFIT1NNUQtkuoJIxCLW/1OwAMkbclmDPXyaW5smAem9+MSM25wN8kU5OytzRcLyG58bdnZyuUuBbGeKDWZwhBuYJ3ib7vHFbetCEmAQhHDmFGnUQf0Kd+0R6BE5en8dswQ== stephgou@X1CARBONW10TP
