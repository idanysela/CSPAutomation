<#  
.SYNOPSIS  
Installs OMS extension for Linux and Windows Azure VMs. The Runbook takes comma seperated list of SubscriptionIds and 
installs OMS Agent on each VMs in the subscription.

The runbook needs service pricipal credentials to access VMs in other subscriptions.

This runbook calls child runbook Install-OMSVMExtension. The Install-OMSVMExtension should be available in the automation account.
This runbook can be used in scenario to mass onboard list of Azure VM for OMS.

.EXAMPLE
.\Onboard-VMsForOMSUpdateManagement

.NOTES

#>

param 
(
    [Parameter(Mandatory=$false)] 
    [String]  $AzureCredentialsAssetName = "AzureSP"
)

$InstallOMSVMExtensionRunbookName = "Install-OMSVMExtension"

try 
{
    # Connect to Azure using service principal auth
    $ServicePrincipalConnection =  Get-AutomationPSCredential -Name $AzureCredentialsAssetName         
    Write-Output "Logging in to Azure..."
    $Null = add-azurermaccount -Credential $ServicePrincipalConnection 
}
catch 
{
    if(!$ServicePrincipalConnection) 
    {
        throw "Credentials $AzureCredentialsAssetName not found."
    }
    else 
    {
        throw $_.Exception
    }
}

$workspaceId = Get-AutomationVariable -Name "WorkspaceId"
$workspaceKey = Get-AutomationVariable -Name "WorkspaceKey"
$subIdSubNameList = Get-AutomationVariable -Name 'OMSMonitoredSubscriptions';
$subIdList = $subIdSubNameList.Split(",")
 
ForEach ($subId in $subIdList) 
{

    $subIdDetails = Get-AzureRmSubscription -SubscriptionId $subId
    if ($subIdDetails -eq $null) 
    {
        Write-Output "Cannot get subscription for subId $($subId) check service principal and permissions"
        Continue
    }	
	
    Select-AzureRmSubscription -SubscriptionId $subId
    $subInfo = Select-AzureRmSubscription -SubscriptionId $subId
    if ($subInfo -ne $null) 
    {
        $subIdSubNameList.Add($subInfo.Subscription.SubscriptionId, $subInfo.Subscription.SubscriptionName)
    }

    $VMs = Get-AzureRmVM | Where { $_.StorageProfile.OSDisk.OSType -eq "Windows" -or  $_.StorageProfile.OSDisk.OSType -eq "Linux" }

    # Start each of the VMs
    foreach ($VM in $VMs) 
    {
        $ExtentionNameAndTypeValue = 'MicrosoftMonitoringAgent'
	    if ($VM.StorageProfile.OSDisk.OSType -eq "Linux") 
        {
            $ExtentionNameAndTypeValue = 'OmsAgentForLinux'	
	    }

        try
        {    
	        $VME = Get-AzureRmVMExtension -ExtensionName $ExtentionNameAndTypeValue -ResourceGroup $VM.ResourceGroupName -VMName $VM.Name -ErrorAction 'SilentlyContinue'
            if ($VME -ne $null)
            {
                Write-Output "MMAExtention is already installed for VM $($VM.Name)"
                Continue
            }
        }
        catch 
        {
            # Ignore error
        }

        Start-Sleep -s 2 # just not to hit trottle limit
    	$InstallJobId =    Start-AutomationRunbook -Name $InstallOMSVMExtensionRunbookName -Parameters @{'AzureCredentialsAssetName'=$AzureCredentialsAssetName;'subId'=$subId;'VMName'=$VM.Name;'ResourceGroupName'=$VM.ResourceGroupName;'workspaceId'=$workspaceId;'workspaceKey'=$workspaceKey}
	    if($InstallJobId -ne $null)
	    {
	        Write-Output "Extension installation Job started with JobId $($InstallJobId) on VM $($VM.Name)"
	    }
    }
}

