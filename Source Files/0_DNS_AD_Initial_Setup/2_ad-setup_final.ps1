<#
.SYNOPSIS
    Automates the installation and initial configuration of a new Active Directory (AD) Forest and Domain Controller.
.DESCRIPTION
    The **2_ad-setup_final.ps1** script performs the automated setup of a new Active Directory Domain Controller.  
    It assists administrators in interactively defining key domain parameters, confirming configuration options,  
    and then executing the **Install-ADDSForest** deployment command with logging and safety checks.

	The script includes:
    - Interactive input for domain name and confirmation prompts
    - Automatic creation of the AD database, log, and SYSVOL directories
    - Integration of DNS installation and delegation (optional)
    - Detailed event and process logging
    - Safe pre-check using `-WhatIf` to preview AD installation before execution
    - Optional automatic restart after setup completion

    This script is primarily used during the **initial setup of a new AD forest** or as part of an automated deployment 
    process (e.g., MDT, SCCM, or PowerShell remoting).  
    It ensures reproducibility, error logging, and guided user interaction.

	Requirements:
    - Windows Server 2016 or newer  
    - PowerShell 5.1 or later  
    - Administrator privileges  
    - DNS Server Role installed (recommended)  
    - Execution policy set to allow script execution (`Set-ExecutionPolicy Bypass`)  
	
.LINK
    https://learn.microsoft.com/en-us/powershell/module/addsdeployment/install-addsforest  
    https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/get-started/virtual-dc/active-directory-domain-services-overview  
	https://github.com/PScherling
	
.NOTES
          FileName: 2_ad-setup_final.ps1
          Solution: Active Directory Initial Forest & Domain Controller Setup  
          Author: Patrick Scherling
          Contact: @Patrick Scherling
          Primary: @Patrick Scherling
          Created: 2025-01-03
          Modified: 2025-01-03

          Version - 0.0.1 - () - Finalized functional version 1.
          Version - 0.0.2 - () - Reworked and little additions like Logging.
          

          TODO:
		  
		
.Example
	PS> .\2_ad-setup_final.ps1
    Starts the interactive Active Directory forest and domain configuration process.  
    Prompts for the desired domain name and other details, then executes the installation safely.

	PS> powershell.exe -ExecutionPolicy Bypass -File "C:\Scripts\2_ad-setup_final.ps1"
    Runs the AD setup script in an automated deployment context (e.g., MDT/SCCM),  
    performing the forest and domain configuration with DNS installation and logging enabled.
#>

####
#### Restart-System
####
function Restart-System {
    do{
        $Continue = Read-Host " Do you want to continue (Y/N)"
    } while($Continue -ne "Y" -and $Continue -ne "N")
	
    if($Continue -eq "Y") {
        for ($i = 10; $i -gt 0; $i=$i - 1 ) {
		    clear-host
		    Write-Host -ForegroundColor Yellow "
	System is going down for reboot in $i seconds..."
		    Start-Sleep -Seconds 1
	    }
        Restart-Computer #-WhatIf
    }
    elseif($Continue -eq "N"){
        Show-Menu
    }
}


###
### Main Script
###
function AD-Setup {
	$DomainName = ""
	$DomainMode = "Default" #Values: Default | 2 or Win2003 | 3 or Win2008 | 4 or Win2008R2 | 5 or Win2012 | 6 or Win2012R2 | 7 or WinThreshold aka Windows Server 2016
	$ForestMode = "Default" #Values: Default | 2 or Win2003 | 3 or Win2008 | 4 or Win2008R2 | 5 or Win2012 | 6 or Win2012R2 | 7 or WinThreshold aka Windows Server 2016
	$InstallDNS = "$true"
	$CreateDNSDelegation = "$true"
	#$DnsDelegationCredential = (Get-Credential "sysadmineuro")
	$DatabasePath = "C:\AD\NTDS" 
	$LogPath = "C:\AD\NTDS"
	$SysvolPath = "C:\AD\SYSVOL"
	$LocalHostname = $env:computername
	$response = ""
	$securityresponse = ""
	# Log file path
    $logFile = "C:\_it\ADC_Setup\Logfiles\ad-setup.log"
	
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
        Write-Log " Input for Domain Name Forest"


		#Input for Domain Name Forest
		while($response -ne "y" -and [string]::IsNullOrEmpty($DomainName)) {
			#User Input for AD
			Write-Host "-----------------------------------------------------------------------------------"
			Write-Host "              Active Directory Initial Configuration Setup"
			Write-Host "              Creating AD Forest and 1.DC Setup"
			Write-Host "-----------------------------------------------------------------------------------" `n

			
			$DomainName = Read-Host -Prompt " Enter your Domain Name (like 'domain.at')"
			Write-Log "-----------------------------------------------------------------------------------"
			Write-Log "    Your Domain Name will be:                        $DomainName"
			Write-Log "    Your Domain Mode will be:                        $DomainMode"
			Write-Log "    Your Forest Mode will be:                        $ForestMode"
			Write-Log "    Install DNS?                                     $InstallDNS"
			Write-Log "    DNS Delegation will be created if possible?      $CreateDNSDelegation"
			#Write-Log "    Admin User for DNS Delegation:                  $DnsDelegationCredential"
			Write-Log "    AD Database Path will be:                        $DatabasePath"
			Write-Log "    AD Log Path will be:                             $LogPath"
			Write-Log "    AD Sysvol Path will be:                          $SysvolPath"
			Write-Log "-----------------------------------------------------------------------------------"
			
			Write-Host "-----------------------------------------------------------------------------------" `n
			Write-Host "    Your Domain Name will be:                        $DomainName"
			Write-Host "    Your Domain Mode will be:                        $DomainMode"
			Write-Host "    Your Forest Mode will be:                        $ForestMode"
			Write-Host "    Install DNS?                                     $InstallDNS"
			Write-Host "    DNS Delegation will be created if possible?      $CreateDNSDelegation"
			#Write-Host "    Admin User for DNS Delegation:                  $DnsDelegationCredential"
			Write-Host "    AD Database Path will be:                        $DatabasePath"
			Write-Host "    AD Log Path will be:                             $LogPath"
			Write-Host "    AD Sysvol Path will be:                          $SysvolPath"
			Write-Host "-----------------------------------------------------------------------------------" `n
			
			Write-Log " Waiting for user input"
			
			$response = Read-Host -Prompt " Press (y) to approve and continue or (a) to abort"
			if($response -eq "a") {
				Write-Log " User input was (a) to abort."
				
				$DomainName = ""
				exit
			}

		}

		if ($response -eq "y") {
			Write-Log " User input was (y) to continue."
			Write-Log "-----------------------------------------------------------------------------------"
			Write-Log " Creating Active Directory"
			Write-Log " Waiting for user input"
			
			Write-Host "-----------------------------------------------------------------------------------" `n
			Write-Host " Creating Active Directory"
			Read-Host -Prompt " Press Enter key to continue"
			
			#This line is for confimration before AD will be created! DO NOT REMOVE "-WhatIF" AT THE END OF THIS LINE!!!
			Install-ADDSForest -DomainName $DomainName -DomainMode $DomainMode -ForestMode $ForestMode -SafeModeAdministratorPassword (Read-Host -AsSecureString -Prompt "Enter DSRM Recovery Password") -InstallDns:$true -CreateDNSDelegation:$true -DnsDelegationCredential (Get-Credential "$LocalHostname\sysadmineuro") -DatabasePath $DatabasePath -LogPath $LogPath -SysvolPath $SysvolPath -WhatIf

			while($securityresponse -ne "y") {
				
				$securityresponse = Read-Host -Prompt " Press (y) to approve and continue with creation or (a) to abort"
				if($securityresponse -eq "a") {
					Write-Log " User input was (a) to abort."
					
					Write-Host "-----------------------------------------------------------------------------------"
					Write-Host " Active Directory Server set up aborted. No Changes were made! Exiting Setup..." -ForegroundColor Yellow
					Write-Host "-----------------------------------------------------------------------------------"
					
					$DomainName = ""
					
					exit
				}
				if ($securityresponse -eq "y") {
					Write-Log " User input was (y) to continue."
					
					Install-ADDSForest -DomainName $DomainName -DomainMode $DomainMode -ForestMode $ForestMode -SafeModeAdministratorPassword (Read-Host -AsSecureString -Prompt "Enter DSRM Recovery Password") -InstallDns:$true -CreateDNSDelegation:$true -DnsDelegationCredential (Get-Credential "$LocalHostname\sysadmineuro") -DatabasePath $DatabasePath -LogPath $LogPath -SysvolPath $SysvolPath -NoRebootOnCompletion -Force:$true -ErrorAction Stop #-WhatIf
					
					Write-Log "-----------------------------------------------------------------------------------"
					Write-Log " Active Directory Server successfully set up. Please restart the server now for completion!"
					Write-Log " After rebooting the system, please secure your DNS Zones in Active Directory and make sure that the 'DNS Dynamic-Updates Setting' is set to 'only save' Updates!"
					Write-Log " After rebooting, please execute the script '3_ad-post-setup-tasks_final.ps1' locatet in the same folder '0_DNS_AD_Initial-Setup'!"
					Write-Log "-----------------------------------------------------------------------------------"
					
					Write-Host "-----------------------------------------------------------------------------------"
					Write-Host " Active Directory Server successfully set up. Please restart the server now for completion!" -ForegroundColor Green
					Write-Host " After rebooting the system, please secure your DNS Zones in Active Directory and make sure that the 'DNS Dynamic-Updates Setting' is set to 'only save' Updates!" -ForegroundColor Yellow
					Write-Host " After rebooting, please execute the script '3_ad-post-setup-tasks_final.ps1' locatet in the same folder '0_DNS_AD_Initial-Setup'!" -ForegroundColor Yellow
					Write-Host "-----------------------------------------------------------------------------------"

					Write-Log " Attention! Server is going down for reboot."
					Write-Warning " Attention! Server is going down for reboot."
			
					Restart-System
				}
			}
		}
	}
	catch {
        Write-Log "Error: An unexpected error occurred: $_"
    } 
	finally {
        # End logging
        Write-Log "End of configuration process."
    }
}


AD-Setup
