<#
.SYNOPSIS
    Links existing Group Policy Objects (GPOs) to their corresponding Organizational Units (OUs) based on a CSV import file.
	
.DESCRIPTION
    The **ou-gpo-link-import_final.ps1** script automates the process of linking Group Policy Objects (GPOs) 
    to specific Organizational Units (OUs) within an Active Directory environment.  
    This eliminates the need for manual GPO-to-OU assignments after domain deployment.

    The script performs the following actions:
    - Reads GPO-to-OU link definitions from a CSV file:
      ```
      C:\_it\ADC_Setup\6_AD_OU-GPO-Link_Import\ad_ou-gpo-link_import_final.csv
      ```
    - Validates that the Active Directory domain and the target OUs exist
    - Verifies that each specified GPO exists before attempting to link it
    - Checks whether the GPO is already linked to the OU to avoid duplicate links
    - Links the GPO to the specified OU if not already associated
    - Logs every action, warning, and error for traceability

    This script is typically executed **after** GPOs have been imported and OUs have been created, 
    as the final stage in Active Directory policy deployment.

    All operations are logged to:
    ```
    C:\_it\ADC_Setup\Logfiles\LinkGPOToOU.log
    ```

	Requirements:
	    - Windows Server 2016 or newer  
	    - PowerShell 5.1 or later  
	    - Active Directory Domain Services (ADDS) and Group Policy Management Console (GPMC) installed  
	    - Administrative privileges on the domain  
	    - Execution policy allowing script execution (`Set-ExecutionPolicy Bypass`)  
	    - CSV file with valid OU and GPO mappings  
		- AD OU Template
		- AD Group Template
		- AD GPOSet Import
	
.LINK
    https://learn.microsoft.com/en-us/powershell/module/grouppolicy/new-gplink  
    https://learn.microsoft.com/en-us/powershell/module/grouppolicy/get-gpo  
    https://learn.microsoft.com/en-us/powershell/module/activedirectory/get-adorganizationalunit  
	https://github.com/PScherling
	
.NOTES
          FileName: ou-gpo-link-import_final.ps1
          Solution: Active Directory GPO-to-OU Linking Automation
          Author: Patrick Scherling
          Contact: @Patrick Scherling
          Primary: @Patrick Scherling
          Created: 2025-01-03
          Modified: 2025-01-03

          Version - 0.0.1 - () - Finalized functional version 1.
          Version - 0.0.2 - () - Reworked and little additions.

          TODO:
		  
		
.Example
	PS> .\ou-gpo-link-import_final.ps1
    Imports the OU-to-GPO link mappings from the default CSV file and links the specified GPOs 
    to their target OUs if not already linked.

    PS> powershell.exe -ExecutionPolicy Bypass -File "C:\Scripts\ou-gpo-link-import_final.ps1"
    Runs the script non-interactively in an automated domain setup to apply GPO links 
    based on the defined import file.
#>

function Link-GPOtoOU {

	# Log file path
    $logFile = "C:\_it\ADC_Setup\Logfiles\LinkGPOToOU.log"
	
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
    $ImportOUGPOLinks = Import-csv -path 'C:\_it\ADC_Setup\6_AD_OU-GPO-Link_Import\ad_ou-gpo-link_import_final.csv' -Delimiter ";" -encoding utf8 # Standardpfad

    $response = ""
    $Domain = ""
    $DomainName = ""
    $DomainDistinguishedName = ""
    $GPO = ""
    $GetGPO = ""
    $GetADOU = ""
    $GetGPOOULinks = ""
    #$gpolinkcreated = "false"
    
    try{

        #Input for Domain Name
        while([string]::IsNullOrEmpty($DomainName)) {
            Write-Host "-----------------------------------------------------------------------------------"
            Write-Host "              Active Directory Configuration Setup"
	        Write-Host "              Linking GPOs with OUs"
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


        #Loop through each row containing GPO details in the CSV file
        Write-Log " Linking GPOs with OUs"
        foreach ($GPO in $ImportOUGPOLinks)
        {
	        #Read user data from each field in each row and assign the data to a variable as below
            if($GPO.Target -match "dc=") {
                $OUDistinguishedName = $DomainDistinguishedName
                #Write-Host $OUDistinguishedName
                #Read-Host -Prompt "Press Enter key"
            }
            else {
                $OUPath = $GPO.Target 
                $OUDistinguishedName = "$OUPath," + $DomainDistinguishedName 
		
		        try {
			        $GetADOU= get-adorganizationalunit -Identity "$OUDistinguishedName" | Select-Object -Property Name
		        }
		        catch {
                    Write-Log " ERROR: An error occured. There is no OU $OUDistinguishedName with this name existing in your system. You have to create the OUs first!" 
				    Write-Host -ForegroundColor Red " ERROR: An error occured. There is no OU '$OUDistinguishedName' with this name existing in your system. You have to create the OUs first!" 
				    #exit #Enable this for Debugging
		        }
            }

	        $GPOName = $GPO.DisplayName #Displayname
	
	        #Checking if the Group Policies are existing, that we are trying to link with our OUs
            #Checking if the OUs are existing, that we are trying to link with our GPOs
	        try {
			        $GetGPO = get-GPO -name "$GPOName" | Select-Object -Property DisplayName
	        }
	        catch {
                Write-Log " An error occured. There is no Group Policy $GetGPO with this name existing in your system. You have to import the Group Policies first!"
			    Write-Host -ForegroundColor Red " An error occured. There is no Group Policy '$GetGPO' with this name existing in your system. You have to import the Group Policies first!"
			    #exit #Enable this for Debugging
	        }
	
	        if((Get-GPInheritance -target "$OUDistinguishedName" | select -ExpandProperty GpoLinks | Select-Object DisplayName) -cmatch $GPOName)
	        {
                Write-Host " This GPO $GPOName is already linked with this OU $OUDistinguishedName - Nothing to do." 
		        Write-Host -ForegroundColor Green " This GPO '$GPOName' is already linked with this OU '$OUDistinguishedName'. Nothing to do." 
	        }
	        else{
		        #Write-Host "This GPO $GPOName will be linked with OU $OUDistinguishedName." -ForegroundColor Yellow
		        #Read-Host -Prompt "Press any key to continue with linking the GPO to the OU" # Enable for Debugging

			
		        #Write Output to screen
		        Write-Host " GPO will be linked with follwing OU"
		        Write-Host "-----------------------------------------------"
		        Write-Host " OU:" $OUDistinguishedName `n " GPO-Name:" $GPOName `n
		        Write-Host "-----------------------------------------------"

                Write-Log " GPO will be linked with follwing OU"
		        Write-Log "-----------------------------------------------"
		        Write-Log " OU: $OUDistinguishedName"
                Write-Log " GPO-Name: $GPOName"
		        Write-Log "-----------------------------------------------"
		
		        #Read-Host -Prompt "Press any key to continue" # Enable for Debugging
			
		
		        #GPO will be linked 
                try{  
		            New-GPLink -name $GPOName -target $OUDistinguishedName -Enforced No -LinkEnabled Yes #-WhatIf
                }
                catch{
                    Write-Log " ERROR: GPO could not be linked with OU!
	Reason: $_"
				    Write-Host -ForegroundColor Red " ERROR: GPO could not be linked with OU!
	Reason: $_"
                }
			 
		        #Write-Host "GPO $GPOName Linked with OU $OUDistinguishedName." `n -ForegroundColor Green
		
		        #Read-Host -Prompt "Press any key to continue" # Enable for Debugging
		
		        #$gpolinkcreated = "true"
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


Link-GPOtoOU
