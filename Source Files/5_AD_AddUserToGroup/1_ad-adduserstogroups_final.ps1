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
      English (en-US): C:\_it\ADC_Setup\5_AD_AddUserToGroup\ad_group-list_final.csv
      German (de-DE):  C:\_it\ADC_Setup\5_AD_EF_AddUserToGroup\de-DE\ad_ef-group-list_de_final.csv
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
      C:\_it\ADC_Setup\Logfiles\AddUsersToGroups.log
      ```
    - For German systems:
      ```
      C:\_it\ADC_Setup\Logfiles\AddUsersToGroups_DE.log
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
          Modified: 2025-01-07

          Version - 0.0.1 - () - Finalized functional version 1.
          Version - 0.0.2 - () - Reworked and little additions.
		  Version - 0.0.3 - () - Integrating "DE" Version

          TODO:
		  
		
.Example
	PS> .\ad-adduserstogroups_final.ps1
    Automatically detects the system language and executes the corresponding process 
    to add users to groups as defined in the CSV file.

    PS> powershell.exe -ExecutionPolicy Bypass -File "C:\Scripts\ad-adduserstogroups_final.ps1"
    Runs the script non-interactively in an automated domain setup pipeline, 
    assigning users to their respective AD groups based on the import file.
#>

function Check-OSLanguage {
	$OSLanguage = Get-ComputerInfo | Select-Object OSLanguage
	$Lang = $OSLanguage.OSLanguage
	
	if($Lang -eq "en-US") {
		Add-UsersToGroups
	}
	elseif($Lang -eq "de-DE") {
		Add-UsersToGroups-DE
	}
	else{
		Write-Host -ForegroundColor Red " ERROR: No valid OS Language found. Your installed OS Language is $Lang"
		Read-Host -Prompt " Press any key"
	}
	
}

function Add-UsersToGroups {

	# Log file path
    $logFile = "C:\_it\ADC_Setup\Logfiles\AddUsersToGroups.log"
	
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
	$ImportADGroups = Import-csv -path 'C:\_it\ADC_Setup\5_AD_AddUserToGroup\ad_group-list_final.csv' -Delimiter ";" #-Encoding utf8 # Standardpfad
	$response = ""
	$Domain = ""
	$DomainName = ""
	$DomainDistinguishedName = ""
	$User = ""
	#$usercreated = "false"

	try{

		#Input for Domain Name
		while([string]::IsNullOrEmpty($DomainName)) {
			Write-Host "-----------------------------------------------------------------------------------"
			Write-Host "              Active Directory Configuration Setup"
			Write-Host "              Adding Users to Groups"
			Write-Host "-----------------------------------------------------------------------------------" `n

			#Checking if a domain was set-up in the first place before running the script
			try {
				Write-Log " Try to get AD-Domain"
				$Domain = get-addomain
			}
			catch {
				Write-Log " ERROR: AD-Domain could not be found! There is no Domain existing in your system. You have to set up the Domain Controller first
		Reason: $_"
				Write-Host -ForegroundColor Red " ERROR: AD-Domain could not be found! There is no Domain existing in your system. You have to set up the Domain Controller first
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
		Write-Log " Adding AD Users to AD Groups"
		foreach ($Group in $ImportADGroups)
		{
			#Read user data from each field in each row and assign the data to a variable as below
			$GroupName = $Group.Name # Gruppenname	
			$SamAccountNames = $Group.Members #Usernames
			$GroupMembersArray = $SamAccountNames.Split(',')
			

			#Read-Host -Prompt "Press any key to continue to check if user exists in AD" # Enable for Debugging

			#Check to see if the user already exists in AD
			
			foreach ($User in $GroupMembersArray)
			{
				$User = $User.ToString()     
				Write-Log " Check to see if the user already exists in AD"
				if (Get-ADUser -F {SamAccountName -eq $User})
				{
					#User exist then proceed to put in groups
					#If user exist
					Write-Log " A user account with username $User exists in Active Directory."
					Write-Host -ForegroundColor Green " A user account with username $User exists in Active Directory." `n		
				
					$usercreated = "true"
					
					Write-Log " User who will be added to Group $Groupname - $User"
					Write-Host " User who will be added to Group "$Groupname": " $User
		  
					#Read-Host -Prompt "Press any key to add user to the group" # Enable for Debugging

					$Members = Get-ADGroupMember -Identity $GroupName -Recursive | Select -ExpandProperty SamAccountName
					Write-Log " Check to see if the user already is member of group"
					if($Members -contains $User)
					{
						#Is member so do nothing.
						Write-Log " There is nothing to do! User is already member of group $GroupName"
						Write-Host -ForegroundColor Yellow " There is nothing to do! User is already member of group $GroupName" `n
			
					}
					else
					{
						#Is not member so add user.
						Write-Log " User is not member of group $GroupName"
						Write-Log " Adding User..."
						
						Write-Host " User is not member of group $GroupName"
						Write-Host " Adding User..." `n
						
						try{
							Add-ADGroupMember -Identity $GroupName -Members $User #-WhatIf
						}
						catch{
							Write-Log " ERROR: User could not be added to Group!
	Reason: $_"
							Write-Host -ForegroundColor Red " ERROR: User could not be added to Group!
	Reason: $_"
						}
				
						#Write-Host "User added to group" `n -ForegroundColor Green
					}		

				}
				else
				{
					#If user does not exist, give a warning
					Write-Log " A user account with username $User does not exist in Active Directory." `n
					Write-Host -ForegroundColor Red " A user account with username $User does not exist in Active Directory." `n
					$usercreated = "false"
	    
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
	
	Read-Host -Prompt " Press any key"
	
}

function Add-UsersToGroups-DE {
	# Log file path
    $logFile = "C:\_it\ADC_Setup\Logfiles\AddUsersToGroups_DE.log"
	
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
	$ImportADGroups = Import-csv -path 'C:\_it\ADC_Setup\5_AD_EF_AddUserToGroup\de-DE\ad_ef-group-list_de_final.csv' -Delimiter ";" #-Encoding utf8 # Standardpfad
	$response = ""
	$Domain = ""
	$DomainName = ""
	$DomainDistinguishedName = ""
	$User = ""
	#$usercreated = "false"
	

	try{
		#Input for Domain Name
		while([string]::IsNullOrEmpty($DomainName)) {
			Write-Host "-----------------------------------------------------------------------------------"
			Write-Host "              Active Directory Setup"
			Write-Host "              Adding Users to Groups"
			Write-Host -ForegroundColor Yellow "              Edition for ADCs in German"
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
		Write-Log " Adding AD Users to AD Groups"
		foreach ($Group in $ImportADGroups)
		{
			#Read user data from each field in each row and assign the data to a variable as below
			$GroupName = $Group.Name # Gruppenname	
			$SamAccountNames = $Group.Members #Usernames
			$GroupMembersArray = $SamAccountNames.Split(',')
			

			#Read-Host -Prompt "Press any key to continue to check if user exists in AD" # Enable for Debugging

			#Check to see if the user already exists in AD
			
			foreach ($User in $GroupMembersArray)
			{
				$User = $User.ToString()     
				Write-Log " Check to see if the user already exists in AD"
				if (Get-ADUser -F {SamAccountName -eq $User})
				{
					#User exist then proceed to put in groups
					#If user exist
					Write-Log " A user account with username $User exists in Active Directory."
					Write-Host -ForegroundColor Green " A user account with username $User exists in Active Directory." `n		
				
					$usercreated = "true"
					
					Write-Log " User who will be added to Group $Groupname - $User"
					Write-Host " User who will be added to Group "$Groupname": " $User
		  
					#Read-Host -Prompt "Press any key to add user to the group" # Enable for Debugging

					$Members = Get-ADGroupMember -Identity $GroupName -Recursive | Select -ExpandProperty SamAccountName
					Write-Log " Check to see if the user already is member of group"
					if($Members -contains $User)
					{
						#Is member so do nothing.
						Write-Log " There is nothing to do! User is already member of group $GroupName"
						Write-Host -ForegroundColor Yellow " There is nothing to do! User is already member of group $GroupName" `n
			
					}
					else
					{
						#Is not member so add user.
						Write-Log " User is not member of group $GroupName"
						Write-Log " Adding User..."
						
						Write-Host " User is not member of group $GroupName"
						Write-Host " Adding User..." `n
						
						try{
							Add-ADGroupMember -Identity $GroupName -Members $User #-WhatIf
						}
						catch{
							Write-Log " ERROR: User could not be added to Group!
	Reason: $_"
							Write-Host -ForegroundColor Red " ERROR: User could not be added to Group!
	Reason: $_"
						}
				
						#Write-Host "User added to group" `n -ForegroundColor Green
					}		

				}
				else
				{
					#If user does not exist, give a warning
					Write-Log " A user account with username $User does not exist in Active Directory." `n
					Write-Host -ForegroundColor Red " A user account with username $User does not exist in Active Directory." `n
					$usercreated = "false"
	    
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
	
	Read-Host -Prompt " Press any key"
}


Check-OSLanguage

