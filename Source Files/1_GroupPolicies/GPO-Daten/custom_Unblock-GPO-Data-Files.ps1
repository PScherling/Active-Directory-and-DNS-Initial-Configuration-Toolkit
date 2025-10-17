<#
.SYNOPSIS
    Automatically unblocks all files within a specified directory, removing the “downloaded from the Internet” security flag applied by Windows.
	
.DESCRIPTION
	The **custom_Unblock-GPO-Data-Files.ps1** script is designed to **recursively unblock files** within a given folder and its subdirectories.  
    When files are downloaded or transferred from another computer, Windows marks them as coming from an untrusted source, 
    which can prevent them from executing or being read correctly by certain tools (e.g., Group Policy Management Console, MDT, or scripts).

	This script:
    - Scans a specified directory (default: `D:\GPO-Daten`)
    - Recursively unblocks all files within that directory
    - Logs every action and file processed
    - Provides visual progress and clear console feedback
    - Offers user input for custom paths and confirmation before execution

    **Typical Use Case:**
    When importing GPO backup data or configuration templates from another environment, Windows often blocks the `.pol`, `.xml`, `.inf`, or `.ps1` files.  
    Running this script ensures all such files are accessible and executable by removing their security “Zone.Identifier” metadata.

    **Key Features:**
    - Interactive path selection (default or custom directory)
    - Validates directory existence before processing
    - Recursively processes all subfolders and files
    - Logs every operation with timestamps
    - Displays color-coded console messages for user clarity
    - Safe and idempotent (can be run multiple times without harm)

    **Default Path:**
    ```
    D:\GPO-Daten
    ```

    **Log File Location:**
    ```
    C:\_it\Unblocking_GPO-Data-Files.log
    ```

    **Command Used:**
    ```
    Unblock-File -Path <FileName>
    ```

    **Common Use Scenarios:**
    - Unblocking Group Policy backup files before import.
    - Cleaning up deployment packages transferred from another environment.
    - Removing security flags from scripts, templates, or utilities after ZIP extraction.
    - Preparing files for automated deployment in CI/CD pipelines or MDT task sequences.

	Requirements:
            - PowerShell 5.1 or later
            - Administrative privileges (recommended)
            - Read/write access to the target directory
            - Execution policy allowing script execution
    
.LINK
	https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/unblock-file
    https://learn.microsoft.com/en-us/windows/security/threat-protection/windows-defender-smartscreen/how-smartscreen-works
    https://ss64.com/ps/unblock-file.html
	https://github.com/PScherling
    
.NOTES
          FileName: custom_Unblock-GPO-Data-Files.ps1
          Solution: File Security Automation
          Author: Patrick Scherling
          Contact: @Patrick Scherling
          Primary: @Patrick Scherling
          Created: 2025-07-10
          Modified: 2025-10-17

          Version - 0.0.1 - () - Finalized functional version 1.
		  Version - 0.0.2 - () - Fixed: Bug by User Input that gets ignored.

          TODO:
		  	- Add progress indicator (e.g., percentage or status bar).
            - Include file count summary in the log.
            - Optionally support network paths and UNC validation.
            - Add parameter support for silent/non-interactive mode.
            - Implement exclusion filters (e.g., skip large files or certain extensions).
		
.Example
	PS C:\> .\custom_Unblock-GPO-Data-Files.ps1
    Launches the script, asks for a directory path, and unblocks all files 
    in that directory and its subfolders. Default path is `D:\GPO-Daten`.

    PS C:\> powershell.exe -ExecutionPolicy Bypass -File "C:\_it\custom_Unblock-GPO-Data-Files.ps1"
    Runs the script in bypass mode, ideal for automated deployment or MDT/SCCM task sequences.
#>

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


function Unblock_GPO-Data-Files($Path) {
    Write-Log "Unblocking Files..."
	
    Get-ChildItem -Path $Path -Recurse -File -Force | ForEach-Object {
        Write-Log "Unblocking File: $($_.FullName)"
        Write-Host "Unblocking File: $($_.FullName)"
        try{            
            Unblock-File -Path $_.FullName #-WhatIf
        }
        catch{
            Write-Warning "Failed to unblock: $($_.FullName)"
            Write-Log "Failed to unblock: $($_.FullName)"
        }
        finally {
            Write-Log "File Unblocked."
            Write-Host -ForegroundColor Green "File Unblocked."
        }
    }
    
    # End logging
    Write-Log "End of configuration process."
	
	Read-Host -Prompt " Press any key to leave"
}




Clear-Host
# Log file path
$logFile = "C:\_it\Unblocking_GPO-Data-Files.log"

# Start logging
Write-Log " Starting configuration process..."


Write-Host -ForegroundColor Cyan "
    +----+ +----+     
    |####| |####|     
    |####| |####|       WW   WW II NN   NN DDDDD   OOOOO  WW   WW  SSSS
    +----+ +----+       WW   WW II NNN  NN DD  DD OO   OO WW   WW SS
    +----+ +----+       WW W WW II NN N NN DD  DD OO   OO WW W WW  SSS
    |####| |####|       WWWWWWW II NN  NNN DD  DD OO   OO WWWWWWW    SS
    |####| |####|       WW   WW II NN   NN DDDDD   OOOO0  WW   WW SSSS
    +----+ +----+       
"
Write-Host "-----------------------------------------------------------------------------------"

do {
    Write-Host "`n Please enter the path to unblock the files or press Enter to use the default location."
    $rawInput = Read-Host " (Default: 'D:\GPO-Daten')"
    Write-Log " User Input for directory: $rawInput"

    # Resolve default vs custom
    if ([string]::IsNullOrWhiteSpace($rawInput)) {
        $destPath = "D:\GPO-Daten"
    } else {
        $destPath = $rawInput
    }

    Write-Host -ForegroundColor Yellow " Directory is '$destPath'"
    Write-Log " Directory is '$destPath'"

    # Validate directory exists
    if (-not (Test-Path -Path $destPath -PathType Container)) {
        Write-Host -ForegroundColor Yellow " WARNING: The directory '$destPath' does not exist."
        Write-Log  " WARNING: The directory '$destPath' does not exist."
        $destPath = $null
        continue
    }

    # Confirm
    $continue = Read-Host " Do you want to continue? (y/n)"

} while ([string]::IsNullOrWhiteSpace($destPath) -or ($continue -notmatch '^(?i)y$|^(?i)n$'))

if ($continue -match '^(?i)y$') {
    Unblock_GPO-Data-Files -Path $destPath
    Write-Log " Unblock_GPO-Data-Files executed for '$destPath'."
} else {
    Write-Log " User chose to abort."
}


