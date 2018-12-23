$pass = ConvertTo-SecureString -AsPlainText -Force -String 'Myaw$0meKey' 
$sp=New-AzureRmADServicePrincipal -DisplayName "OMSAutomation" -Password $pass
New-AzureRmRoleAssignment  -ApplicationId $sp.Id -RoleDefinitionName Contributor 
New-AzureRmDeployment -Name deployoms -TemplateFile .\template.json -templateStorage csb634336f30983x4d4dxbe4 -EnvironmentName omstest -Location "west europe" -workspaceSku PerNode