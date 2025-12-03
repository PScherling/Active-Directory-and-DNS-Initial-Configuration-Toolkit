<#
.SYNOPSIS
    Configures and initializes the DNS Server role for a new Active Directory environment.
.DESCRIPTION
    The **1_ad-dns-server-configuration_final.ps1** script automates the essential configuration steps 
    required to prepare and initialize a DNS Server in an Active Directory environment.  

    It guides the administrator through:
    - Disabling IPv6 on the primary network adapter (if required)
    - Setting up the DNS client suffix
    - Creating forward and reverse lookup zones
    - Automatically generating correct reverse zone names based on entered CIDR prefixes
    - Creating the DNS A record (static host entry) for the local DNS server

    The script is fully interactive and logs all operations to:
    ```
    C:\_psc\ADC_Setup\Logfiles\ad-dns-server-configuration.log
    ```

    Each major action (e.g., DNS zone creation, IPv6 disabling, static record setup) is recorded 
    and validated to prevent configuration errors.

    At the end of the process, the server reboots automatically (after confirmation) to apply all changes.
	
.LINK
    https://learn.microsoft.com/en-us/powershell/module/dnsserver/
    https://learn.microsoft.com/en-us/windows-server/networking/dns/
	https://github.com/PScherling
	
.NOTES
          FileName: 1_ad-dns-server-configuration_final.ps1
          Solution: Active Directory / DNS Server Initial Configuration
          Author: Patrick Scherling
          Contact: @Patrick Scherling
          Primary: @Patrick Scherling
          Created: 2025-04-10
          Modified: 2025-04-10

          Version - 0.0.1 - () - Finalized functional version 1.
		  Version - 0.0.2 - () - Reworked and little additions.
		  Version - 0.0.3 - () - Minor Bug fixes
          

          TODO:
		  
		
.Example
	PS> .\1_ad-dns-server-configuration_final.ps1
    Launches the DNS configuration wizard interactively, prompting for domain name and 
    reverse lookup zone network ID. Automatically configures DNS zones, static records, 
    and reboots the server when finished.

	PS> powershell.exe -ExecutionPolicy Bypass -File "C:\Scripts\1_ad-dns-server-configuration_final.ps1"
    Executes the script unattended as part of a deployment sequence or MDT/SCCM task, 
    performing the full DNS configuration process.
#>

####
#### Restart-System
####
function Restart-System {
    do{
        $Continue = Read-Host " Do you want to continue (Y/N)"
    } while($Continue -ne "Y" -and $Continue -ne "N")
	
    if($Continue -eq "Y") {
        for ($i = 10; $i -gt 0; $i=$i - 1 ) {
		    clear-host
		    Write-Host -ForegroundColor Yellow "
	System is going down for reboot in $i seconds..."
		    Start-Sleep -Seconds 1
	    }
        Restart-Computer #-WhatIf
    }
    elseif($Continue -eq "N"){
        Show-Menu
    }
}


###
### Main Script
###
function DNS-Configuration {
	$DomainName = ""
	$FLZoneFile = ".dns"
	$RLZoneFile = ".in-addr.arpa.dns"
	$NetworkID = ""
	$IPv4wSubnetArray = ""
	$IPv4Array = ""
	$response = ""
	$IsIPv6Disabled = ""
	$ArrayOfPrefixes = @(1..32)
	# Log file path
    $logFile = "C:\_psc\ADC_Setup\Logfiles\ad-dns-server-configuration.log"
	
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

	try {
		
		Write-Log " Input for Domain Name Forest"
		 
		#Input for Domain Name Forest
		while($response -ne "y" -and [string]::IsNullOrEmpty($DomainName)) {
			#User Input for DNS Forest
			Write-Host "-----------------------------------------------------------------------------------"
			Write-Host "              DNS Configuration Setup"
			Write-Host "              First Setup for DNS Server"
			Write-Host "-----------------------------------------------------------------------------------" `n
			Write-Host " First Step is to disable IPv6 on primary Network Adapter"
			
			Write-Log " First Step is to disable IPv6 on primary Network Adapter"
			Write-Log " Waiting for user input"
			
			Read-Host -Prompt " Press Enter key to continue"
			$IsIPv6Disabled = Get-NetAdapterBinding -InterfaceAlias "Ethernet*" -ComponentID ms_tcpip6 | Select-Object -Property Enabled
			if($IsIPv6Disabled -match "false") {
				Write-Log " IPv6 is already disabled on primary Networkadapter. Nothing to do."
				Write-Host " IPv6 is already disabled on primary Networkadapter. Nothing to do..." -ForegroundColor Green
			}
			else {
				Disable-NetAdapterBinding -InterfaceAlias "Ethernet*" -ComponentID ms_tcpip6 -ErrorAction Stop #-WhatIf
				Write-Log " IPv6 is now disabled on primary Networkadapter!"
				Write-Host " IPv6 is now disabled on primary Networkadapter!" -ForegroundColor Green
			}
			
			Write-Log "-----------------------------------------------------------------------------------"
			Write-Log " Now we are configuring our DNS Forest for our Domain"
			Write-Log " Waiting for user input"
			
			Write-Host "-----------------------------------------------------------------------------------" `n
			Write-Host " Now we are configuring our DNS Forest for our Domain"
			
			$DomainName = Read-Host -Prompt " Enter DNS Domain Name (like 'at' or 'domain.at')"
			$NetworkID = Read-Host -Prompt " Enter Reverse-Lookup Zone IPv4 (like 10.173.1.0/24 or 10.173.0.0/16 or 10.0.0.0/8)"
			
			Write-Log "-----------------------------------------------------------------------------------"
			Write-Log "    Your DNS Suffix will be:                            $DomainName"
			Write-Log "    Your Forward-Lookup Zone will be:                   $DomainName"
			Write-Log "    Your Forward-Lookup Zone File will be:              $DomainName$FLZoneFile"
			Write-Log "    Your Network ID for Reverse-Lookupzone will be:     $NetworkID"
			
			Write-Host "-----------------------------------------------------------------------------------" `n
			Write-Host "    Your DNS Suffix will be:                            $DomainName"
			Write-Host "    Your Forward-Lookup Zone will be:                   $DomainName"
			Write-Host "    Your Forward-Lookup Zone File will be:              $DomainName$FLZoneFile"
			Write-Host "    Your Network ID for Reverse-Lookupzone will be:     $NetworkID"

			$IPv4wSubnetArray = $NetworkID.Split(".")
			$IPv4Array = $IPv4wSubnetArray.Split("/")

			#Output for testing!
			#Write-Host $IPv4wSubnetArray
			#Write-Host $IPv4Array
			#Write-Host "Octets: " $IPv4Array[0] " - " $IPv4Array[1] " - " $IPv4Array[2] " - " $IPv4Array[3]

			#Check if Prefix is /1 to /7
			if($IPv4Array[4] -in $ArrayOfPrefixes[0..6]) {
				#$ReverseZone = $IPv4Array[0]
				Write-Log " Reverse-Lookup Zone can not be created with this Network ID! Aborting..."
				Write-Host " Reverse-Lookup Zone can not be created with this Network ID! Aborting..." -ForegroundColor Red
				Exit
			}
			#Check if Prefix is /8
			elseif($IPv4Array[4] -in $ArrayOfPrefixes[7]) {
				$ReverseZone = $IPv4Array[0]
				Write-Log " Reverse-Lookup Zone will be created with Prefix '/8'"
			}
			#Check if Prefix is /9 to /15
			elseif($IPv4Array[4] -in $ArrayOfPrefixes[8..14]) {
				$ReverseZone = $IPv4Array[0]
				$NetworkID = $IPv4Array[0]+"."+$IPv4Array[1]+"."+$IPv4Array[2]+"."+$IPv4Array[3]+"/"+$ArrayOfPrefixes[7]
				Write-Log " Attention! You have entered a Prefix between '/9' and '/15'. All these subnets will be created as '/8' Prefix."
				Write-Host " Attention! You have entered a Prefix between '/9' and '/15'. All these subnets will be created as '/8' Prefix." -ForegroundColor Yellow
			}
			#Check if Prefix is /16
			elseif($IPv4Array[4] -in $ArrayOfPrefixes[15]) {
				$ReverseZone = $IPv4Array[1]+"."+$IPv4Array[0]
				Write-Log " Reverse-Lookup Zone will be created with Prefix '/16'"
			}
			#Check if Prefix is /17 to /23
			elseif($IPv4Array[4] -in $ArrayOfPrefixes[16..22]) {
				$ReverseZone = $IPv4Array[1]+"."+$IPv4Array[0]
				$NetworkID = $IPv4Array[0]+"."+$IPv4Array[1]+"."+$IPv4Array[2]+"."+$IPv4Array[3]+"/"+$ArrayOfPrefixes[15]
				Write-Log " Attention! You have entered a Prefix between '/17' and '/23'. All these subnets will be created as '/16' Prefix."
				Write-Host " Attention! You have entered a Prefix between '/17' and '/23'. All these subnets will be created as '/16' Prefix." -ForegroundColor Yellow
			}
			#Check if Prefix is /24
			elseif($IPv4Array[4] -in $ArrayOfPrefixes[23]) {
				$ReverseZone = $IPv4Array[2]+"."+$IPv4Array[1]+"."+$IPv4Array[0]
				Write-Log " Reverse-Lookup Zone will be created with Prefix '/24'"
			}
			#Check if Prefix is /25 to /32
			elseif($IPv4Array[4] -in $ArrayOfPrefixes[24..31]) {
				$ReverseZone = $IPv4Array[2]+"."+$IPv4Array[1]+"."+$IPv4Array[0]
				$NetworkID = $IPv4Array[0]+"."+$IPv4Array[1]+"."+$IPv4Array[2]+".0/"+$ArrayOfPrefixes[23]
				Write-Log " Attention! A Reverse Lookup-Zone can only handle up to 3 Octets. This means, every subnet between '/25' and '/32' is handled as '/24' Prefix Length and the Reverse Lookup-Zone will be created as '/24' Prefix."
				Write-Host " Attention! A Reverse Lookup-Zone can only handle up to 3 Octets. This means, every subnet between '/25' and '/32' is handled as '/24' Prefix Length and the Reverse Lookup-Zone will be created as '/24' Prefix." -ForegroundColor Yellow
			}
			else {
				Write-Log " Reverse-Lookup Zone can not be created with this Network ID! Aborting..."
				Write-Host " Reverse-Lookup Zone can not be created with this Network ID! Aborting..." -ForegroundColor Red
				exit
			}

			Write-Log "    Your Reverse-Lookup Zone File will be:              $ReverseZone$RLZoneFile"
			Write-Log "-----------------------------------------------------------------------------------"
			
			Write-Host "    Your Reverse-Lookup Zone File will be:              $ReverseZone$RLZoneFile"
			Write-Host "-----------------------------------------------------------------------------------" `n
			
			Write-Log " Waiting for user input"
			
			$response = Read-Host -Prompt " Press (y) to approve and continue or (a) to abort"
			if($response -eq "a") {
				Write-Log " User input was (a) to abort."
				$DomainName = ""
				exit
			}

		}

		if ($response -eq "y") {
			Write-Log " User input was (y) to continue."
			Write-Log "-----------------------------------------------------------------------------------"
			Write-Log " Creating DNS Suffix"
			
			Write-Host "-----------------------------------------------------------------------------------" `n
			Write-Host " Creating DNS Suffix"
			
			Write-Log " Waiting for user input"
			
			Read-Host -Prompt " Press Enter key to continue"

			Set-DnsClientGlobalSetting -SuffixSearchList $DomainName -ErrorAction Stop #-WhatIf

			Write-Log "-----------------------------------------------------------------------------------"
			Write-Log " Creating Forward-Lookup Zone " $DomainName
			
			Write-Host "-----------------------------------------------------------------------------------" `n
			Write-Host " Creating Forward-Lookup Zone " $DomainName
			
			Write-Log " Waiting for user input"
			
			Read-Host -Prompt " Press Enter key to continue"

			Add-DnsServerPrimaryZone -name $DomainName -DynamicUpdate NonsecureAndSecure -ZoneFile $DomainName$FLZoneFile -PassThru -ErrorAction Stop #-WhatIf

			Write-Log "-----------------------------------------------------------------------------------"
			Write-Log " Creating Reverse-Lookup Zone " $NetworkID
			
			Write-Host "-----------------------------------------------------------------------------------" `n
			Write-Host " Creating Reverse-Lookup Zone " $NetworkID
			
			Write-Log " Waiting for user input"
			
			Read-Host -Prompt " Press Enter key to continue"

			Add-DnsServerPrimaryZone -NetworkID $NetworkID -ZoneFile $ReverseZone$RLZoneFile -DynamicUpdate NonsecureAndSecure -ErrorAction Stop #-WhatIf

			Write-Log "-----------------------------------------------------------------------------------"
			Write-Log " Creating Static Host Entry for DNS Server"

			Write-Host "-----------------------------------------------------------------------------------" `n
			Write-Host " Creating Static Host Entry for DNS Server"
			
			Write-Log " Waiting for user input"
			
			Read-Host -Prompt " Press Enter key to continue"

			$LocalIPAdress = Get-NetIPAddress -InterfaceAlias "Ethernet*" -AddressFamily IPv4
			$IP = $LocalIPAdress.IPAddress
			Write-Log "    Local IP is: $IP"
			Write-Host "    Local IP is: $IP"

			Add-DnsServerResourceRecordA -name $env:computername -zonename $DomainName -IPv4Address $LocalIPAdress.IPAddress -AllowUpdateAny -CreatePtr -ErrorAction Stop #-WhatIf
			
			Write-Log "-----------------------------------------------------------------------------------"
			Write-Log " DNS Server successfully configured"
			Write-Log "-----------------------------------------------------------------------------------" `n
			
			Write-Host "-----------------------------------------------------------------------------------"
			Write-Host " DNS Server successfully configured" -ForegroundColor Green
			Write-Host "-----------------------------------------------------------------------------------" `n
			
			Write-Log " Attention! Server is going down for reboot."
			Write-Warning " Attention! Server is going down for reboot."
			
			Restart-System
		}
	}
	catch {
        Write-Log "Error: An unexpected error occurred: $_"
    } 
	finally {
        # End logging
        Write-Log "End of configuration process."
    }
}



DNS-Configuration

