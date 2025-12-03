<#
.SYNOPSIS
    Adds existing Active Directory users to predefined security and distribution groups using a CSV-based import process.
	
.DESCRIPTION
    The **ad-adduserstogroups_final.ps1** script automates the process of assigning users to Active Directory groups 
    based on mappings defined in a CSV file.  
    It supports both **English (en-US)** and **German (de-DE)** operating system environments and automatically 
    selects the corresponding dataset and logic for each locale.

    The script performs the following actions:
    - Detects the system language using `Get-ComputerInfo`
    - Imports group membership definitions from:
      ```
      English (en-US): C:\_psc\ADC_Setup\5_AD_AddUserToGroup\ad_group-list_final.csv
      German (de-DE):  C:\_psc\ADC_Setup\5_AD_AddUserToGroup\de-DE\ad_group-list_de_final.csv
      ```
    - Validates the Active Directory domain configuration before execution  
    - Iterates through each group listed in the CSV file and:
        - Verifies if the specified users exist in Active Directory  
        - Checks whether each user is already a member of the target group  
        - Adds missing members to their assigned groups  
    - Provides detailed console feedback and generates a full activity log

    The script logs operations to:
    - For English systems:
      ```
      C:\_psc\ADC_Setup\Logfiles\AddUsersToGroups.log
      ```
    - For German systems:
      ```
      C:\_psc\ADC_Setup\Logfiles\AddUsersToGroups_DE.log
      ```

    This script is typically executed **after the OU, group, and user import processes** have been completed,
    serving as the final step in domain configuration and role-based access control setup.

	Requirements:
	    - Windows Server 2016 or newer  
	    - PowerShell 5.1 or later  
	    - Active Directory Domain Services (ADDS) installed and configured  
	    - Administrative privileges on the domain  
	    - Valid CSV file defining user-group mappings  
	    - Execution policy allowing script execution (`Set-ExecutionPolicy Bypass`)  
		- AD OU Teomplate
		- AD Group Template
		- AD User Import
	
.LINK
    https://learn.microsoft.com/en-us/powershell/module/activedirectory/add-adgroupmember  
    https://learn.microsoft.com/en-us/powershell/module/activedirectory/get-adgroupmember
	https://github.com/PScherling
	
.NOTES
          FileName: ad-adduserstogroups_final.ps1
          Solution: Active Directory Group Membership Automation  
          Author: Patrick Scherling
          Contact: @Patrick Scherling
          Primary: @Patrick Scherling
          Created: 2025-01-07
          Modified: 2025-12-03

          Version - 0.0.1 - () - Finalized functional version 1.
          Version - 0.0.2 - () - Reworked and little additions.
		  Version - 0.0.3 - () - Integrating "DE" Version
		  Version - 0.0.4 - () - Adding group membership fucntionality
		  Version - 0.0.5 - () - Refactoring to get rid of duplicated logic, multi-lang support, cleaner console output, easier maintanance

          TODO:
		  
		
.Example
	PS> .\ad-adduserstogroups_final.ps1
    Automatically detects the system language and executes the corresponding process 
    to add users to groups as defined in the CSV file.

    PS> powershell.exe -ExecutionPolicy Bypass -File "C:\Scripts\ad-adduserstogroups_final.ps1"
    Runs the script non-interactively in an automated domain setup pipeline, 
    assigning users to their respective AD groups based on the import file.
#>

# ===============================
# 1. Localization / Configuration
# ===============================
$Localization = @{
    'en-US' = @{
        CsvPath       = 'C:\_psc\ADC_Setup\5_AD_AddUserToGroup\ad_group-list_final.csv'
        LogFile       = 'C:\_psc\ADC_Setup\Logfiles\AddUsersToGroups.log'
        Header        = "-----------------------------------------------------------------------------------
              Active Directory Configuration Setup
              Adding Users to Groups
-----------------------------------------------------------------------------------`n"
        LangName      = "English"
    }

    'de-DE' = @{
        CsvPath       = 'C:\_psc\ADC_Setup\5_AD_AddUserToGroup\de-DE\ad_group-list_de_final.csv'
        LogFile       = 'C:\_psc\ADC_Setup\Logfiles\AddUsersToGroups_DE.log'
        Header        = "-----------------------------------------------------------------------------------
              Active Directory Configuration Setup
              Adding Users to Groups (German Edition)
-----------------------------------------------------------------------------------`n"
        LangName      = "German"
    }
}
# Default fallback if an unsupported language is detected
$DefaultLanguage = 'en-US'


# ===============================
# 2. Logging Function
# ===============================

function Write-Log {
	param (
		[string]$Message
	)
	$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
	$logMessage = "[$timestamp] $Message"
	#Write-Output $logMessage
	$logMessage | Out-File -FilePath $logFile -Append
}


# ===============================
# 3. Language Selection
# ===============================
function Get-OSLanguageConfig {

    $Lang = (Get-ComputerInfo).OSLanguage

    if ($Localization.ContainsKey($Lang)) {
        return $Localization[$Lang]
    }

    Write-Host "Unsupported OS language detected: $Lang" -ForegroundColor Yellow
    Write-Host "Falling back to $DefaultLanguage." -ForegroundColor Yellow
    return $Localization[$DefaultLanguage]
}

# ===============================
# 4. Core Logic (Universal)
# ===============================
function Add-UsersToGroups {
    param(
        [string]$CsvPath,
        [string]$LogFilePath,
        [string]$HeaderText
    )

    # Make log file globally available to Write-Log
    $script:LogFile = $LogFilePath

    Write-Log "=== Starting AD Group Assignment Process ==="
    Write-Host $HeaderText

    # Validate AD domain
    Write-Log "Checking AD Domain"
    <#
	try {
        $Domain = Get-ADDomain
    }
    catch {
        Write-Log "ERROR: No AD Domain detected. Cannot continue. $_"
        Write-Host "ERROR: No AD Domain detected - aborting." -ForegroundColor Red
        exit
    }

    Write-Host "Detected Domain:" $Domain.DNSRoot -ForegroundColor Green
    Write-Log  "Detected Domain: $($Domain.DNSRoot)"
	#>
	
	#Input for Domain Name
	while([string]::IsNullOrEmpty($DomainName)) {
				
		#Checking if a domain was set-up in the first place before running the script
		try {
			Write-Log "Try to get AD-Domain"
			$Domain = get-addomain
		}
		catch {
			Write-Log " ERROR: AD-Domain could not be found! There is no Domain existing in your system. You have to set up the Domain Controller first
Reason: $_"
			Write-Host -ForegroundColor Red "ERROR: AD-Domain could not be found! There is no Domain existing in your system. You have to set up the Domain Controller first
Reason: $_"
			exit
		}
		
		Write-Host " This is your Domain for this Setup"
		Write-Host "-----------------------------------------------"
		$DomainName = $Domain.DNSRoot
		$DomainDistinguishedName = $Domain.DistinguishedName
		Write-Host " The Domain Name is:" $DomainName -ForegroundColor Green
		Write-Host " The Domain Distinguished-Name is:" $DomainDistinguishedName -ForegroundColor Green
		Write-Host "-----------------------------------------------"
		
		Write-Log " This is your Domain for this Setup"
		Write-Log "-----------------------------------------------"
		Write-Log " The Domain Name is: $DomainName"
		Write-Log " The Domain Distinguished-Name is: $DomainDistinguishedName"
		Write-Log "-----------------------------------------------"
		
		while($response -ne "y") {
			Write-Log " Waiting for user input"
			$response = Read-Host -Prompt "Press (y) to approve and continue or (a) to abort"
			if($response -eq "a") {
				Write-Log " User input was (a) to abort."
				exit
			}
		}
		Read-Host -Prompt "Press any key to continue for safety reasons"
	}

    # Load CSV
    if (-not (Test-Path $CsvPath)) {
        Write-Host "ERROR: CSV file not found at $CsvPath" -ForegroundColor Red
        Write-Log  "ERROR: CSV file missing at $CsvPath"
        exit
    }

    $GroupMappings = Import-Csv $CsvPath -Delimiter ';'
    Write-Log "Imported CSV entries: $($GroupMappings.Count)"

    foreach ($Entry in $GroupMappings) {

        $GroupName = $Entry.Name
        $Members   = $Entry.Members -split ','

        Write-Host "`nProcessing Group: $GroupName" -ForegroundColor Cyan
        Write-Log  "Processing Group: $GroupName"

        foreach ($ObjectName in $Members) {

            $ObjectName = $ObjectName.Trim()

            # Check if object is a user or group
            $IsUser  = Get-ADUser  -Filter "SamAccountName -eq '$($ObjectName)'" -ErrorAction SilentlyContinue
            $IsGroup = Get-ADGroup -Filter "SamAccountName -eq '$($ObjectName)'" -ErrorAction SilentlyContinue

            if (-not $IsUser -and -not $IsGroup) {
                Write-Host "WARN: AD object '$($ObjectName)' not found." -ForegroundColor Yellow
                Write-Log  "WARN: AD object '$($ObjectName)' not found."
                continue
            }

            $Type = if ($IsUser) { 'User' } else { 'Group' }

            Write-Host "Found $($Type): $ObjectName"
            Write-Log  "Found $($Type): $ObjectName"

            # Check existing group membership
            $CurrentMembers = Get-ADGroupMember $GroupName -Recursive | Select-Object -ExpandProperty SamAccountName

            if ($CurrentMembers -contains $ObjectName) {
                Write-Host "Already in $GroupName" -ForegroundColor Green
                Write-Log  "Already member of $GroupName"
                continue
            }

            # Add to group
            try {
                Add-ADGroupMember -Identity $GroupName -Members $ObjectName
                Write-Host "Added $ObjectName to $GroupName" -ForegroundColor Green
                Write-Log  "Added $ObjectName to $GroupName"
            }
            catch {
                Write-Host "ERROR: Failed to add $($ObjectName): $_" -ForegroundColor Red
                Write-Log  "ERROR adding member: $_"
            }
        }
    }

    Write-Log "=== Finished AD Group Assignment Process ==="
	Read-Host -Prompt " Press any key"
}


# ===============================
# 5. Entry Point
# ===============================
$Cfg = Get-OSLanguageConfig

Add-UsersToGroups -CsvPath $Cfg.CsvPath -LogFilePath $Cfg.LogFile -HeaderText $Cfg.Header


