<#
.SYNOPSIS
    Imports and creates Active Directory user accounts from a predefined CSV template.
	
.DESCRIPTION
    The **user-import_final.ps1** script automates the mass creation of Active Directory user accounts 
    from a structured CSV import file.  
    It ensures standardized user provisioning, correct OU placement, consistent naming, and password initialization 
    across enterprise environments.

    The script performs the following actions:
    - Loads a CSV file containing user account details from:
      ```
      C:\_psc\ADC_Setup\4_AD_User_Import\ad_user_import_final.csv
      ```
    - Retrieves and validates the Active Directory domain context  
    - Checks for existing users before attempting creation to avoid duplicates  
    - Creates new accounts with proper attributes including:
        - **SamAccountName**
        - **GivenName**
        - **Surname**
        - **DisplayName**
        - **Description**
        - **OU Path**
        - **Password**
    - Optionally disables the built-in "Administrator" account for improved security  
    - Provides full console feedback and logs all actions, warnings, and errors  

    The script logs all operations to:
    ```
    C:\_psc\ADC_Setup\Logfiles\Import-ADUsers.log
    ```

    It is typically executed after the OU and group structure have been deployed, 
    as part of an automated domain setup or user onboarding process.

	Requirements:
	    - Windows Server 2016 or newer  
	    - PowerShell 5.1 or later  
	    - Active Directory Domain Services (ADDS) installed and configured  
	    - Administrative privileges on the domain  
	    - Valid CSV input file with correct field headers  
	    - Execution policy allowing script execution (`Set-ExecutionPolicy Bypass`)  
		- AD OU Template
		- AD Group Template
	
.LINK
	https://learn.microsoft.com/en-us/powershell/module/activedirectory/new-aduser  
    https://learn.microsoft.com/en-us/powershell/module/activedirectory/get-aduser 
	https://github.com/PScherling
    
.NOTES
          FileName: user-import_final.ps1
          Solution: Active Directory User Import Automation 
          Author: Patrick Scherling
          Contact: @Patrick Scherling
          Primary: @Patrick Scherling
          Created: 
          Modified: 2025-01-03

          Version - 0.0.1 - () - Finalized functional version 1.
          Version - 0.0.2 - () - Reworked and little additions.

          TODO:
		  
		
.Example
	PS> .\user-import_final.ps1
    Imports and creates all user accounts defined in the CSV file for the current Active Directory domain.

    PS> powershell.exe -ExecutionPolicy Bypass -File "C:\Scripts\user-import_final.ps1"
    Executes the script automatically during a domain provisioning sequence to populate 
    the directory with all required users.
#>

function Import-ADUsers {

	# Log file path
    $logFile = "C:\_psc\ADC_Setup\Logfiles\Import-ADUsers.log"
	
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
	$ImportADUsers = Import-csv -path 'C:\_psc\ADC_Setup\4_AD_User_Import\ad_user_import_final.csv' -Delimiter ";" -encoding utf8 # Standardpfad
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
			Write-Host "              AD User Setup"
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
		Write-Log " Importing AD Users"
		foreach ($User in $ImportADUsers)
		{
			#Read user data from each field in each row and assign the data to a variable as below
				
			$Username 	= $User.Username #SamAccountName aka AccountName aka LogonName
			$Firstname 	= $User.Firstname #GivenName
			$Lastname 	= $User.Lastname #Surname
			$Name       = $User.Displayname #Name in AD Users & Computers
			$DisplayName = $User.Displayname #Displayname at Logon
			$Description = $User.Description #User Description for additional information
			$Path 		= $User.OUPath #This field refers to the OU the user account is to be created in
			$DistinguishedName = "$Path," + $DomainDistinguishedName #Full DistinguishedName
			$Password   = $User.Password
			#$ProfilePath = $User.ProfilePath
			#$EmailAddress = $User.EmailAddress
			#$HomeDirectory = $User.HomeDirectory
			#$HomeDrive = $User.HomeDrive
			
			#Write Output to screen
			Write-Host " User Creation"
			Write-Host "-----------------------------------------------"
			Write-Host " Username:" $Username
			Write-Host " Firstname:" $Firstname
			Write-Host " Lastname:" $Lastname
			Write-Host " Displayname:" $Displayname
			Write-Host " Description:" $Description    
			Write-Host " OU:" $DistinguishedName
			#Write-Host " Home Directory:" $HomeDirectory$Username
			#Write-Host " Home Drive:" $HomeDrive
			#Write-Host " Principal Name:" "$Username@$DomainName"
			
			Write-Log " User Creation"
			Write-Log "-----------------------------------------------"
			Write-Log " Username: $Username"
			Write-Log " Firstname: $Firstname"
			Write-Log " Lastname: $Lastname"
			Write-Log " Displayname: $Displayname"
			Write-Log " Description: $Description"   
			Write-Log " OU: $DistinguishedName"
			#Write-Log " Home Directory: $HomeDirectory$Username"
			#Write-Log " Home Drive: $HomeDrive"
			#Write-Log " Principal Name:" "$Username@$DomainName"

			#Read-Host -Prompt "Press any key to continue with User creation" # Enable for Debugging

			#Check to see if the user already exists in AD
			if (Get-ADUser -F {SamAccountName -eq $Username})
			{
				#If user does exist, give a warning
				Write-Log " A user account with username $Username already exist in Active Directory."
				Write-Host -ForegroundColor Red " A user account with username $Username already exist in Active Directory." `n
			}
			else
			{
				#User does not exist then proceed to create the new user account
						
				
				#Testausgabe der User wie sie angelegt werden
				#$stringToPost = "AccountName: "+ $Username + " - " + "Principal: " + "$Username@$DomainName"  + " - " + "Name: " + $DisplayName  + " - " + "GivenName: " + $Firstname  + " - " + "Surname: " + $Lastname  + " - " + "DisplayName: " + $DisplayName  + " - " + "Path: " + $DistinguishedName  + " - " + "HomeDirectory: " + "$HomeDirectory$Username"  + " - " + "HomeDrive: " + $HomeDrive  + " - " + "Password: " + $Password  
				#Write-Host $stringToPost `n
				
				#Write Output to screen
				Write-Host " User will be created with follwing Properties" -ForegroundColor Green
				Write-Host "-----------------------------------------------"
				Write-Host " AccountName:" $Username `n " Principal Name:" "$Username@$DomainName" `n " Name:" $Name `n " GivenName:" $Firstname `n " Surname:" $Lastname `n " Displayname:" $Displayname `n " Description:" $Description `n " OU-Path:" $DistinguishedName `n
				Write-Host "-----------------------------------------------"
				#Write-Host "AccountName:" $Username
				#Write-Host "Principal Name:" "$Username@$DomainName"
				#Write-Host "Name:" $Name
				#Write-Host "GivenName:" $Firstname
				#Write-Host "Surname:" $Lastname
				#Write-Host "Displayname:" $Displayname
				#Write-Host "OU-Path:" $DistinguishedName
				#Write-Host "Home Directory:" $HomeDirectory$Username
				#Write-Host "Home Drive:" $HomeDrive `n
				
				Write-Log " User will be created with follwing Properties"
				Write-Log "-----------------------------------------------"
				Write-Log " AccountName: $Username"
				Write-Log " Principal Name: $Username@$DomainName"
				Write-Log " Name: $Name"
				Write-Log " GivenName: $Firstname"
				Write-Log " Surname: $Lastname"
				Write-Log " Displayname: $Displayname"
				Write-Log " Description: $Description"
				Write-Log " OU-Path: $DistinguishedName"
				Write-Log "-----------------------------------------------"

				#Read-Host -Prompt "Press any key to continue" # Enable for Debugging

				#Account will be created
				try{
					Write-Log " Creating User"
					Write-Host " Creating User"
					New-ADUser -SamAccountName $Username -UserPrincipalName "$Username@$DomainName" -name $Name -GivenName $Firstname -Surname $Lastname -Enabled $True -DisplayName $DisplayName -Description $Description -path "$DistinguishedName" -AccountPassword (ConvertTo-SecureString $Password -AsPlainText -Force) -ChangePasswordAtLogon $false -PasswordNeverExpires $true
				}
				catch{
					Write-Log " ERROR: Group could not be created!
		Reason: $_"
					Write-Host -ForegroundColor Red " ERROR: Group could not be created!
		Reason: $_"
				}
				
				#Write-Host "User created" `n -ForegroundColor Green
				#$usercreated = "true"
			}

		}

		# Deaktivate Default Domain Administrator
		Write-Log " Built-In Administrator Account is still active"
		$deactivateAdmin = "false"
		while($deactivation -ne 'y' -and $deactivation -ne 'n'){
			Write-Log " Waiting for user input"
			$deactivation = Read-Host " Do you want to deactivate the Built-In Domain Administrator User Account called 'Administrator'? (y/n)"
			if($deactivation -eq 'y') {
				Write-Log " User input is (y)"
				Write-Log " Deactivating the Built-In Administrator Account"
				Write-Host " Deactivating the Built-In Administrator Account"
				
				Disable-ADAccount -Identity "Administrator" -Confirm
				
				$deactivateAdmin = "true"
				
			}
			elseif($deactivation -eq 'n') {
				Write-Log " User input is (n)"
				Write-Log " Built-In Administrator Account will not be deactivated. This may be a scurity risk!"
				Write-Host -ForegroundColor Yellow " Built-In Administrator Account will not be deactivated. This may be a scurity risk!"
				
			}
			elseif($deactivation -ne 'y' -and $deactivation -ne 'n') {
				Write-Host " Wrong Input" -ForegroundColor Red
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


Import-ADUsers

