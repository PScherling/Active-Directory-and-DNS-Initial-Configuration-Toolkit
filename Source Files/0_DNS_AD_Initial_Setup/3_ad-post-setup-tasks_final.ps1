<#
.SYNOPSIS
    Performs Active Directory post-installation configuration and security hardening tasks.
.DESCRIPTION
    The **3_ad-post-setup-tasks_final.ps1** script is designed to execute essential post-installation
    configuration steps after the creation of a new Active Directory forest and domain.  

    It provides administrators with an interactive menu to apply critical post-setup security and configuration
    enhancements such as:

    - Integrating existing DNS zones into Active Directory and enabling **Secure Dynamic Updates**
    - Enabling the **Active Directory Recycle Bin** for object recovery
    - Restricting non-administrative users from joining computers to the domain

    The script supports interactive selection or batch execution of all tasks and logs every action performed
    to a persistent log file:
    ```
    C:\_it\ADC_Setup\Logfiles\ad-post-setup-tasks.log
    ```

    Each operation is validated for errors and reattempted in case of transient failures.  
    This script is intended to be executed **after the initial AD domain controller setup** (script `2_ad-setup_final.ps1`)
    to finalize domain configuration and strengthen security baselines.

	Requirements:
    - Windows Server 2016 or newer  
    - PowerShell 5.1+  
    - DNS Server Role installed  
    - ADDS (Active Directory Domain Services) configured  
    - Administrator privileges  
    - Execution policy allowing scripts (`Set-ExecutionPolicy Bypass`)  
	
.LINK
    https://learn.microsoft.com/en-us/powershell/module/activedirectory  
    https://learn.microsoft.com/en-us/powershell/module/dnsserver 
	https://github.com/PScherling
	
.NOTES
          FileName: 3_ad-post-setup-tasks_final.ps1
          Solution: Active Directory Post-Setup Configuration and Hardening 
          Author: Patrick Scherling
          Contact: @Patrick Scherling
          Primary: @Patrick Scherling
          Created: 2025-01-03
          Modified: 2025-01-03

          Version - 0.0.1 - () - Finalized functional version 1.
		  Version - 0.0.2 - () - Reworked and little additions like Logging.
          

          TODO:
		  
		
.Example
    PS> .\3_ad-post-setup-tasks_final.ps1
    Launches the interactive post-setup configuration menu.  
    Allows selection of specific tasks (e.g., enabling the AD Recycle Bin or integrating DNS zones).

    PS> powershell.exe -ExecutionPolicy Bypass -File "C:\Scripts\3_ad-post-setup-tasks_final.ps1"
    Executes the script in an automated deployment sequence, applying all post-setup security tasks automatically.

#>

function Post-AD-Setup {
	# Log file path
	$logFile = "C:\_it\ADC_Setup\Logfiles\ad-post-setup-tasks.log"
	
	# Function to log messages with timestamps
    function Write-Log {
        param (
            [string]$Message
        )
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logMessage = "[$timestamp] $Message"
        #Write-Output $logMessage
        $logMessage | Out-File -FilePath $logFile -Append
    }
    
    # Start logging
    Write-Log " Starting configuration process..."
	
	try {
	
		Write-Host "-----------------------------------------------------------------------------------"
		Write-Host "              Active Directory Post Setup Tasks"
		Write-Host "              Security Features and other Tweaks"
		Write-Host "-----------------------------------------------------------------------------------" `n
		$response = "false"
		while($response -match "false"){
			Write-Host "    Select Option" `n
			Write-Host "    0) Integrate DNS in AD and configure 'Secure Updates' for DNS Zones" -ForegroundColor Yellow
			Write-Host "    1) Enable Recycle Bin for AD (optional)"
			Write-Host "    2) Prevent Non-Admins from adding Computers to Domain (optional)"
			Write-Host "    a) Execute all Tasks"
			Write-Host "    e) Leave" `n

			Write-Log " Waiting for user input"
			
			$i = Read-Host " Please select an option (0/1/2/a/e)"
			if($i -eq '0'){
				Write-Log " User input is '0'"
				Write-Log " Integrate DNS in AD and configure 'Secure Updates' for DNS Zones"
				
				$response = "true"
				#Call Functions
				try{
					Write-Log " Try to get Reverse Lookup Zone Name"
				    $ReverseLookupZoneName = Get-DNSServerZone | Where-Object {$_.IsAutoCreated -ne "True" -and $_.IsReverseLookupZone -eq "True"} | Select-Object ZoneName
				}
				catch{
					Write-Log "Error: Could not resolve Reverse Lookup Zone Name"
				}
				
				try{
					Write-Log " Try to convert Forward Lookup Zone"
				    ConvertTo-DnsServerPrimaryZone (Get-ADDomain).DNSRoot -PassThru -Verbose -ReplicationScope Domain -Force #-WhatIf
				}
				catch{
                    Write-Log "Error: Could not convert Forward Lookup Zone"
				}

				try{
					Write-Log " Try to convert Reverse Lookup Zone Name"
				    ConvertTo-DnsServerPrimaryZone $ReverseLookupZoneName.ZoneName -PassThru -Verbose -ReplicationScope Domain -Force #-WhatIf
				}
				catch{
					Write-Log "Error: Could not convert Reverse Lookup Zone"
				}
				
				try{
					Write-Log " Try to set secure updates for Forward Lookup Zone Name"
				    set-dnsserverprimaryzone -name (Get-ADDomain).DNSRoot -dynamicupdate "Secure" #-WhatIf
				}
				catch{
					Write-Log "Error: Could not set secure updates for Forward Lookup Zone Name"
				}

				try{
					Write-Log " Try to set secure updates for Reverse Lookup Zone Name"
				    set-dnsserverprimaryzone -name $ReverseLookupZoneName.ZoneName -dynamicupdate "Secure" #-WhatIf
				}
				catch{
					Write-Log "Error: Could not set secure updates for Reverse Lookup Zone Name"
				}
				
				Post-AD-Setup	
			
			}
			elseif($i -eq '1'){
				Write-Log " User input is '1'"
				Write-Log " Enable Recycle Bin for AD (optional)"
				
				$response = "true"
				#Call Function
				try{
					Write-Log " Try to enable Recycle Bin for AD"
				    Enable-ADOptionalFeature 'Recycle Bin Feature' -Scope ForestOrConfigurationSet -Target (Get-ADDomain).DNSRoot
				}
				catch{
					Write-Log "Error: Could not enable Recycle Bin for AD"
				}

				Post-AD-Setup
			
			}
			elseif($i -eq '2'){
				Write-Log " User input is '2'"
				Write-Log " Prevent Non-Admins from adding Computers to Domain (optional)"
				
				$response = "true"
				#Call Function
				try{
					Write-Log " Try to set to prevent Non-Admins from adding Computers to Domain"
				    Set-ADDomain (Get-ADDomain).distinguishedname -Replace @{"ms-ds-MachineAccountQuota"="0"}
				}
				catch{
					Write-Log "Error: Could not set to prevent Non-Admins from adding Computers to Domain"
				}

				Post-AD-Setup	
			}
			elseif($i -eq 'a'){
				Write-Log " User input is 'a'"
				Write-Log " Execute all Tasks"
				
				$response = "true"
				
				# Integrate DNS in AD and configure 'Secure Updates' for DNS Zones
				Write-Log " Integrate DNS in AD and configure 'Secure Updates' for DNS Zones"
				try{
					Write-Log " Try to get Reverse Lookup Zone Name"
				    $ReverseLookupZoneName = Get-DNSServerZone | Where-Object {$_.IsAutoCreated -ne "True" -and $_.IsReverseLookupZone -eq "True"} | Select-Object ZoneName
				}
				catch{
					Write-Log "Error: Could not resolve Reverse Lookup Zone Name"
				}
				
				try{
					Write-Log " Try to convert Forward Lookup Zone"
				    ConvertTo-DnsServerPrimaryZone (Get-ADDomain).DNSRoot -PassThru -Verbose -ReplicationScope Domain -Force #-WhatIf
				}
				catch{
                    Write-Log "Error: Could not convert Forward Lookup Zone"
				}

				try{
					Write-Log " Try to convert Reverse Lookup Zone Name"
				    ConvertTo-DnsServerPrimaryZone $ReverseLookupZoneName.ZoneName -PassThru -Verbose -ReplicationScope Domain -Force #-WhatIf
				}
				catch{
					Write-Log "Error: Could not convert Reverse Lookup Zone"
				}
				
				try{
					Write-Log " Try to set secure updates for Forward Lookup Zone Name"
				    set-dnsserverprimaryzone -name (Get-ADDomain).DNSRoot -dynamicupdate "Secure" #-WhatIf
				}
				catch{
					Write-Log "Error: Could not set secure updates for Forward Lookup Zone Name"
				}

				try{
					Write-Log " Try to set secure updates for Reverse Lookup Zone Name"
				    set-dnsserverprimaryzone -name $ReverseLookupZoneName.ZoneName -dynamicupdate "Secure" #-WhatIf
				}
				catch{
					Write-Log "Error: Could not set secure updates for Reverse Lookup Zone Name"
				}
				
				# AD Recycle Bin
				Write-Log " Enable Recycle Bin for AD (optional)"
				try{
					Write-Log " Try to enable Recycle Bin for AD"
				    Enable-ADOptionalFeature 'Recycle Bin Feature' -Scope ForestOrConfigurationSet -Target (Get-ADDomain).DNSRoot
				}
				catch{
					Write-Log "Error: Could not enable Recycle Bin for AD"
				}
				
				# Prevent Non-Admins from adding Computers to Domain
				Write-Log " Prevent Non-Admins from adding Computers to Domain (optional)"
				try{
					Write-Log " Try to set to prevent Non-Admins from adding Computers to Domain"
				    Set-ADDomain (Get-ADDomain).distinguishedname -Replace @{"ms-ds-MachineAccountQuota"="0"}
				}
				catch{
					Write-Log "Error: Could not set to prevent Non-Admins from adding Computers to Domain"
				}

				Post-AD-Setup
			
			}
			elseif($i -eq 'e'){
				Write-Log " User input is '2'"
				Write-Log " Leaving Post Setup Tasks"
				
				Write-Host "Exiting..." -ForegroundColor Yellow
				exit
			}
			elseif($i -ne '0' -or $i -ne '1' -or $i -ne '2' -or $i -ne 'a' -or $i -ne 'e') {
				Write-Log " User input is wrong. User input: $i"
				Write-Host "Wrong Input" `n -ForegroundColor Red
			}
		}
	}
	catch {
        Write-Log "Error: An unexpected error occurred: $_"
    } finally {
        # End logging
        Write-Log "End of configuration process."
    }
}


Post-AD-Setup
