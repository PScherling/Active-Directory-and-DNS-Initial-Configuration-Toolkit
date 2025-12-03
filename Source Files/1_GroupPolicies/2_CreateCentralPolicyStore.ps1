<#
.SYNOPSIS
    Creates a Central Policy Store for Group Policy Objects (GPOs) within an Active Directory domain.
	
.DESCRIPTION
    The **2_CreateCentralPolicyStore.ps1** script automates the creation and deployment of the 
    **Central Policy Store (CPS)** used by Group Policy Management across the domain.

    The Central Policy Store is a centralized repository located in the SYSVOL directory that holds 
    administrative template files (`.admx` and `.adml`). By hosting these templates centrally, 
    administrators ensure that all Group Policy Management Consoles (GPMC) within the domain use 
    the same set of templates, maintaining consistency and version control.

    This script:
    - Validates the existence of the **PolicyDefinitions** source directory
    - Determines the correct domain name dynamically via Active Directory
    - Creates the necessary folder structure under:
      ```
      C:\AD\SYSVOL\sysvol\<DomainName>\Policies\PolicyDefinitions
      ```
    - Copies all `.admx` and `.adml` files (including hidden/system files) recursively
    - Logs every step, including errors and file operations, to a persistent log file:
      ```
      C:\_psc\ADC_Setup\Logfiles\CreateCentralPolicyStore.log
      ```

    This script is intended to be executed **after Active Directory and SYSVOL are fully initialized**, 
    as part of the post-domain setup or GPO infrastructure configuration phase.

	Requirements:
	    - Windows Server 2016 or newer  
	    - PowerShell 5.1 or later  
	    - Active Directory Domain Services installed and configured  
	    - SYSVOL and Policies directories available  
	    - Administrative privileges  
	    - Execution policy allowing scripts (`Set-ExecutionPolicy Bypass`) 
	
.LINK
    https://learn.microsoft.com/en-us/troubleshoot/windows-server/group-policy/create-and-manage-central-store  
    https://learn.microsoft.com/en-us/windows/client-management/administrative-template-files 
	https://github.com/PScherling
	
.NOTES
          FileName: 2_CreateCentralPolicyStore.ps1
          Solution: Central Policy Store Deployment and GPO Template Synchronization
          Author: Patrick Scherling
          Contact: @Patrick Scherling
          Primary: @Patrick Scherling
          Created: 2025-01-03
          Modified: 2025-01-03

          Version - 0.0.1 - () - Finalized functional version 1.
		  Version - 0.0.2 - () - Reworked and little additions.
          

          TODO:
		  
		
.Example
	PS> .\2_CreateCentralPolicyStore.ps1
    Creates the Central Policy Store by copying the contents of 
    `C:\_psc\ADC_Setup\1_GroupPolicies\PolicyDefinitions` 
    to the SYSVOL location of the current domain.

    PS> powershell.exe -ExecutionPolicy Bypass -File "C:\Scripts\2_CreateCentralPolicyStore.ps1"
    Runs the script non-interactively during an automated AD post-deployment phase to initialize 
    the Central Policy Store and ensure consistent Group Policy management templates.
#>

function Create-CentralPolicyStore {

	# Log file path
    $logFile = "C:\_psc\ADC_Setup\Logfiles\CreateCentralPolicyStore.log"
	
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
	
	# Define the source and destination paths
	$SourcePath = "C:\_psc\ADC_Setup\1_GroupPolicies\PolicyDefinitions"
	Write-Log " Source Path is: $SourcePath"
	
	try{
		Write-Log " Try to get DomainName"
		$DomainName = (Get-ADDomain -ErrorAction SilentlyContinue).DNSRoot
	}
	catch{
		Write-Log " ERROR: DomainName can not be found!
	Reason: $_"
		Write-Host -ForegroundColor Red " ERROR: DomainName can not be found!
	Reason: $_"
	
		$DomainName = $null
	}
	
	$DestinationPath = "C:\AD\SYSVOL\sysvol\$DomainName\Policies"
	Write-Log " Destination Path is: $DestinationPath"

	# Check if the source folder exists
	Write-Log " Check if the source folder exists"
	if (Test-Path -Path $SourcePath) {
		# Check if the destination folder exists
		Write-Log " Check if the destination folder exists"
		if (-not (Test-Path -Path $DestinationPath)) {
			Write-Log " Can not access destination directory!"
			Write-Host -ForegroundColor Red " Can not access destination directory!"
			Read-Host " Press any key to abort"
			Exit
		}
		else{
			<#
			# Copy the contents of the PolicyDefinitions folder to the destination			
			try{
				Write-Log " Copying PolicyDefinitions folder and its contents..."
				Write-Host " Copying PolicyDefinitions folder and its contents..."
			
				Copy-Item -Path "$SourcePath\*" -Destination $DestinationPath -Recurse -Force -WhatIf
			}
			catch {
				Write-Host " Copy Process could not be executed!
	Reason: $_"
				Write-Host -ForegroundColor Red " Copy Process could not be executed!
	Reason: $_"
			}
			#>

			# Creating final target folder 'PolicyDefinitions'
			$DestinationPath = "C:\AD\SYSVOL\sysvol\$DomainName\Policies\PolicyDefinitions"
			if (-not (Test-Path -Path $DestinationPath)) {
			    Write-Log " Directory for PolicyDefinitions have to be created."
			    Write-Host -ForegroundColor Yellow " Directory for PolicyDefinitions have to be created."

				try{
					New-Item -Path $DestinationPath -ItemType Directory
				}
				catch{
					Write-Log " ERROR: Directory $DestinationPath could not be created!
	Reason: $_"
					Write-Host " ERROR: Directory $DestinationPath could not be created!
	Reason: $_"					
				}
		    }

			# Get all files and subdirectories from the source folder, including hidden/system files
			$items = Get-ChildItem -Path $SourcePath -Recurse -Force

			# Copy each item individually to ensure hidden/system files are copied
            foreach ($item in $items) {
                # Ensure the target folder structure is created
                    $targetItemPath = Join-Path -Path $DestinationPath -ChildPath $item.FullName.Substring($SourcePath.Length)
    
                    # If it's a directory, create it
                    if ($item.PSIsContainer) {
                        if (-not (Test-Path -Path $targetItemPath)) {
							try{
								Write-Log " Creating directory: $targetItemPath"
                                Write-Host " Creating directory: $targetItemPath"
                                New-Item -Path $targetItemPath -ItemType Directory
							}
							catch{
								Write-Log " ERROR: Directory $targetItemPath could not be created!
	Reason: $_"
								Write-Host " ERROR: Directory $targetItemPath could not be created!
	Reason: $_"
							}
                    }
                }
                else {
                    # If it's a file, copy it
					$ItemName = $item.FullName
					try{
						Write-Log " Copying file: $ItemName to $targetItemPath"
                        Write-Host " Copying file: $ItemName to $targetItemPath"
                        Copy-Item -Path $ItemName -Destination $targetItemPath -Force
					}
					catch{
						Write-Log " ERROR: File $ItemName could not be copied!
	Reason: $_"
						Write-Host " ERROR: File $ItemName could not be copied!
	Reason: $_"
					}
                }
            }

			Write-Log " Copy operation completed."
			Write-Host " Copy operation completed."
		}
	} else {
		Write-Log " ERROR: Source folder does not exist!"
		Write-Host " ERROR: Source folder does not exist!"
		
		Read-Host " Press any key to abort"
		Exit
	}

	Read-Host -Prompt " Press any key"
}


Create-CentralPolicyStore

