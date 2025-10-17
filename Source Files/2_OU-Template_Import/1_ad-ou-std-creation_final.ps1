<#
.SYNOPSIS
    Creates a standardized Organizational Unit (OU) structure in Active Directory from a predefined CSV template.
	
.DESCRIPTION
	The **ad-ou-std-creation_final.ps1** script automates the creation of a consistent and hierarchical 
    Organizational Unit (OU) structure within an Active Directory domain based on a CSV import file.  
    It is designed to standardize Active Directory environments, ensuring predictable OU layouts across 
    multiple domains or deployments.

    The script:
    - Reads OU definitions from a structured CSV file located at:
      ```
      C:\_it\ADC_Setup\2_OU-Template_Import\ad_ou_template_final.csv
      ```
    - Retrieves and verifies the current domain configuration using `Get-ADDomain`
    - Constructs full Distinguished Names (DNs) for each OU dynamically
    - Checks for existing OUs before creation to avoid duplicates
    - Creates missing OUs with protection against accidental deletion
    - Provides real-time console feedback and detailed logging of every operation

    The script logs all actions, warnings, and errors to:
    ```
    C:\_it\ADC_Setup\Logfiles\OU-Template-Creation.log
    ```

    This script is typically executed after domain setup and initial configuration to deploy the 
    organizational baseline structure before applying Group Policy Objects or security delegations.

	Requirements:
	    - Windows Server 2016 or newer  
	    - PowerShell 5.1 or later  
	    - Active Directory Domain Services (ADDS) installed and configured  
	    - Administrative privileges  
	    - Valid CSV import file containing OU definitions  
	    - Execution policy allowing scripts (`Set-ExecutionPolicy Bypass`) 
    
.LINK
	https://learn.microsoft.com/en-us/powershell/module/activedirectory/new-adorganizationalunit  
    https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/understand-organizational-units  
	https://github.com/PScherling
    
.NOTES
          FileName: ad-ou-std-creation_final.ps1
          Solution: Active Directory Standard OU Structure Creation
          Author: Patrick Scherling
          Contact: @Patrick Scherling
          Primary: @Patrick Scherling
          Created: 2025-01-03
          Modified: 2025-01-03

          Version - 0.0.1 - () - Finalized functional version 1.
          Version - 0.0.2 - () - Reworked and little additions.

          TODO:
		  
		
.Example
	PS> .\ad-ou-std-creation_final.ps1
    Creates the entire OU structure defined in the CSV template file for the current domain.

    PS> powershell.exe -ExecutionPolicy Bypass -File "C:\Scripts\ad-ou-std-creation_final.ps1"
    Runs the OU creation script as part of an automated AD post-deployment setup, 
    creating all defined OUs from the provided CSV file.
#>

function Create-OU-Template {
	
	# Log file path
    $logFile = "C:\_it\ADC_Setup\Logfiles\OU-Template-Creation.log"
	
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

	$ImportADOUs = Import-csv -path 'C:\_it\ADC_Setup\2_OU-Template_Import\ad_ou_template_final.csv' -Delimiter ";" -encoding utf8 # Standardpfad
	$response = ""
	$Domain = ""
	$DomainName = ""
	$DomainDistinguishedName = ""
	#$oucreated = "false"

	try{
		#Input for Domain Name
		while([string]::IsNullOrEmpty($DomainName)) {
			#User Input for AD Name
			#$DomainName = Read-Host -Prompt 'Input Full DomainName (like domain.at)'
			Write-Host "-----------------------------------------------------------------------------------"
			Write-Host "              Active Directory Configuration Setup"
			Write-Host "              OU Creation Setup"
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
			Read-Host -Prompt "Press any key to continue for safety reasons!"
		}


		#Loop through each OU to create
		Write-Log " Creating OU Structure"
		foreach ($OU in $ImportADOUs)
		{
			#Read ou data from each field in each row and assign the data to a variable as below
			$OUName 	= $OU.Name
			$Path 		= $OU.OUPath
			$OUDistinguishedName = "$Path" + $DomainDistinguishedName #Full DistinguishedName
			
			Write-Host " OU Creation"
			Write-Host "-----------------------------------------------"
			Write-Host " OU Name:" $OUName   
			Write-Host " OU DistinguishedName:" $OUDistinguishedName
			
			Write-Log " OU Creation"
			Write-Log "-----------------------------------------------"
			Write-Log " OU Name: $OUName"
			Write-Log " OU DistinguishedName: $OUDistinguishedName"
			
			#Read-Host -Prompt "Press any key to continue with OU creation" # Enable for Debugging

			#Check to see if the OU already exists in AD
			Write-Log " Checking if OU already exists in AD"
			if (Get-ADOrganizationalUnit -F {Name -eq $OUName})
			{
				#If OU does exist, give a warning
				Write-Log " An OU with Name $OUName already exists in this Active Directory."
				Write-Host -ForegroundColor Red " An OU with Name $OUName already exists in this Active Directory." `n
			}
			else
			{
				#OU does not exist then proceed to create the new OU
				
				#Write Output to screen
				Write-Host " OU will be created with follwing Properties" -ForegroundColor Green
				Write-Host "-----------------------------------------------"
				Write-Host " OU Name:" $OUName
				Write-Host " OU DistinguishedName:" $OUDistinguishedName
				Write-Host "-----------------------------------------------" `n
				
				Write-Log " OU will be created with follwing Properties"
				Write-Log "-----------------------------------------------"
				Write-Log " OU Name: $OUName"
				Write-Log " OU DistinguishedName: $OUDistinguishedName"
				Write-Log "-----------------------------------------------"
				
				#Read-Host -Prompt "Press any key to continue" # Enable for Debugging

				#OU will be created
				try{
					Write-Log " Creating OU"
					Write-Host " Creating OU"
					New-ADOrganizationalUnit -Name $OUName -Path "$OUDistinguishedName" -ProtectedFromAccidentalDeletion $True
				}
				catch{
					Write-Log " ERROR: OU could not be created!
		Reason: $_"
					Write-Host -ForegroundColor Red " ERROR: OU could not be created!
		Reason: $_"
				}
				
				#Write-Log " OU created"
				#Write-Host "OU created" `n -ForegroundColor Green
				#$oucreated = "true"
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


Create-OU-Template

