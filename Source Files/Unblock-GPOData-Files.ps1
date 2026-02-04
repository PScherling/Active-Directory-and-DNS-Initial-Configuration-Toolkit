<#
.SYNOPSIS
  Unblocks files (removes Zone.Identifier / “Mark of the Web”) in a target directory.
  
.DESCRIPTION
  Recursively scans a directory and removes the Zone.Identifier alternate data stream
  from each file using Unblock-File. This is commonly required when GPO backup/data
  files were copied from another system or downloaded and are considered untrusted by Windows.

  Use -WhatIf first to verify what would be changed.

.PARAMETER Path
  Root directory containing the files to unblock.
  Default: D:\GPO-Daten

.PARAMETER LogFile
  Path to the log file. The parent folder is created if missing.
  Default: C:\_psc\Unblocking_Data-Files.log

.PARAMETER PauseOnExit
  If set, prompts before exiting (useful when running interactively).

    
.LINK
	https://github.com/PScherling
    
.NOTES
          FileName: custom_Unblock-GPO-Data-Files.ps1
          Solution: Set GPO-Data Files on a share as trsutworthy
          Author: Patrick Scherling
          Contact: @Patrick Scherling
          Primary: @Patrick Scherling
          Created: 2025-07-10
          Modified: 2026-02-04

          Version - 0.0.1 - () - Finalized functional version 1.
		      Version - 0.0.2 - () - Fixed: Bug by User Input that gets ignored.
          Version - 0.0.3 - (2026-02-04) - Adding Parameter

          TODO:

Requirements / Notes for admins:
- Unblock-File removes the Zone.Identifier ADS. This is supported on NTFS.
  On non-NTFS storage or some shares, the ADS may not exist or may not be supported.
- Run with sufficient permissions to read/write the target directory contents.
		  
		
.Example
  .\custom_Unblock-Data-Files.ps1
  Uses the default path (D:\GPO-Daten) and logs to C:\_it\Unblocking_Data-Files.log.

  .\custom_Unblock-Data-Files.ps1 -Path "D:\Data\GPO" -WhatIf
  Shows what would be unblocked without making changes.

  .\custom_Unblock-Data-Files.ps1 -Path "\\fileserver\share\GPO-Daten" -LogFile "D:\Logs\unblock.log" -Verbose
  Runs against a share path (if supported by the underlying filesystem) with verbose output.

#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false)]
    [string] $Path = "D:\GPO-Daten",

    [Parameter(Mandatory = $false)]
    [string] $LogFile = "C:\_psc\Unblocking_Data-Files.log",

    [Parameter(Mandatory = $false)]
    [switch] $PauseOnExit
)

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


function Start-UnblockDataFiles {
    param(
      [Parameter(Mandatory)] [string] $TargetPath
    )
    
    Write-Log "Unblocking files in '$TargetPath' ..."

    # Enumerate files (silently skip folders we can't access)
    $files = Get-ChildItem -Path $TargetPath -Recurse -File -Force -ErrorAction SilentlyContinue

    foreach ($f in $files) {
        Write-Log  "Unblocking file: $($f.FullName)"
        Write-Host "Unblocking file: $($f.FullName)"

        try {
            if ($PSCmdlet.ShouldProcess($f.FullName, "Unblock-File")) {
                Unblock-File -Path $f.FullName -ErrorAction Stop
            }
            Write-Log  "File unblocked."
            Write-Host -ForegroundColor Green "File unblocked."
        }
        catch {
            Write-Warning "Failed to unblock: $($f.FullName) ($($_.Exception.Message))"
            Write-Log     "FAILED: $($f.FullName) ($($_.Exception.Message))"
        }
    }

    Write-Log "End of configuration process."
}




Clear-Host
# Ensure log folder exists
$logDir = Split-Path -Parent $LogFile
if ($logDir -and -not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}


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
# If user explicitly passed -Path, we trust it (still validate). If they didn't pass anything,
# you still get a default; optionally allow interactive override:
$destPath = $Path

if (-not (Test-Path -Path $destPath -PathType Container)) {
    Write-Host -ForegroundColor Yellow "WARNING: The directory '$destPath' does not exist."
    Write-Log  "WARNING: The directory '$destPath' does not exist."
    if ($PauseOnExit) { Read-Host -Prompt "Press Enter to exit" }
    return
}

# Optional confirmation (interactive)
$continue = "y"
if ($Host.Name -match "ConsoleHost") {
    $continue = Read-Host "Directory is '$destPath'. Continue? (y/n)"
}

if ($continue -match '^(?i)y$') {
    Start-UnblockDataFiles -TargetPath $destPath
    Write-Log "Unblock executed for '$destPath'."
}
else {
    Write-Log "User chose to abort."
}

if ($PauseOnExit) {
    Read-Host -Prompt "Press Enter to exit"
}

