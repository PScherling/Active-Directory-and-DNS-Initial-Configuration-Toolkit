<#
.SYNOPSIS
    Adds a new Domain Controller (DC) to an existing Active Directory domain.
.DESCRIPTION
    The **4_ad-setup_add-dc_final.ps1** script automates the process of adding a new Domain Controller 
    (DC) to an existing Active Directory domain environment.  
    It performs key validation checks, gathers relevant AD information (domain name, site name), and 
    executes the **Install-ADDSDomainController** cmdlet with full logging, user confirmation, and 
    safety prompts.  

    The script includes:
    - Pre-checks for existing domain membership and AD site resolution
    - Interactive confirmation before domain controller promotion
    - Automatic configuration of DNS role installation
    - Creation of database, log, and SYSVOL directories
    - Optional replication and catalog settings
    - Detailed, timestamped logging of all operations and results  

    This script is typically executed after the AD forest has been created using  
    `2_ad-setup_final.ps1` and ensures consistent and repeatable DC deployment across environments.  
    It can be integrated into deployment pipelines, MDT, or manual PowerShell workflows.

	Requirements:
    - Windows Server 2016 or newer  
    - PowerShell 5.1 or later  
    - Active Directory Domain Services (ADDS) role installed  
    - Administrative privileges  
    - Server must be joined to an existing domain  
    - Execution policy must allow script execution (`Set-ExecutionPolicy Bypass`)  
	
.LINK
	https://learn.microsoft.com/en-us/powershell/module/addsdeployment/install-addsdomaincontroller  
    https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/get-started/virtual-dc/active-directory-domain-services-overview  
	https://github.com/PScherling
    
.NOTES
          FileName: 4_ad-setup_add-dc_final.ps1
          Solution: Active Directory Additional Domain Controller Deployment 
          Author: Patrick Scherling
          Contact: @Patrick Scherling
          Primary: @Patrick Scherling
          Created: 2025-01-02
          Modified: 2025-01-02

          Version - 0.0.1 - () - Finalized functional version 1.
          

          TODO:
		  
		
.Example
	PS> .\4_ad-setup_add-dc_final.ps1
    Launches the interactive process to add a new Domain Controller to the existing Active Directory domain.  
    Prompts the user to confirm configuration details and proceeds with DC promotion.

    PS> powershell.exe -ExecutionPolicy Bypass -File "C:\Scripts\4_ad-setup_add-dc_final.ps1"
    Executes the script in an automated or semi-automated environment, logging all steps and 
    adding the server as a secondary Domain Controller with DNS services installed.
#>

function Add-DC {
	# Log file path
    $logFile = "C:\_it\ADC_Setup\Logfiles\ad-setup_add-dc.log"
	
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
		Write-Log " Checking if server is already member of a domain."
		try{
			$DomainName = (Get-ADDomain -ErrorAction SilentlyContinue).DNSRoot
		}
		catch{
			Write-Log " Error: Server is not member of a domain."
			$DomainName = $null
		}

		$DomainMode = "Default" #Values: Default | 2 or Win2003 | 3 or Win2008 | 4 or Win2008R2 | 5 or Win2012 | 6 or Win2012R2 | 7 or WinThreshold aka Windows Server 2016
		$ForestMode = "Default" #Values: Default | 2 or Win2003 | 3 or Win2008 | 4 or Win2008R2 | 5 or Win2012 | 6 or Win2012R2 | 7 or WinThreshold aka Windows Server 2016
		$InstallDNS = "$true"
		$CreateDNSDelegation = "$false"
		#$DnsDelegationCredential = (Get-Credential "sysadmineuro")
		$DatabasePath = "C:\AD\NTDS" 
		$LogPath = "C:\AD\NTDS"
		$SysvolPath = "C:\AD\SYSVOL"

		$ErrorActionPreference = "SilentlyContinue"
		Write-Log " Checking if an existing SiteName can be resolved."
		try{
			$SiteName = [System.DirectoryServices.ActiveDirectory.ActiveDirectorySite]::GetComputerSite().Name
		}
		catch{
			Write-Log " Error: No SiteName could be resolved."
			$SiteName = $null
		}
		finally {
			# Reset ErrorActionPreference to its default value (Continue)
			$ErrorActionPreference = "Continue"
		}

		$LocalHostname = $env:computername
		$response = ""
		$securityresponse = ""


		if(-not [string]::IsNullOrEmpty($DomainName) -and -not [string]::IsNullOrEmpty($SiteName)) {
			Write-Log " Prechecks successfully finished. We can continue..."
			
			while($response -ne "y") {

				Write-Host "-----------------------------------------------------------------------------------"
				Write-Host "              Active Directory Configuration Setup"
				Write-Host "              Adding a DC to existing Domain"
				Write-Host "-----------------------------------------------------------------------------------" `n
				
				Write-Log "    Your Domain Name is:                            $DomainName"
				Write-Log "    The Domain Site Name is:                        $SiteName"
				#Write-Log "    Your Domain Mode will be:                      $DomainMode"
				#Write-Log "    Your Forest Mode will be:                      $ForestMode"
				Write-Log "    Install DNS?                                    $InstallDNS"
				Write-Log "    DNS Delegation will be created if possible?     $CreateDNSDelegation"
				#Write-Log "    Admin User for DNS Delegation:                 $DnsDelegationCredential"
				Write-Log "    AD Database Path will be:                       $DatabasePath"
				Write-Log "    AD Log Path will be:                            $LogPath"
				Write-Log "    AD Sysvol Path will be:                         $SysvolPath"
				Write-Log "-----------------------------------------------------------------------------------"

				Write-Host "    Your Domain Name is:                            $DomainName"
				Write-Host "    The Domain Site Name is:                        $SiteName"
				#Write-Host "    Your Domain Mode will be:                      $DomainMode"
				#Write-Host "    Your Forest Mode will be:                      $ForestMode"
				Write-Host "    Install DNS?                                    $InstallDNS"
				Write-Host "    DNS Delegation will be created if possible?     $CreateDNSDelegation"
				#Write-Host "    Admin User for DNS Delegation:                 $DnsDelegationCredential"
				Write-Host "    AD Database Path will be:                       $DatabasePath"
				Write-Host "    AD Log Path will be:                            $LogPath"
				Write-Host "    AD Sysvol Path will be:                         $SysvolPath"
				Write-Host "-----------------------------------------------------------------------------------" `n
			
				Write-Log " Waiting for user input."
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
				Write-Log " Adding DC to existing domain"
				
				Write-Host "-----------------------------------------------------------------------------------" `n
				Write-Host " Adding DC to existing domain"
				
				Write-Log " Waiting for user input."
				
				Read-Host -Prompt " Press Enter key to continue"
			
				#This line is for confimration before AD will be created! DO NOT REMOVE "-WhatIF" AT THE END OF THIS LINE!!!
				Install-ADDSDomainController -DomainName $DomainName -SafeModeAdministratorPassword (Read-Host -AsSecureString -Prompt "Enter DSRM Recovery Password") -InstallDns:$true -CreateDNSDelegation:$false -DatabasePath $DatabasePath -LogPath $LogPath -SysvolPath $SysvolPath -CriticalReplicationOnly:$false -NoGlobalCatalog:$false -NoRebootOnCompletion:$false -WhatIf

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
					
						Install-ADDSDomainController -DomainName $DomainName -SafeModeAdministratorPassword (Read-Host -AsSecureString -Prompt "Enter DSRM Recovery Password") -InstallDns:$true -CreateDNSDelegation:$false -DatabasePath $DatabasePath -LogPath $LogPath -SysvolPath $SysvolPath -CriticalReplicationOnly:$false -NoGlobalCatalog:$false -NoRebootOnCompletion:$false -Force:$true -ErrorAction Stop #-WhatIf
						
						Write-Log "-----------------------------------------------------------------------------------"
						Write-Log " Active Directory Server successfully added to existing domain. The server restarts now for completion!"
						#Write-Log "After rebooting the system, please secure your DNS Zones in Active Directory and make sure that the 'DNS Dynamic-Updates Setting' is set to 'only save' Updates!"
						#Write-Log "After rebooting, please execute the script '3_ad-post-setup-tasks_V0.1.ps1' located in the same folder '0_DNS_AD_Initial-Setup'!"
						Write-Log "-----------------------------------------------------------------------------------"
						
						Write-Host "-----------------------------------------------------------------------------------"
						Write-Host " Active Directory Server successfully added to existing domain. The server restarts now for completion!" -ForegroundColor Green
						#Write-Host "After rebooting the system, please secure your DNS Zones in Active Directory and make sure that the 'DNS Dynamic-Updates Setting' is set to 'only save' Updates!" -ForegroundColor Yellow
						#Write-Host "After rebooting, please execute the script '3_ad-post-setup-tasks_V0.1.ps1' located in the same folder '0_DNS_AD_Initial-Setup'!" -ForegroundColor Yellow
						Write-Host "-----------------------------------------------------------------------------------"
					}
				}
			}
		}
		else{
			Write-Log "    Active-Directory Management can not be executed due to insufficient prerequisites!"
			
			Write-Host -ForegroundColor Red "    Active-Directory Management can not be executed due to insufficient prerequisites!"
			Read-Host " Press any key to abort"
			Exit
		}
	}
	catch {
        Write-Log "Error: An unexpected error occurred: $_"
    } finally {
        # End logging
        Write-Log "End of configuration process."
    }
}


Add-DC
