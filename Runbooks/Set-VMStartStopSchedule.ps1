#workflow Set-VMStartStopSchedule
#{
    <#
	.SYNOPSIS
		Adds Schedule tag to a VM or Resource Group that is later evaluated by Test-ResourceSchedule to decide if VM(s) will shutdown or not.
	.DESCRIPTION
		Adds Schedule tag to a VM or Resource Group that is later evaluated by Test-ResourceSchedule to decide if VM(s) will shutdown or not. If a schedule is attached to a resource group it will apply to
		all VMs whithin that resource group, if both the resource group and VM inside it has a Schedule tag attached, the VM tag will be evaluated and takes precedence.
	.PARAMETER SubscriptioName
		Name of Azure subscription where resource groups and resources are located.
	.PARAMETER ResourceGroupName
        Name of the resource group where the VM resides
	.PARAMETER VmName
	    Optional, if this parameter is used, a VM will be tagged with a Schedule tag. If it is not provided te resource group will be tagged instead.
	.PARAMETER Schedule
	    Hash table that defines the schedule and Timezone of the resource. TzId is the time zone resource id and it can be obtained by exeuting [System.TimeZoneInfo]::GetSystemTimeZones() in a powershell command prompt.
			Sample code on how to define the hashtable:
   
			$schedule= @{
							"TzId"="Central Standard Time";
							"0"= @{
										"S"="11";
										"E"="17"};
							"1"= @{
										"S"="9";
										"E"="19"};
							"2"= @{
										"S"="9";
										"E"="19"};
							"3"= @{
										"S"="9";
										"E"="19"};
							"4"= @{
										"S"="9";
										"E"="19"};
							"5"= @{
										"S"="9";
										"E"="19"};
							"6"= @{
										"S"="11";
										"E"="17"}

						}
		   }        
        
		   Where:
				TzID - Time zone ID - this is the timezone of the resource where this schedule is being applied.
				0, 1 , 2 , 3, 4, 5, 6 - numeric representation of days of week, Sunday starts in 0.
				S - Start time, numeric value of the hour from 1 to 24.
				E - End/Stop time, numeric value of the hour from 1 to 24
	.PARAMETER TagName				
	.PARAMETER EnableTagName					
	.PARAMETER ConnectionName					
	.EXAMPLE
		How to manually execute this runbook from a Powershell command prompt:
		
        Add-AzureRmAccount
        
        Select-AzureRmSubscription -SubscriptionName pmcglobal
        
        $schedule= @{ "TzId"="Central Standard Time"; "0"= @{"S"="11";"E"="17"};"1"= @{"S"="9";"E"="19"};"2"= @{"S"="9";"E"="19"};"3"= @{"S"="9";"E"="19"};"4"= @{"S"="9";"E"="19"};"5"= @{"S"="9";"E"="19"};"6"= @{"S"="11";"E"="17"}}      

		$params = @{"SubscriptionName"="pmcglobal";"ResourceGroupName"="pmcrg01";"VmName"="pmcvm01";"Schedule"=$schedule}
		Start-AzureRmAutomationRunbook -Name "Add-ResourceSchedule" -Parameters $params -AutomationAccountName "pmcAutomation01" -ResourceGroupName "rgAutomation"

	.NOTE
		Since this runbook is being created from Azure Portal (azure.portal.com), this is Resource Manager so the following cmdlets
		should be executed when starting it from an Azure Powershell 1.0 command prompt:
		
		Add-AzureRmAccount
		Select-AzureRmSubscription -SubscriptionName <subscritpionname>
		
	.DISCLAIMER
		This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment.
	    THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED,
	    INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.  
	    We grant You a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute the object
	    code form of the Sample Code, provided that You agree: (i) to not use Our name, logo, or trademarks to market Your software
	    product in which the Sample Code is embedded; (ii) to include a valid copyright notice on Your software product in which the
	    Sample Code is embedded; and (iii) to indemnify, hold harmless, and defend Us and Our suppliers from and against any claims
	    or lawsuits, including attorneys’ fees, that arise or result from the use or distribution of the Sample Code.
	    Please note: None of the conditions outlined in the disclaimer above will supersede the terms and conditions contained
	    within the Premier Customer Services Description.
	#>
    
	[cmdletBinding()]
	Param
	(
		[Parameter(Mandatory=$true)]
		[string]$SubscriptionName,
		
		[Parameter(Mandatory=$true)]
		[string]$ResourceGroupName,
	
		[Parameter(Mandatory=$false)]
		[string]$VMName,
	
		[Parameter(Mandatory=$false)]
		[string] $Schedule,
		[Parameter(Mandatory=$false)]
		[string] $TagName='StartStopSchedule',
		[Parameter(Mandatory=$false)]
		[string] $EnableTagName='EnableStartStopSchedule',
		[Parameter(Mandatory=$false)]
		[string] $ScriptTagName='ScriptStartStopSchedule',		
		#switch not supported in powershell workflow
		[Parameter(Mandatory=$false)]
		[bool] $enabled=$true,		
		[Parameter(Mandatory=$false)]
		[string] $ConnectionName='AzureRunAsConnection',
		[Parameter(Mandatory=$false)]
		[string] $shutdownscript
		
)
	
	# Default schedule hash table
	if ($Schedule -eq $null)
	{
		# Sunday is 0
		# it accept only hour numbers from 1 to 24 (so 24h notation)
		$schedule= (@{
	                    "TzId"="Central Standard Time";
	                    "0"= @{
	                                "S"="11";
	                                "E"="17"};
	                    "1"= @{
	                                "S"="9";
	                                "E"="19"};
	                    "2"= @{
	                                "S"="9";
	                                "E"="19"};
	                    "3"= @{
	                                "S"="9";
	                                "E"="19"};
	                    "4"= @{
	                                "S"="9";
	                                "E"="19"};
	                    "5"= @{
	                                "S"="9";
	                                "E"="19"};
	                    "6"= @{
	                                "S"="11";
	                                "E"="17"}

	                }) | convertto-json -Depth 4 -Compress
	}
	
	# Authenticating and setting up current subscription
	Write-Output "Authenticating"
	
	try
	{
		# Get the connection "AzureRunAsConnection "
		$servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         

		Add-AzureRmAccount `
			-ServicePrincipal `
			-TenantId $servicePrincipalConnection.TenantId `
			-ApplicationId $servicePrincipalConnection.ApplicationId `
			-CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
	}
	catch
	{
		if (!$servicePrincipalConnection)
		{
			$ErrorMessage = "Connection $connectionName not found."
			throw $ErrorMessage
		}
		else
		{
			Write-Error -Message $_.Exception
			throw $_.Exception
		}
	}

#region parameters validation
	$subscription = Select-AzureRmSubscription -SubscriptionName $subscriptionName -ErrorAction SilentlyContinue -ErrorVariable subErr


	if($subErr -or !$subscription) {
        if ($subErr) {throw $subErr.tostring()}
        else {throw 'Error getting subscription'}
	}
	
	$resGroup = Get-AzureRmResourceGroup -Name $ResourceGroupName
	if(!$resGroup) {
		throw ('{0} not found' -f $ResourceGroupName)
	}

	if(![String]::IsNullOrEmpty($VMName)) {
		$vm = get-azurermvm -ResourceGroupName $ResourceGroupName -Name $VMName
		if (! $vm) {
			throw ('VM {0} not found in resource group {1}' -f $VMName, $ResourceGroupName)
		}
	}
#endregion 

	# Getting tags
if(![String]::IsNullOrEmpty($VMName))
	{
		$tags = (Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $vmName).Tags
	}
	else
	{
		$tags = (Get-AzureRmResourceGroup -ResourceGroupName $resourceGroupName).Tags
	}

  # Setting tag
  #compress schedule
	$scheduleJson = $schedule | ConvertFrom-Json | ConvertTo-Json -Depth 4 -Compress
	if($shutdownscript) {$scriptJson = $shutdownscript | convertfrom-json | COnvertTo-Json -Depth 4 -Compress}
	if($enabled) {$localeIndipendentEnableValue=1} else {$localeIndipendentEnableValue=0}

	if($tags.ContainsKey($tagName)) {$tags[$tagName] = $scheduleJson}	else {$tags.Add($tagName,$scheduleJson)}
	if($tags.ContainsKey($EnableTagName)) {$tags[$EnableTagName] = $localeIndipendentEnableValue}	else {$tags.Add($EnableTagName,$localeIndipendentEnableValue)}	
	if($shutdownscript) {
		if($tags.ContainsKey($ScriptTagName)) {$tags[$ScriptTagName]=$scriptJson} else {$tags.Add($ScriptTagName,$scriptJson)}
	}


if(![String]::IsNullOrEmpty($VMName))
	{
		Set-AzureRmResource -Name $vmName -resourceGroupName $resourceGroupName -ResourceType "Microsoft.Compute/VirtualMachines" -Tag $tags -Confirm:$false -force
	}
	else
	{
		Set-AzureRmResourceGroup -ResourceGroupName $resourceGroupName -Tag $tags
	}

	if($error) {
		throw $error[0]
	}
#}
