<#
.SYNOPSIS
    Imports and creates Active Directory security and distribution groups from a predefined CSV template.
	
.DESCRIPTION
    The **group-import_final.ps1** script automates the bulk creation of Active Directory groups 
    based on definitions provided in a CSV file.  
    It ensures consistent group naming conventions, correct OU placement, and reliable configuration 
    of group attributes such as category, scope, and description.

    The script:
    - Reads group definitions from a CSV file located at:
      ```
      C:\_psc\ADC_Setup\3_AD_Gruppen_Import\ad_group_import_final.csv
      ```
    - Retrieves and validates the current Active Directory domain context
    - Checks whether each group already exists in AD before creating it
    - Creates new groups with their defined attributes:
        - **Name**
        - **SamAccountName**
        - **GroupCategory** (Security / Distribution)
        - **GroupScope** (Global / DomainLocal / Universal)
        - **DisplayName**
        - **Description**
        - **OU Path**
    - Provides real-time feedback and detailed logging for each operation

    All operations are logged to:
    ```
    C:\_psc\ADC_Setup\Logfiles\Import-ADGroups.log
    ```

    This script is typically used during Active Directory initialization or re-deployment 
    to quickly rebuild standard group structures after domain creation and OU setup.

	Requirements:
	    - Windows Server 2016 or newer  
	    - PowerShell 5.1 or later  
	    - Active Directory Domain Services (ADDS) installed and configured  
	    - Administrative privileges on the domain  
	    - Valid CSV input file with correct field headers  
	    - Execution policy allowing scripts (`Set-ExecutionPolicy Bypass`)  
		- AD Standard OU Template
	
.LINK
    https://learn.microsoft.com/en-us/powershell/module/activedirectory/new-adgroup  
    https://learn.microsoft.com/en-us/powershell/module/activedirectory/get-adgroup
	https://github.com/PScherling
	
.NOTES
          FileName: group-import_final.ps1
          Solution: Active Directory Group Import and Standardization  
          Author: Patrick Scherling
          Contact: @Patrick Scherling
          Primary: @Patrick Scherling
          Created: 2025-01-03
          Modified: 2025-01-03

          Version - 0.0.1 - () - Finalized functional version 1.
          Version - 0.0.2 - () - Reworked and little additions.

          TODO:
		  
		
.Example
	PS> .\group-import_final.ps1
    Imports and creates all Active Directory groups defined in the CSV file for the current domain.

    PS> powershell.exe -ExecutionPolicy Bypass -File "C:\Scripts\group-import_final.ps1"
    Runs the script non-interactively during automated AD provisioning to recreate groups 
    from the standardized import list.
#>

function Import-ADGroups {

	# Log file path
    $logFile = "C:\_psc\ADC_Setup\Logfiles\Import-ADGroups.log"
	
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


	#Import active directory module for running AD cmdlets
	#Import-Module activedirectory
	  
	#Store the data from ADUsers.csv in the $ADUsers variable
	$ImportADGroups = Import-csv -path 'C:\_psc\ADC_Setup\3_AD_Gruppen_Import\ad_group_import_final.csv' -Delimiter ";" -encoding utf8 # Standardpfad
	$response = ""
	$Domain = ""
	$DomainName = ""
	$DomainDistinguishedName = ""
	$Group = ""
	#$groupcreated = "false"

	try{

		#Input for Domain Name
		while([string]::IsNullOrEmpty($DomainName)) {
			
			Write-Host "-----------------------------------------------------------------------------------"
			Write-Host "              Active Directory Configuration Setup"
			Write-Host "              AD Group Setup"
			Write-Host "-----------------------------------------------------------------------------------" `n
			
			#Checking if a domain was set-up in the first place before running the script
			try {
				Write-Log " Try to get AD-Domain"
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

		#Loop through each row containing user details in the CSV file
		Write-Log " Importing AD Groups"
		foreach ($Group in $ImportADGroups)
		{
			#Read group data from each field in each row and assign the data to a variable as below
				
			$Groupname 	= $Group.Name #GroupName or Identity
			$GroupSamAccountName 	= $Group.SamAccountName #SamAccountName
			$GroupCategory	= $Group.GroupCategory #Category
			$GroupScope       = $Group.GroupScope #Scope
			$GroupDisplayName = $Group.Displayname #Displayname
			$GroupDescription = $Group.Description #Group Description for additional information
			$GroupPath 		= $Group.OUPath #This field refers to the OU the group is to be created in
			$GroupDistinguishedName = "$GroupPath," + $DomainDistinguishedName #Full DistinguishedName
			
			#Write Output to screen
			Write-Host " Group Creation"
			Write-Host "-----------------------------------------------"
			Write-Host " Group Name:" $Groupname
			Write-Host " SamAccountName:" $GroupSamAccountName
			Write-Host " Category:" $GroupCategory
			Write-Host " Scope:" $GroupScope
			Write-Host " Displayname:" $GroupDisplayName  
			Write-Host " Description:" $GroupDescription 
			Write-Host " OU:" $GroupDistinguishedName
			
			Write-Log " Group Creation"
			Write-Log "-----------------------------------------------"
			Write-Log " Group Name: $Groupname"
			Write-Log " SamAccountName: $GroupSamAccountName"
			Write-Log " Category: $GroupCategory"
			Write-Log " Scope: $GroupScope"
			Write-Log " Displayname: $GroupDisplayName"
			Write-Log " Description: $GroupDescription"
			Write-Log " OU: $GroupDistinguishedName"


			#Read-Host -Prompt "Press any key to continue with group creation" # Enable for Debugging

			#Check to see if the group already exists in AD
			if (Get-ADGroup -F {SamAccountName -eq $GroupSamAccountName})
			{
				#If group does exist, give a warning
				Write-Log " A group with Groupname $Groupname already exist in Active Directory."
				Write-Host -ForegroundColor Red " A group with Groupname $Groupname already exist in Active Directory." `n
				
			}
			else
			{
				#Group does not exist then proceed to create the new group
						
				
				#Write Output to screen
				Write-Host " Group will be created with follwing Properties" -ForegroundColor Green
				Write-Host "-----------------------------------------------"
				Write-Host " GroupName:" $Groupname `n " Sam Account Name:" $GroupSamAccountName `n " Category:" $GroupCategory `n " Scope:" $GroupScope `n " Displayname:" $GroupDisplayName `n " Description:" $GroupDescription `n " OU:" $GroupDistinguishedName `n
				Write-Host "-----------------------------------------------"
				
				Write-Log " Group will be created with follwing Properties" -ForegroundColor Green
				Write-Log "-----------------------------------------------"
				Write-Log " GroupName: $Groupname"
				Write-Log " Sam Account Name: $GroupSamAccountName"
				Write-Log " Category:" $GroupCategory"
				Write-Log " Scope:" $GroupScope"
				Write-Log " Displayname: $GroupDisplayName"
				Write-Log " Description: $GroupDescription"
				Write-Log " OU: $GroupDistinguishedName"
				Write-Log "-----------------------------------------------"
				
				#Read-Host -Prompt "Press any key to continue" # Enable for Debugging

				#Group will be created
				try{
					Write-Log " Creating Group"
					Write-Host " Creating Group"
					New-ADGroup -Name $Groupname -SamAccountName $GroupSamAccountName -GroupCategory $GroupCategory -GroupScope $GroupScope -DisplayName $GroupDisplayName -Path $GroupDistinguishedName -Description $GroupDescription
				}
				catch{
					Write-Log " ERROR: Group could not be created!
		Reason: $_"
					Write-Host -ForegroundColor Red " ERROR: Group could not be created!
		Reason: $_"
				}
				
				#Write-Host "Group created" `n -ForegroundColor Green
				#$groupcreated = "true"
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
	
	Read-Host -Prompt " Press any key"
}


Import-ADGroups


