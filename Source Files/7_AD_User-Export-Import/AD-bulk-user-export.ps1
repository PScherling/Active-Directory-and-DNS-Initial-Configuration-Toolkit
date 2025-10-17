<#
.SYNOPSIS
    Exports Active Directory user accounts from a selected Organizational Unit (OU) into a structured CSV file.
	
.DESCRIPTION
	The **AD-bulk-user-export.ps1** script automates the export of user account data 
    from Active Directory to a CSV file for documentation, migration, or replication purposes.

    The script allows the administrator to:
    - Automatically detect the Active Directory domain
    - Display all available Organizational Units (OUs)
    - Interactively select an OU for export
    - Retrieve all user accounts within the selected OU
    - Export detailed user properties to a UTF-8 encoded CSV file
    - Save the export file to a user-defined or default location:
      ```
      C:\_it\<DomainName>_<OUName>_ad-user-export.csv
      ```
    - Log all operations, errors, and user actions to:
      ```
      C:\_it\ADC_Setup\Logfiles\Export-ADUsers.log
      ```

    The exported file can be used for:
    - Backup or documentation of AD user structures
    - Data migration between domains
    - Automated reimport in provisioning scripts (e.g. user-import_final.ps1)
    - Reporting and compliance audits

    Exported user properties include (by default):
    ```
    Enabled, SamAccountName, GivenName, Surname, DisplayName, Path, 
    Password (placeholder), ProfilePath, EmailAddress, HomeDirectory, HomeDrive, 
    legacyExchangeDN, City, Country, Description, State, Title, PostalCode, 
    Department, Company
    ```

    Administrators can easily customize this list to include or exclude specific attributes 
    (e.g., `ProfilePath`, `EmailAddress`, etc.) depending on organizational needs.

	Requirements:
	    - Windows Server 2016 or newer  
	    - PowerShell 5.1 or later  
	    - Active Directory Module for Windows PowerShell  
	    - Domain administrative privileges  
	    - Execution policy allowing script execution (`Set-ExecutionPolicy Bypass`) 
    
.LINK
	https://learn.microsoft.com/en-us/powershell/module/activedirectory/get-aduser  
    https://learn.microsoft.com/en-us/powershell/module/activedirectory/get-adorganizationalunit  
    https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/export-csv  
	https://github.com/PScherling
    
.NOTES
          FileName: AD-bulk-user-export.ps1
          Solution: Active Directory Bulk User Export Automation  
          Author: Patrick Scherling
          Contact: @Patrick Scherling
          Primary: @Patrick Scherling
          Created: 2020-11-23
          Modified: 2025-09-17

          Version - 0.0.1 - () - Finalized functional version 1.
          Version - 0.0.2 - () - Umlautabfrage hinzugefügt.
		  Version - 0.0.3 - () - LegacyDN zum Export hinzugefügt (wichtig für X500 Mailadressen).
		  Version - 0.0.4 - () - Reworking the whole script for better usability.
		  Version - 0.0.5 - () - Adaption for efsconfig.
          Version - 0.0.6 - () - Adding more Properties for User to export (like ILS MUC needed)
          Version - 0.0.7 - () - Adding user property "Enabled" to export

          TODO:
		  
		
.Example
	PS> .\AD-bulk-user-export.ps1
    Displays all available OUs in the domain, prompts for selection, 
    then exports all user data from the chosen OU into a CSV file in the default path.

    PS> powershell.exe -ExecutionPolicy Bypass -File "C:\Scripts\AD-bulk-user-export.ps1"
    Executes the export process non-interactively during a scheduled administrative task, 
    generating a CSV file containing user data for documentation or replication.
#>

#Import active directory module for running AD cmdlets
#Import-Module activedirectory


function EF-Export-ADUsers {
    Clear-Host
	# Log file path
    $logFile = "C:\_it\ADC_Setup\Logfiles\Export-ADUsers.log"
	
	# CSV Export Path
	$ExportPath = ""
	
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
	  
	
	$response = ""
	$Domain = ""
	$DomainName = ""
	$DomainDistinguishedName = ""
	$User = ""
	#$usercreated = "false"

	$OrgUnits = @()
    $selectedOU = ""

	try{

		#Input for Domain Name
		while([string]::IsNullOrEmpty($DomainName)) {

			Write-Host "-----------------------------------------------------------------------------------"
			Write-Host "              Active Directory Management"
			Write-Host "              AD User Export"
			Write-Host "-----------------------------------------------------------------------------------" `n
			
			#Checking if a domain was set-up in the first place before running the script
			try {
				Write-Log " Try to get AD-Domain"
				$Domain = get-addomain
			}
			catch {
				Write-Log " ERROR: AD-Domain could not be found! There is no Domain existing in your system. You have to run this within an AD!
    Reason: $_"
				Write-Host -ForegroundColor Red "ERROR: AD-Domain could not be found! There is no Domain existing in your system. You have to run this within an AD!
    Reason: $_"
                Read-Host -Prompt " Press any key to exit"
				exit
			}
			
			Write-Host " This is your Domain"
			Write-Host "-----------------------------------------------"
			$DomainName = $Domain.DNSRoot
			$DomainDistinguishedName = $Domain.DistinguishedName
			Write-Host " The Domain Name is:" $DomainName -ForegroundColor Green
			Write-Host " The Domain Distinguished-Name is:" $DomainDistinguishedName -ForegroundColor Green
			Write-Host "-----------------------------------------------"
			
			Write-Log " This is your Domain"
			Write-Log "-----------------------------------------------"
			Write-Log " The Domain Name is: $DomainName"
			Write-Log " The Domain Distinguished-Name is: $DomainDistinguishedName"
			Write-Log "-----------------------------------------------"
			
			$response = ""
			while($response -ne "y") {
				Write-Log " Waiting for user input"
				$response = Read-Host -Prompt "Press (y) to approve and continue or (a) to abort"
				if($response -eq "a") {
					Write-Log " User input was (a) to abort."
					exit
				}
			}
			#Read-Host -Prompt "Press any key to continue for safety reasons"
		}
		
		# Fill Array with OU Information
		try{
			$OrgUnits = Get-ADOrganizationalUnit -Filter 'Name -like "*"' | select-object Name, DistinguishedName #| Format-Table Name, DistinguishedName -A
		}
		catch{
			Write-Log " ERROR: Can not fetch OU information from Domain!
    Reason: $_"
			Write-Host -ForegroundColor Red "ERROR: Can not fetch OU information from Domain!
    Reason: $_"
            Read-Host -Prompt " Press any key to exit"
			exit
		}

        # Output for Debug
        <#Write-Host " This are your OUs"
        Write-Host "-----------------------------------------------"
        $OrgUnits | ft -AutoSize
        Write-Host "-----------------------------------------------"#>
		
		Write-Log " This are your OUs"
		Write-Log "-----------------------------------------------"
        $OrgUnits | ForEach-Object {
            Write-Log " $($_.Name) --> $($_.DistinguishedName)"
        }
		Write-Log "-----------------------------------------------"

        # Selecting OU
        do{

            Write-Host `n " Organizational Units:"
            Write-Host "-----------------------------------------------"
            $Count = $OrgUnits.Count - 1
            foreach ($x in 0..$Count){
                $OUName = $OrgUnits.Name[$x]
                $OUDName = $OrgUnits.DistinguishedName[$x]

                Write-Host " $x) $OUName"
            }
            Write-Host "-----------------------------------------------"
            
            do {
                $choice = Read-Host " Choose an OU (0 - $Count)"
                Write-Log " User Input: $choice"
            } while (-not ($choice -as [int] -in 0..$Count))
            
            $selectedOUName = $OrgUnits.Name[$choice]
            $selectedOUDName = $OrgUnits.DistinguishedName[$choice]

            Write-Host `n " This is your selected OU"
		    Write-Host "-----------------------------------------------"
		    Write-Host " The OU Name is:" $selectedOUName -ForegroundColor Green
		    Write-Host " The OU Distinguished-Name is:" $selectedOUDName -ForegroundColor Green
		    Write-Host "-----------------------------------------------"
			
		    Write-Log " This is your selected OU"
		    Write-Log "-----------------------------------------------"
		    Write-Log " The OU Name is: $selectedOUName"
		    Write-Log " The OU Distinguished-Name is: $selectedOUDName"
		    Write-Log "-----------------------------------------------"
		    
            $response = ""
            while($response -ne "y") {
			    Write-Log " Waiting for user input"
                Write-Host -ForegroundColor Yellow " Warning!"
			    $response = Read-Host -Prompt " Press (y) to approve and begin with export or (a) to abort"
			    if($response -eq "a") {
				    Write-Log " User input was (a) to abort."
				    exit
			    }
		    }

            # Try to get users in the selected OU
            try{
                $Users = Get-ADUser -Filter * -SearchBase $selectedOUDName -Properties * | 
                    Select-Object -Property `
                        Enabled, `
                        SamAccountName, `
                        GivenName, `
                        Surname, `
                        Name, `
                        HomeDirectory, `
                        HomeDrive, `
                        ProfilePath, `
                        EmailAddress, `
                        legacyExchangeDN, `
                        City, `
                        Country, `
                        Description, `
                        State, `
                        Title, `
                        PostalCode, `
                        Department, `
                        Company 
                    #Bei Bedarf anpassen!
            }
            catch{
                Write-Log " ERROR: Can not gather Users in selected OU!
        Reason: $_"
			    Write-Host -ForegroundColor Red "ERROR: Can not gather Users in selected OU!
        Reason: $_"
                Read-Host -Prompt " Press any key to exit"
                exit
            }

            # Check if no users were found
            if (-not $Users -or $Users.Count -eq 0) {
                Write-Log " WARNING: No users found in the selected OU: $selectedOUName"
                Write-Host -ForegroundColor Yellow "WARNING: No users found in the selected OU: $selectedOUName"`n
            
                $tryAgain = Read-Host " Do you want to select another OU? (y/n)"
                Write-Log " User Input: $tryAgain"
                if ($tryAgain -ne 'y') {
                    Write-Log "User chose not to try a different OU. Exiting."
                    exit
                }
                else{
                    Write-Log "User choose to select a different OU."
                }
            }
            else{
                # Users found, exit loop
                break
            }
        } while ($true)

        Write-Host `n "-----------------------------------------------"
        Write-Host " Beginning with User-Export from selected OU..."
        
        Write-Log "-----------------------------------------------"
        Write-Log " Beginning with User-Export from selected OU..."

        <#foreach ($User in $Users) {
	        $AccountName = $User.SamAccountName
	        $FirstName = $User.GivenName
	        $LastName = $User.Surname
	        $DisplayName = $User.Name
	        $HomeDirectory = $User.HomeDirectory
	        $HomeDrive = $User.HomeDrive
            $Mail = $User.EmailAddress
	        $LegacyDN = $User.legacyExchangeDN

            $stringToPost = $AccountName + ";" + $FirstName + ";" + $LastName + ";" + $DisplayName + ";" + $HomeDirectory + ";" + $HomeDrive + ";" + $Mail + ";" + $LegacyDN
            Write-Host `n " Exporting User: $($DisplayName)"
            Write-Host "-> $($stringToPost)"

            Write-Log " Exporting User: $($DisplayName)"
            Write-Log "-> $($stringToPost)"
   
        }#>
		
		$ExportUsers = @()

        foreach ($User in $Users) {
            $ExportObject = [PSCustomObject]@{
                Enabled        = $User.Enabled
                Username       = $User.SamAccountName
                Firstname      = $User.GivenName
                Lastname       = $User.Surname
                DisplayName    = $User.Name
                Path           = $selectedOUDName
                Password       = "Password"       # Default or placeholder password
                ProfilePath    = $User.ProfilePath
                EmailAddress   = $User.EmailAddress
                HomeDirectory  = $User.HomeDirectory
                HomeDrive      = $User.HomeDrive
                LegacyDN 	   = $User.legacyExchangeDN
                City		   = $User.City
                Country	       = $User.Country
                Description    = $User.Description
                State		   = $User.State
                Title		   = $User.Title
                PostalCode	   = $User.PostalCode
                Department	   = $User.Department
                Company	       = $User.Company
            }

            $ExportUsers += $ExportObject

            Write-Host "`n Exporting User: $($User.Name)"
            Write-Host "-> $($ExportObject | ConvertTo-Csv -Delimiter ';' -NoTypeInformation | Select-Object -Skip 1)"
            Write-Log " Exporting User: $($User.Name)"
        }

        # Ask for Export Path
        Write-Host `n "-----------------------------------------------"
        do {
            Write-Host "`n Please enter the path to export the CSV file or press enter to use default location."
            $ExportPath = Read-Host " (Default: C:\_it\$($DomainName)_$($selectedOUName)_ad-user-export.csv)"
            Write-Log " User Input for Export Path: $ExportPath"

            # Check if input is empty
            if ([string]::IsNullOrWhiteSpace($ExportPath)) {
                #Write-Host -ForegroundColor Yellow " Export path cannot be empty."
                #Write-Log " WARNING: Export path can not be empty!"
                #continue
				$ExportPath = "C:\_it\$($DomainName)_$($selectedOUName)_ad-user-export.csv"
				Write-Host -ForegroundColor Yellow " Path for export is '$ExportPath'"
				Write-Log " Path for export is '$ExportPath'"
            }

            # Check for invalid characters in path
            if ($ExportPath.IndexOfAny([System.IO.Path]::GetInvalidPathChars()) -ne -1) {
                Write-Host -ForegroundColor Red " ERROR: The path contains invalid characters."
                Write-Log " ERROR: Export path contains invalid characters."
                $ExportPath = ""
                continue
            }

            # Extract directory path from full file path
            $Directory = [System.IO.Path]::GetDirectoryName($ExportPath)

            # Check if directory exists
            if (-not (Test-Path -Path $Directory)) {
                Write-Host -ForegroundColor Yellow " WARNING: The directory '$Directory' does not exist."
                Write-Log " WARNING: The directory '$Directory' does not exist."
                $ExportPath = ""
                continue
                
            }

            # Check if file already exists
            if (Test-Path $ExportPath) {
                Write-Host -ForegroundColor Yellow " WARNING: File already exists at $ExportPath"
                $overwrite = Read-Host " Do you want to overwrite it? (y/n)"
                if ($overwrite -ne 'y') {
                    $ExportPath = ""
                    continue
                } else {
                    Write-Log " User chose to overwrite existing file."
                }
            }

        } while ([string]::IsNullOrEmpty($ExportPath))

        try{
            #$Users | Export-CSV $ExportPath -Delimiter ';' -encoding utf8 -NoTypeInformation
            $ExportUsers | Export-CSV $ExportPath -Delimiter ';' -Encoding UTF8 -NoTypeInformation
        }
        catch{
            Write-Log " ERROR: Information can not be saved in csv file!
    Reason: $_"
			Write-Host -ForegroundColor Red "ERROR: Information can not be saved in csv file!
    Reason: $_"
            Read-Host -Prompt " Press any key to exit"
            exit
        }
		
	}
    catch {
        Write-Host  -ForegroundColor Red " Error: An unexpected error occurred: $_"
        Write-Log " Error: An unexpected error occurred: $_"

        Read-Host -Prompt " Press any key to exit"
        exit
    } 
	finally {
        # End logging
        Write-Log "End of configuration process."
    }
	
	Read-Host -Prompt " Press any key to leave"
}



EF-Export-ADUsers

