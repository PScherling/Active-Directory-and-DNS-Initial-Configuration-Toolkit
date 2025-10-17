<#
.SYNOPSIS
    Imports Active Directory user accounts from a structured CSV file and automatically creates corresponding user objects.
	
.DESCRIPTION
	The **AD-bulk-user-import.ps1** script automates the creation of Active Directory user accounts 
    based on data from a UTF-8 encoded CSV file. It provides an interactive interface to select 
    the import file, validate user information, and create accounts with proper attributes and permissions.

    The script performs the following tasks:
    - Detects the current Active Directory domain
    - Prompts the administrator to select a CSV import file from:
      ```
      C:\_it\
      ```
    - Reads and validates user data from the CSV file  
    - Automatically creates new AD user accounts with all specified properties
    - Checks for duplicate users before creation
    - Supports conversion of German umlauts and special characters
    - Optionally creates user home and profile directories and sets appropriate ACLs
    - Logs all actions, warnings, and errors for traceability

    Each imported user can contain the following properties (depending on CSV data):
    ```
    Enabled;Username;Firstname;Lastname;DisplayName;Path;Password;ProfilePath;EmailAddress;
    HomeDirectory;HomeDrive;LegacyDN;City;Country;Description;State;Title;PostalCode;Department;Company
    ```

    Example file location:
    ```
    C:\_it\ils-karlsruhe_Systemverwaltung_ad-user-export.csv
    ```

    The script writes a full log to:
    ```
    C:\_it\ADC_Setup\Logfiles\Import-ADUsers.log
    ```

    This tool is designed to work seamlessly with the export script:
    **custom_AD-bulk-user-export.ps1**
    allowing domain administrators to clone or migrate user structures 
    between environments with minimal manual configuration.

    $SearchBase = 'OU=Systemverwaltung,OU=Systembenutzer,OU=ILS-Template,DC=domain,DC=at' #Exportiert User in der angegebenen OU der Domäne; Bei Bedarf anpassen!

    Requirements:
	    - Windows Server 2016 or newer  
	    - PowerShell 5.1 or later  
	    - Active Directory Domain Services (ADDS) and PowerShell AD module installed  
	    - Domain administrative privileges  
	    - Execution policy allowing script execution (`Set-ExecutionPolicy Bypass`)  
	    - Valid CSV file with proper attribute structure
    
.LINK
	https://learn.microsoft.com/en-us/powershell/module/activedirectory/new-aduser  
    https://learn.microsoft.com/en-us/powershell/module/activedirectory/get-aduser  
    https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/import-csv  
	https://github.com/PScherling
    
.NOTES
          FileName: AD-bulk-user-import.ps1
          Solution: Active Directory Bulk User Import Automation  
          Author: Patrick Scherling
          Contact: @Patrick Scherling
          Primary: @Patrick Scherling
          Created: 2020-11-23
          Modified: 2025-09-16

          Version - 0.0.1 - () - Finalized functional version 1.
          Version - 0.0.2 - () - Umlautabfrage hinzugefügt.
		  Version - 0.0.3 - () - Optional Output in Logfile hinzugefügt.
          Version - 0.0.5 - () - Domain Name erkennung
		  Version - 0.0.5 - () - Reworking the whole script for better usability.
		  Version - 0.0.6 - () - Adding File selection for import.
		  Version - 0.0.7 - () - Adaption for efsconfig.
          Version - 0.0.8 - () - Adding more Properties for Users (like ILS MUC needed) and reworking the import process for dynamically property linking to user
          Version - 0.0.9 - () - Adding user property "Enabled" to import

          TODO:
		  
		
.Example
	PS> .\AD-bulk-user-import.ps1
    Prompts for domain verification and CSV file selection, 
    then imports users defined in the CSV into the appropriate OUs, 
    creating accounts, home directories, and profile directories as needed.

    PS> powershell.exe -ExecutionPolicy Bypass -File "C:\Scripts\AD-bulk-user-import.ps1"
    Executes the script non-interactively as part of an automated domain setup 
    or migration process, importing all users defined in the selected CSV file.
#>

#Import active directory module for running AD cmdlets
#Import-Module activedirectory



function EF-Import-ADUsers {
    Clear-Host
	# Log file path
    $logFile = "C:\_it\ADC_Setup\Logfiles\Import-ADUsers.log"
	
	# CSV Export Path
	$ImportPath = "C:\_it\"
  

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
	
	function SelectFile {	
	
		$Options = @()
		$Input = ""
        $FileSelected = "false"
        $GetFiles = ""
        $SumOfFile = ""
        $File = ""
        $FileList = @()

		#$global:GetExclusionFiles = Get-ChildItem -File "C:\Users\pscherling\Desktop\SOne API Calls\3_Create Exclusions" -Name -Include *.csv
		try{
            $GetFiles = Get-ChildItem -File "$ImportPath" -Name -Include *.csv
        }
        catch{
            Write-Log " ERROR: CSV File could not be found in directory '$ImportPath'! There is no file available for import!
    Reason: $_"
			Write-Host -ForegroundColor Red "ERROR: CSV File could not be found in directory '$ImportPath'! There is no file available for import!
    Reason: $_"
            Read-Host -Prompt " Press any key to exit"
			exit
        }

        
		$SumOfFile = $GetFiles.Count

		#Write-Host $global:SumOfExclusionFile
		#Write-Host $global:GetExclusionFiles

        if($SumOfFile -eq 0){
            Write-Log " ERROR: No CSV files found! There is no file available for import!"
			Write-Host -ForegroundColor Red "ERROR: No CSV files found! There is no file available for importt!"
            Read-Host -Prompt " Press any key to exit"
			exit
        }
		
        else{
		    while($FileSelected -eq "false")
		    {
			    foreach($File in $GetFiles) {
				    #Write-Host $ReqFile
				    $FileList += $File
			    }

			    Write-Host " Select a File:"
			    for(($x = 0); $x -lt $SumOfFile; $x++) {
				    Write-Host " "$x"." $FileList[$x]
				    $Options += $x
			    }
			    Write-Host " e. Exit" `n
			
			    $Input = Read-Host " Please select an option (0/1/../e)"
			
			    if($Options -contains $Input){
				    $FileSelected = "true"
				    $GetFile = $FileList[$Input]
				    $FileName = $GetFile#+".csv"
				    Write-Host " Selected File:" $FileName `n -ForegroundColor Yellow
					$global:File = $FileName
				
			    }
			    elseif($Input -eq "e")
			    {
				    Write-Host " Exiting..." -ForegroundColor Yellow
				    exit
			    }
			    elseif($Input -ne "e" -and $Options -notcontains $Input) {
				    Write-Host " Wrong Input" `n -ForegroundColor Red
			    }
		    }
        }
		
		
	}

    function Rewrite-SpecialCharacters($inputstring){
 
	    for ($i = 0; $i -lt $Sonderzeichen.Length; $i++){
		    $inputstring = $inputstring.replace($Sonderzeichen[$i],$Umschrieb[$i])
	    } 
    
	    return $inputstring
    }
	<#
    $Sonderzeichen = @(
		    'Á',
		    'À',
		    'Â',
		    'Ä',
		    'É',
		    'È',
		    'Ê',
		    'Ë',
		    'Í',
		    'Ì',
		    'Î',
		    'Ï',
		    'Ó',
		    'Ò',
		    'Ô',
		    'Ö',
		    'Ú',
		    'Ù',
		    'Û',
		    'Ü',
		    'á',
		    'à',
		    'â',
		    'ä',
		    'é',
		    'è',
		    'ê',
		    'ë',
		    'í',
		    'ì',
		    'î',
		    'ï',
		    'ó',
		    'ò',
		    'ô',
		    'ö',
		    'ú',
		    'ù',
		    'û',
		    'ü',
		    'ß'
	    )
    $Umschrieb = @(
		    'A',
		    'A',
		    'A',
		    'Ae',
		    'E',
		    'E',
		    'E',
		    'E',
		    'I',
		    'I',
		    'I',
		    'I',
		    'O',
		    'O',
		    'O',
		    'Oe',
		    'U',
		    'U',
		    'U',
		    'Ue',
		    'a',
		    'a',
		    'a',
		    'ae',
		    'e',
		    'e',
		    'e',
		    'e',
		    'i',
		    'i',
		    'i',
		    'i',
		    'o',
		    'o',
		    'o',
		    'oe',
		    'u',
		    'u',
		    'u',
		    'ue',
		    'ss'
	    )
#>

	$Sonderzeichen = @(
		    'Ä',
		    'Ö',
		    'Ü',
		    'ä',
		    'ö',
		    'ü',
		    'ß'
	    )
    $Umschrieb = @(
		    'Ae',
		    'Oe',
		    'Ue',
		    'ae',
		    'oe',
		    'ue',
		    'ss'
	    )

    
    $response = ""
    $Domain = ""
    $DomainName = ""
    $DomainDistinguishedName = ""
    $usercreated = "false"
    
    try{
        #Input for Domain Name
        while([string]::IsNullOrEmpty($DomainName)) {
			<#Write-Host -ForegroundColor Red "
	   .-://///:-.
	 -://:-...-//   .       
	-///-         ///       EEEEEEE UU   UU RRRRRR   OOOOO  FFFFFFF UU   UU NN   NN KK  KK
	///:         :///       EE      UU   UU RR   RR OO   OO FF      UU   UU NNN  NN KK KK
	///:         :///       EEEEE   UU   UU RRRRRR  OO   OO FFFF    UU   UU NN N NN KKKK
	-///-       -///-       EE      UU   UU RR  RR  OO   OO FF      UU   UU NN  NNN KK KK
	 -://:-...-://:-        EEEEEEE  UUUUU  RR   RR  OOOO0  FF       UUUUU  NN   NN KK  KK
	   *-://///:-*
"#>

            Write-Host "-----------------------------------------------------------------------------------"
			Write-Host "              Active Directory Management"
			Write-Host "              AD User Import"
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
        }
		
		# File Selection Function
		SelectFile

        #Store the data from ADUsers.csv in the $ADUsers variable
        try{
            $ADUsers = Import-csv -path "$($ImportPath)$($global:File)" -Delimiter ";" -encoding utf8
        }
        catch{
            Write-Log " ERROR: File for import could not be set.
    Reason: $_"
			Write-Host -ForegroundColor Red "ERROR: File for import could not be set.
    Reason: $_"
            Read-Host -Prompt " Press any key to exit"
			exit
        }


        #Loop through each row containing user details in the CSV file
        Write-Log "Loop through each row containing user details in the CSV file."
        foreach ($User in $ADUsers)
        {
	        #Read user data from each field in each row and assign the data to a variable as below
            Write-Log "Read user data from each field in each row and assign the data to a variable."
		
            $Enabled        = $User.Enabled # If user account is enabled or disabled (true/false)
	        $Username       = $User.Username #SamAccountName aka AccountName aka LogonName
	        $Firstname 	    = $User.Firstname #GivenName
	        $Lastname 	    = $User.Lastname #Surname
            $Name           = $User.Displayname #Name in AD Users & Computers
            $DisplayName    = $User.Displayname #Displayname at Logon
	        $Path 		    = $User.Path #This field refers to the OU the user account is to be created in
            $Password       = $User.Password
	        $ProfilePath    = $User.ProfilePath
            $EmailAddress   = $User.EmailAddress
	        $HomeDirectory  = $User.HomeDirectory
	        $HomeDrive      = $User.HomeDrive
            $LegacyDN 	    = $User.legacyExchangeDN
            $City		    = $User.City
            $Country	    = $User.Country
            $Description    = $User.Description
            $State		    = $User.State
            $ProfilePath    = $User.ProfilePath
            $Title		    = $User.Title
            $PostalCode	    = $User.PostalCode
            $Department	    = $User.Department
            $Company	    = $User.Company
    
            
	        #Check to see if the user already exists in AD
            Write-Log "Check to see if the user already exists in AD"
	        if (Get-ADUser -F {SamAccountName -eq $Username})
	        {
		        #If user does exist, give a warning
		        Write-Host -ForegroundColor Yellow " WARNING: A user account with username $Username already exist in this Active Directory." `n
                Write-Log " WARNING: A user account with username $Username already exist in this Active Directory."
	        }
	        else
	        {
		        #User does not exist then proceed to create the new user account
		        Write-Log "Proceeding with user import."

                # Sanitize special characters
                foreach ($var in @('Username', 'Firstname', 'Lastname', 'Name', 'City', 'Country', 'State', 'Title', 'Department', 'Company', 'HomeDirectory')) {
                    if ((Get-Variable -Name $var).Value -match '[ÄäÖöÜüß]') {
                        Write-Log "WARNING: $var contains special characters."
                        Set-Variable -Name $var -Value (Rewrite-SpecialCharacters (Get-Variable -Name $var).Value)
                    }
                }

                # Replace missing or empty fields with $null
                foreach ($field in @(
                    'EmailAddress', 'HomeDirectory', 'HomeDrive', 'LegacyDN',
                    'City', 'Country', 'Description', 'State', 'ProfilePath',
                    'Title', 'PostalCode', 'Department', 'Company'
                )) {
                    if ([string]::IsNullOrEmpty((Get-Variable -Name $field).Value)) {
                        Write-Log "WARNING: $field is empty. Will be excluded from AD creation."
                        Set-Variable -Name $field -Value $null
                    }
                }

                # Optional: Append Username to HomeDirectory if set
                <#
                if ($HomeDirectory) {
                    $HomeDirectory = "$HomeDirectory\$Username"
                }#>
		        
                #Prüfung für Testzwecke
                Write-Host `n "User will be created with follwing Properties" -ForegroundColor Green
                Write-Host "-----------------------------------------------"
                Write-Host " AccountName: $Username
    Enabled:           $Enabled
    Principal Name:    $Username@$DomainName
    Name:              $Name
    GivenName:         $Firstname
    Surname:           $Lastname
    Displayname:       $Displayname
    OU-Path:           $Path
    Email Address:     $EmailAddress
    Home Directory:    $HomeDirectory
    Home Drive:        $HomeDrive
    LegacyDN:          $LegacyDN
    City:              $City
    Country:           $Country
    Description:       $Description
    State:             $State
    Profile Path:      $ProfilePath
    Title:             $Title
    Postal Code:       $PostalCode
    Department:        $Department
    Company:           $Company"
                Write-Host "-----------------------------------------------"

                if($Enabled -eq "True"){
                    $Enabled = $true
                } else{
                    $Enabled = $false
                }
                
                # Build AD user creation parameters dynamically
                $ADUserParams = @{
                    Enabled                = $Enabled
                    #Enabled                = $true
                    SamAccountName         = $Username
                    UserPrincipalName      = "$Username@$DomainName"
                    Name                   = $Name
                    GivenName              = $Firstname
                    Surname                = $Lastname
                    DisplayName            = $DisplayName
                    Path                   = "$Path"
                    AccountPassword        = (ConvertTo-SecureString $Password -AsPlainText -Force)
                    ChangePasswordAtLogon = $true
                }
                
                # Add optional fields only if they're not $null
                if ($EmailAddress)    { $ADUserParams["EmailAddress"] = $EmailAddress }
                if ($HomeDirectory)   { $ADUserParams["HomeDirectory"] = $HomeDirectory }
                if ($HomeDrive)       { $ADUserParams["HomeDrive"] = $HomeDrive }
                if ($LegacyDN)        { $ADUserParams["LegacyExchangeDN"] = $LegacyDN }
                if ($City)            { $ADUserParams["City"] = $City }
                if ($Country)         { $ADUserParams["Country"] = $Country }
                if ($Description)     { $ADUserParams["Description"] = $Description }
                if ($State)           { $ADUserParams["State"] = $State }
                if ($ProfilePath)     { $ADUserParams["ProfilePath"] = $ProfilePath }
                if ($Title)           { $ADUserParams["Title"] = $Title }
                if ($PostalCode)      { $ADUserParams["PostalCode"] = $PostalCode }
                if ($Department)      { $ADUserParams["Department"] = $Department }
                if ($Company)         { $ADUserParams["Company"] = $Company }

                Write-Log "User will be created with follwing Properties"
                Write-Log "-----------------------------------------------"
                Write-Log "AccountName:          $Username"
                Write-Log " Enabled:             $Enabled"
                Write-Log " Principal Name:      $Username@$DomainName"
                Write-Log " Name:                $Name"
                Write-Log " GivenName:           $Firstname"
                Write-Log " Surname:             $Lastname"
                Write-Log " Displayname:         $Displayname"
                Write-Log " OU-Path:             $Path"
                Write-Log " Email Address:       $EmailAddress"
                Write-Log " Home Directory:      $HomeDirectory"
                Write-Log " Home Drive:          $HomeDrive"
                Write-Log " LegacyDN:            $LegacyDN"
                Write-Log " City:                $City"
                Write-Log " Country:             $Country"
                Write-Log " Description:         $Description"
                Write-Log " State:               $State"
                Write-Log " Profile Path:        $ProfilePath"
                Write-Log " Title:               $Title"
                Write-Log " Postal Code:         $PostalCode"
                Write-Log " Department:          $Department"
                Write-Log " Company:             $Company"
                Write-Log "-----------------------------------------------"


                Read-Host -Prompt "Press any key to check if user can be imported..."
		

                # Try to create user
                try {
                    New-ADUser @ADUserParams -WhatIf  # Remove -WhatIf to execute
                    Write-Log "SUCCESS: User $Username can be imported."
                    Write-Host -ForegroundColor Green "`n User can be imported!"
                    Write-Log "User can be imported."
                }
                catch {
                    Write-Log "ERROR: Failed to import user $Username. Reason: $_"
                    Write-Host -ForegroundColor Red "`nERROR: Failed to import user $Username. Reason: $_"
                    continue
                }
                
		        Read-Host -Prompt "Press any key to import user"
		
                #Account will be created in the OU provided by the $OU variable read from the CSV file
                try {
                    New-ADUser @ADUserParams
                    Write-Log "SUCCESS: User $Username imported successfully."
                    Write-Host -ForegroundColor Green "User $Username created successfully." `n
                }
                catch {
                    Write-Log "ERROR: Failed to create user $Username. Reason: $_"
                    Write-Host -ForegroundColor Red "ERROR: Failed to create user $Username. Reason: $_"
                }
                
            }

            
            

            #Creation of the Home Directory and/or Profile Directory
            if($usercreated)
            {
                <#
                Home Directory
                #>
                Write-Log "Creation of the Home Directory"
                Read-Host -Prompt "Press any key to create HomeDirectory"
                #if ( !(Test-Path -Path "$HomeDirectory" -PathType Container) -and ![string]::IsNullOrEmpty($HomeDirectory) ) {
                
                # Ensure $HomeDirectory is not empty before using it with Test-Path
                if ( -not [string]::IsNullOrEmpty($HomeDirectory) -and -not (Test-Path -Path $HomeDirectory -PathType Container) ) {
                    # Doesn't exist so create it.
                    Write-Host "Home directory doesn't exist. Creating home directory..." `n
                    Write-Log "Home directory doesn't exist. Creating home directory..."

                    # Trim whitespace
                    $HomeDirectory = $HomeDirectory.Trim()

                    # Remove leading slashes and split
                    $trimmedPath = $HomeDirectory.TrimStart('\')
                    $parts = $trimmedPath -split '\\'

                    # Check parts count to avoid errors
                    if ($parts.Length -ge 3) {
                        $sharePath = "\\" + $parts[0] + "\" + $parts[1]   # e.g. \\PSC-SRV25-FILE1\Benutzerordner
                        $username = $parts[2]                              # e.g. import.user

                        try {
                            New-Item -Path $sharePath -Name $username -ItemType Directory -Force
                        }
                        catch {
                            Write-Log " ERROR: Can not create Home Directory! Reason: $_"
                            Write-Host -ForegroundColor Red "ERROR: Can not create Home Directory! Reason: $_"
                        }
                        finally{
                            $userDir = "$HomeDirectory"
                            Write-Host "Home Directory $userDir created." -ForegroundColor Green `n
                            Write-Log "Home Directory $userDir created."
                        }
                    }
                    else {
                        Write-Host -ForegroundColor Red "Invalid HomeDirectory path format: $HomeDirectory"
                        Write-Log "Invalid HomeDirectory path format: $HomeDirectory"
                    }

                    $userPrincipal = "$Username@$Domain"
                    Write-Host "User Principal: "$userPrincipal
                    Write-Log "User Principal: $userPrincipal"

                    #Get User SID
                    try{
                        $sid = (New-Object System.Security.Principal.NTAccount("$Username")).Translate([System.Security.Principal.SecurityIdentifier]).Value
                    }
                    catch{
                        Write-Log " ERROR: Can not get Users SID!
    Reason: $_"
			            Write-Host -ForegroundColor Red "ERROR: Can not get Users SID!
    Reason: $_"
                        Read-Host -Prompt " Press any key to exit"
			            exit
                    }
                    Write-Host "The Users SID: "$sid
                    Write-Log "The Users SID: $sid"

                    Read-Host -Prompt "Press any key to set ACL"

                    # Modify  Permissions on homedir
                    if($sid){
                        $Rights=[System.Security.AccessControl.FileSystemRights]::FullControl #Options: Read;Write;Modify;FullControl
            
                        $Inherit=[System.Security.AccessControl.InheritanceFlags]::ObjectInherit -bor [System.Security.AccessControl.InheritanceFlags]::ContainerInherit #Options: None - The ACE is not inherited by child objects.;ContainerInherit - The ACE is inherited by child container objects.;ObjectInherit - The ACE is inherited by child leaf objects.
            
                        $Propogation=[System.Security.AccessControl.PropagationFlags]::None #Options: None - Specifies that no inheritance flags are set.;InheritOnly - Specifies that the ACE is propagated only to child objects. This includes both container and leaf child objects.;NoPropagateInherit - Specifies that the ACE is not propagated to child objects.
            
                        $Access=[System.Security.AccessControl.AccessControlType]::Allow #Options: Allow;Deny
            
                        $AccessRule = new-object System.Security.AccessControl.FileSystemAccessRule("$Username",$Rights,$Inherit,$Propogation,$Access)
                        try{
                            $ACL = Get-Acl $userDir
                            $ACL.AddAccessRule($AccessRule)
                            #Sets this User as Owner of the Directory
                            #$Account = new-object System.Security.Principal.NTAccount($Username)
                            #$ACL.setowner($Account)
                            $ACL.SetAccessRule($AccessRule)
                        }
                        catch{
                            Write-Log " ERROR: Can not get ACL for Home Directory!
        Reason: $_"
			                Write-Host -ForegroundColor Red "ERROR: Can not get ACL for Home Directory!
        Reason: $_"
                        }
                    
                        try{
                            Set-Acl $userDir $ACL
                        }
                        catch{
                            Write-Log " ERROR: Can not set ACL for Home Directory!
        Reason: $_"
			                Write-Host -ForegroundColor Red "ERROR: Can not set ACL for Home Directory!
        Reason: $_"
                        }
                    }
                    else{
                        Write-Host -ForegroundColor Red " ERROR: Can not modify permissions on Users Home Diretory!"
                        Write-Log " ERROR: Can not modify permissions on Users Home Diretory!"
                    }
                }

                <#
                Profile Directory
                #>
                Write-Log "Creation of the Profile Directory"
                Read-Host -Prompt "Press any key to create ProfileDirectory"

                # Ensure $ProfilePath is not empty before using it with Test-Path
                if ( -not [string]::IsNullOrEmpty($ProfilePath) -and -not (Test-Path -Path $ProfilePath -PathType Container) ) {
                    # Doesn't exist so create it.
                    Write-Host "Profile directory doesn't exist. Creating profile directory..." `n
                    Write-Log "Profile directory doesn't exist. Creating profile directory..."

                    # Trim whitespace
                    $ProfilePath = $ProfilePath.Trim()

                    # Remove leading slashes and split
                    $trimmedPath = $ProfilePath.TrimStart('\')
                    $parts = $trimmedPath -split '\\'

                    # Check parts count to avoid errors
                    if ($parts.Length -ge 3) {
                        $proPath = "\\" + $parts[0] + "\" + $parts[1]   # e.g. \\PSC-SRV25-FILE1\Benutzerordner
                        $username = $parts[2]                              # e.g. import.user

                        try {
                            New-Item -Path $proPath -Name $username -ItemType Directory -Force
                        }
                        catch {
                            Write-Log " ERROR: Can not create Profile Directory! Reason: $_"
                            Write-Host -ForegroundColor Red "ERROR: Can not create Profile Directory! Reason: $_"
                        }
                        finally{
                            $userDir = "$ProfilePath"
                            Write-Host "Profile Directory $userDir created." -ForegroundColor Green `n
                            Write-Log "Profile Directory $userDir created."
                        }
                    }
                    else {
                        Write-Host -ForegroundColor Red "Invalid ProfileDirectory path format: $ProfilePath"
                        Write-Log "Invalid ProfileDirectory path format: $ProfilePath"
                    }

                    $userPrincipal = "$Username@$Domain"
                    Write-Host "User Principal: "$userPrincipal
                    Write-Log "User Principal: $userPrincipal"

                    #Get User SID
                    try{
                        $sid = (New-Object System.Security.Principal.NTAccount("$Username")).Translate([System.Security.Principal.SecurityIdentifier]).Value
                    }
                    catch{
                        Write-Log " ERROR: Can not get Users SID!
    Reason: $_"
			            Write-Host -ForegroundColor Red "ERROR: Can not get Users SID!
    Reason: $_"
                        Read-Host -Prompt " Press any key to exit"
			            exit
                    }
                    Write-Host "The Users SID: "$sid
                    Write-Log "The Users SID: $sid"

                    Read-Host -Prompt "Press any key to set ACL"

                    # Modify  Permissions on profiledir
                    if($sid){
                        $Rights=[System.Security.AccessControl.FileSystemRights]::FullControl #Options: Read;Write;Modify;FullControl
            
                        $Inherit=[System.Security.AccessControl.InheritanceFlags]::ObjectInherit -bor [System.Security.AccessControl.InheritanceFlags]::ContainerInherit #Options: None - The ACE is not inherited by child objects.;ContainerInherit - The ACE is inherited by child container objects.;ObjectInherit - The ACE is inherited by child leaf objects.
            
                        $Propogation=[System.Security.AccessControl.PropagationFlags]::None #Options: None - Specifies that no inheritance flags are set.;InheritOnly - Specifies that the ACE is propagated only to child objects. This includes both container and leaf child objects.;NoPropagateInherit - Specifies that the ACE is not propagated to child objects.
            
                        $Access=[System.Security.AccessControl.AccessControlType]::Allow #Options: Allow;Deny
            
                        $AccessRule = new-object System.Security.AccessControl.FileSystemAccessRule("$Username",$Rights,$Inherit,$Propogation,$Access)
                        try{
                            $ACL = Get-Acl $userDir
                            $ACL.AddAccessRule($AccessRule)
                            #Sets this User as Owner of the Directory
                            #$Account = new-object System.Security.Principal.NTAccount($Username)
                            #$ACL.setowner($Account)
                            $ACL.SetAccessRule($AccessRule)
                        }
                        catch{
                            Write-Log " ERROR: Can not get ACL for Profile Directory!
        Reason: $_"
			                Write-Host -ForegroundColor Red "ERROR: Can not get ACL for Profile Directory!
        Reason: $_"
                        }
                    
                        try{
                            Set-Acl $userDir $ACL
                        }
                        catch{
                            Write-Log " ERROR: Can not set ACL for Profile Directory!
        Reason: $_"
			                Write-Host -ForegroundColor Red "ERROR: Can not set ACL for Profile Directory!
        Reason: $_"
                        }
                    }
                    else{
                        Write-Host -ForegroundColor Red " ERROR: Can not modify permissions on Users Diretory!"
                        Write-Log " ERROR: Can not modify permissions on Users Diretory!"
                    }
                }

                else {
                    Write-Host "Nothing to do..." -ForegroundColor Green `n
                    Write-Log "Nothing to do..."
                }
            }
            else {
                Write-Host "User doesn't exist." -ForegroundColor Red
                Write-Log "User doesn't exist."
            }
            
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



EF-Import-ADUsers
