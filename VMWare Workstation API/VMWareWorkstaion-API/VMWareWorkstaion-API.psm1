#Requires -RunAsAdministrator

Function Write-Message {
    [cmdletbinding()]
    Param 
    (
        [Parameter(Mandatory)]
        [String]$Message,

        [Parameter(Mandatory)]
        [ValidateSet('ERROR', 'INFORMATION', 'WARNING')]
        $MessageType     
    )
    switch ($MessageType) {
        ERROR { 
            $ForegroundColor = 'White'
            $BackgroundColor = 'Red'
            $MessageStartsWith = "[ERROR] - " 
        }
        INFORMATION {
            $ForegroundColor = 'White'
            $BackgroundColor = 'blue'
            $MessageStartsWith = "[INFORMATION] - " 
        }
        WARNING {
            $ForegroundColor = 'White'
            $BackgroundColor = 'DarkYellow'
            $MessageStartsWith = "[WARNING] - " 
        }
    }
   Write-Host "$MessageStartsWith $Message" -ForegroundColor $ForegroundColor -BackgroundColor $BackgroundColor
}

Function ShowFolder {
    [cmdletbinding()]
    Param 
    (
        [Parameter(Mandatory)]
        [ValidateSet('GetVMWareWorkstationInstallationPath')]
        $Parameter
    )

    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop      
    $FolderBrowserDialog = New-Object System.Windows.Forms.FolderBrowserDialog -ErrorAction Stop
    $FolderBrowserDialog.Description = "Select de Folder where VMWARE Workstation $($VMWareWorkStationSettings.Version) is installed"
    $FolderBrowserDialog.ShowNewFolderButton = $false
    $FolderBrowserDialog.rootfolder = "MyComputer"
    [void]::($FolderBrowserDialog.ShowDialog((New-Object System.Windows.Forms.Form -Property @{TopMost = $true; TopLevel = $true })))
    
    switch ($Parameter) {

        GetVMWareWorkstationInstallationPath { $FolderBrowserFile = "vmware.exe" }
    }

    $FolderBrowserDialogPath = Get-ChildItem -Path $FolderBrowserDialog.SelectedPath -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq $FolderBrowserFile }
    return $FolderBrowserDialogPath
}

try {
    [void]::(Get-Variable -Name $VMwareWorkstationConfigParameters -ErrorAction Stop)
    }
catch {
    $Global:VMwareWorkstationConfigParameters = New-Object PSObject
}

Function VMWare_SetPassword {
    
    $Credentials = Get-StoredCredential -Target "VMWARE-API-VMREST-PASSWORD" –AsCredentialObject
    
    if (!($Credentials.Password)) {
        [void]::(New-StoredCredential -Target "VMWARE-API-VMREST-PASSWORD" -Credentials $(Get-Credential -UserName $VMwareWorkstationConfigParameters.username -message "Provide the vmrest credentials") -Persist LocalMachine)
        $Credentials = Get-StoredCredential -Target "VMWARE-API-VMREST-PASSWORD" –AsCredentialObject   
    }
    
    $securePassword = $Credentials.Password | ConvertTo-SecureString -AsPlainText -Force
    Remove-Variable -Name $Credentials -ErrorAction SilentlyContinue         
    
    if (!(Get-Member -InputObject $VMwareWorkstationConfigParameters -Name Password -ErrorAction SilentlyContinue)) {
        $Global:VMwareWorkstationConfigParameters | Add-Member -MemberType NoteProperty -Name "Password" -Value $securePassword -Force -ErrorAction Stop
    }
    else {
        $Credentials = Get-StoredCredential -Target "VMWARE-API-VMREST-PASSWORD" –AsCredentialObject
        $VMwareWorkstationConfigParameters | Add-Member -MemberType NoteProperty -Name "Password" -Value $securePassword -Force -ErrorAction Stop
    } 
    Remove-Variable $securePassword -ErrorAction SilentlyContinue
}

Function RunVMRestConfig {
    [cmdletbinding()]
    Param 
    (
        [Parameter(Mandatory)]
        [ValidateSet('Preconfig','ConfigCredentialsCheck')]
        $Config     
    )
    switch ($Config) {
        Preconfig { 
            Write-Host "TEST"
        }
        ConfigCredentialsCheck {
            if (($VMwareWorkstationConfigParameters.HostAddress) -and ($VMwareWorkstationConfigParameters.port) -and ($VMwareWorkstationConfigParameters.Password)) {
                 $URL = "http://$($VMwareWorkstationConfigParameters.HostAddress):$($VMwareWorkstationConfigParameters.port)/api/vms"  
                 [void]::(Invoke-VMWareRestRequest -Method GET -Uri $URL)
            }
        }
    }
}

Function VMWare_ImportSettings {
    $VMWareImportSettings = "$PSScriptRoot\Settings-$($([System.Security.Principal.WindowsIdentity]::GetCurrent().Name).replace("\","-")).xml"

    try {
        if (Test-Path -Path $VMWareImportSettings -ErrorAction Stop) {
            
            $GLOBAL:VMwareWorkstationConfigParameters = Import-Clixml -Path $VMWareImportSettings -ErrorAction Stop
        }
        else {
            VMWare_RetrieveSettings
        }
    }
    catch {
        VMWare_RetrieveSettings
    }
}

Function VMWare_ExportSettings {
    $VMwareWorkstationConfigParameters | Export-Clixml -Path "$PSScriptRoot\Settings-$($([System.Security.Principal.WindowsIdentity]::GetCurrent().Name).replace("\","-")).xml" -Force
}

Function VMWare_RetrieveSettings {

    [void]::([bool]$VmwareCouldNotDetermine_Win32_Products = $true) 

    if (Get-Member -InputObject $VMwareWorkstationConfigParameters -Name installlocation) {
        Remove-Variable VMwareWorkstationConfigParameters -ErrorAction SilentlyContinue
    }

    if (Test-Path -Path "$PSScriptRoot\Settings-$($([System.Security.Principal.WindowsIdentity]::GetCurrent().Name).replace("\","-")).xml") {
        Remove-Item -Path "$PSScriptRoot\Settings-$($([System.Security.Principal.WindowsIdentity]::GetCurrent().Name).replace("\","-")).xml" -Force -ErrorAction SilentlyContinue
    }

    # Gather Registry settings
    if ([string]::IsNullOrEmpty($VMwareWorkstationConfigParameters.Version)) {
        try {        
            if ([string]::IsNullOrEmpty($VMwareWorkstationConfigParameters.Name) ) {
                Write-Message -Message "Gathering Information about the VMWare Workstation installation on your computer: $(hostname)" -MessageType INFORMATION
            
                $Global:VMwareWorkstationConfigParameters = Get-CimInstance  -ClassName Win32_Product -ErrorAction Stop | Where-Object { $_.Name -like "*VMware Workstation" } | Select-Object Name, Version, InstallLocation
                Write-Message -Message "Vmware Workstation $($VMwareWorkstationConfigParameters.Version) found" -MessageType INFORMATION 
            }
        }
        catch {
            Write-Message -Message "Cannot load the CimInstance Win32_Product $($error[0])" -MessageType ERROR
            $VmwareCouldNotDetermine_Win32_Products = $true
        }
    }
    # Gathering Folder information
     try {
        if ([string]::IsNullOrEmpty($VMwareWorkstationConfigParameters.InstallLocation)) {
            
            Write-Message -Message "Could not find the installation folder in the registry. Please provide the VMWare $($VMwareWorkstationConfigParameters.Version) installation folder" -MessageType INFORMATION

            [void]::([int]$RetryRetrieveFolder)

            [bool]$RetryRetrieveFolderError = $false    
            do {
                if ($FolderBrowserDialogPath = ShowFolder -Parameter GetVMWareWorkstationInstallationPath) {
                    if (Test-Path $FolderBrowserDialogPath.FullName -ErrorAction Stop) {
            
                        if (!(Get-Member -InputObject $VMwareWorkstationConfigParameters -Name installlocation)) {
                            $Global:VMwareWorkstationConfigParameters | Add-Member -MemberType NoteProperty -Name "InstallLocation" -Value "" -Force -ErrorAction Stop
                        }

                        if ($VmwareCouldNotDetermine_Win32_Products) {
                            $Global:VMwareWorkstationConfigParameters.InstallLocation = $FolderBrowserDialogPath.DirectoryName
                            $Global:VMwareWorkstationConfigParameters | Add-Member -MemberType NoteProperty -Name "Name" -Value "VMware Workstation" -Force -ErrorAction Stop
                        }
                        $Global:VMwareWorkstationConfigParameters | Add-Member -MemberType NoteProperty -Name "Version" -Value "$([System.Diagnostics.FileVersionInfo]::GetVersionInfo($FolderBrowserDialogPath.fullname) | Select-Object -ExpandProperty FileVersion)" -Force
                        Write-Message -Message "Vmware Workstation $($VMwareWorkstationConfigParameters.Version) Installlocation defined as: $($VMwareWorkstationConfigParameters.InstallLocation)" -MessageType INFORMATION
                        $VmwareCouldNotDetermine_Win32_Products = $true
                        [void]::($RetryRetrieveFolder = 0)
                    } 
                }
                else {
                        Write-Message -Message "Vmware Workstation installationfolder $($VMwareWorkstationConfigParameters.Version) could not be defined, Last retry" -MessageType ERROR
                }
  
                if ($RetryRetrieveFolder -gt 0) {
                    Write-Message -Message "The Path $($FolderBrowserDialogPath) does not contain the vmware installation, please retry" -MessageType INFORMATION
                    $RetryRetrieveFolderError = $true
                    $VmwareCouldNotDetermine_Win32_Products = $false
                }
                if ($RetryRetrieveFolder -gt 1) {
                    Write-Message -Message "The Path $($FolderBrowserDialogPath) does not contain the vmware installation, last retry" -MessageType INFORMATION
                    $RetryRetrieveFolderError = $true
                    $VmwareCouldNotDetermine_Win32_Products = $false
                    Write-Error -Exception "Path Not found" -ErrorAction Stop
                }
                [void]::($RetryRetrieveFolder++)

            } until (($RetryRetrieveFolder -ge 2) -or (!([string]::IsNullOrEmpty($VMwareWorkstationConfigParameters.InstallLocation))))
        }
        else {
            $VmwareCouldNotDetermine_Win32_Products = $true
        }
    }
    catch {
         if ($RetryRetrieveFolderError) {
             Write-Message -Message "Doing a alternative scan - Scanning all filesystem disks that are found" -MessageType INFORMATION
             $CollectDriveLetters = $(Get-PSDrive -PSProvider FileSystem ) | Select-Object -ExpandProperty Root
             $Collected = [System.Collections.ArrayList]@()
             $CollectDriveLetters | ForEach-Object { $Collected += Get-ChildItem -Path $($_) -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq "vmware.exe" } }

            if (!([string]::IsNullOrEmpty($Collected))) {
                if ($Collected.count -le 1) {
                       $Global:VMwareWorkstationConfigParameters | Add-Member -MemberType NoteProperty -Name "Name" -Value "VMware Workstation" -Force -ErrorAction Stop
                       $Global:VMwareWorkstationConfigParameters | Add-Member -MemberType NoteProperty -Name "Version" -Value "$([System.Diagnostics.FileVersionInfo]::GetVersionInfo($Collected.fullname) | Select-Object -ExpandProperty FileVersion)" -Force
                       $Global:VMwareWorkstationConfigParameters | Add-Member -MemberType NoteProperty -Name "InstallLocation" -Value $Collected.DirectoryName -Force -ErrorAction Stop
                       $VmwareCouldNotDetermine_Win32_Products = $true
                }
                if ($Collected.count -gt 1) {
                   Write-Output "#functie schrijven om te bepalen wat te doen."
                }
            }
         }
         else {
             Write-Message -Message "Unknown error occured the script is quitting" -MessageType ERROR
         }

        if ([string]::IsNullOrEmpty($VMwareWorkstationConfigParameters.InstallLocation)) {
            Write-Message -Message "Cannot determine if VMWare Workstation is installed on this machine, the script is quitting" -MessageType ERROR
        }
    }

   #Gather VMRest Config Settings vmrest.cfg
   Write-Message -Message "Gathering VMREST config" -MessageType INFORMATION

    Try {
        $GetVMRESTConfig = Get-ChildItem -Path $([Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)) -Recurse | Where-Object { $_.Name -eq "vmrest.cfg" } | Select-Object -ExpandProperty fullname -ErrorAction SilentlyContinue

        if (Test-Path $GetVMRESTConfig) {
            $GetVMRESTConfigLoader = $(Get-Content -Path $GetVMRESTConfig -ErrorAction Stop | Select-String -Pattern 'PORT','USERNAME' -AllMatches ).line.Trim()

            if (!([String]::IsNullOrEmpty(($GetVMRESTConfigLoader)))) {
                $GetVMRESTConfigLoader | ForEach-Object { 
                    $Global:VMwareWorkstationConfigParameters | Add-Member -MemberType Noteproperty $($_.split("=")[0]) $($_.split("=")[1]) -Force
            }
            
            $Global:VMwareWorkstationConfigParameters | Add-Member -MemberType NoteProperty "HostAddress" -Value "127.0.0.1" -Force
            Remove-Variable -name GetVMRESTConfigLoader,GetVMRESTConfig -ErrorAction SilentlyContinue
            }
        }
    }
    catch {
        Write-Message -Message "Cannot load the vmrest.cfg file" -MessageType INFORMATION 
        Remove-StoredCredential -Target "VMWARE-API-VMREST-PASSWORD" -ErrorAction SilentlyContinue
        Start-Process -FilePath $(Join-Path -Path $VMwareWorkstationConfigParameters.InstallLocation -ChildPath "\vmrest.exe") -ArgumentList "-C" -Wait
        VMWare_SetPassword
        VMWare_RetrieveSettings

 }
}

Function Invoke-VMWareRestRequest {
    [cmdletbinding()]
    Param 
    (
        $Uri=$URL,
        [Parameter(Mandatory)]
        [ValidateSet('GET', 'PUT', 'POST', 'DELETE')]
        $Method,
        $Body=$Null
    )
    if (!($(Get-Process -name vmrest -ErrorAction SilentlyContinue))) {
        Stop-Process -name vmrest -ErrorAction SilentlyContinue
        Start-Process -FilePath $(Join-Path -Path $VMwareWorkstationConfigParameters.InstallLocation -ChildPath "\vmrest.exe") -ArgumentList "-d" -NoNewWindow -PassThru
    } 
    if (($VMwareWorkstationConfigParameters.username) -and ($VMwareWorkstationConfigParameters.password)) {
        
        [pscredential]::new('user',$VMwareWorkstationConfigParameters.password).GetNetworkCredential().Password

        $Authentication = ("{0}:{1}" -f $VMwareWorkstationConfigParameters.username,$VMwareWorkstationConfigParameters.password)
        $Authentication = [System.Text.Encoding]::UTF8.GetBytes($Authentication)
        $Authentication = [System.Convert]::ToBase64String($Authentication)
        $Authentication = "Basic {0}" -f $Authentication

        $Headers = @{
            'authorization' =  $Authentication;
            'content-type' =  'application/vnd.vmware.vmw.rest-v1+json';
            'accept' = 'application/vnd.vmware.vmw.rest-v1+json';
            'cache-control' = 'no-cache'
        }
        $Error.clear()
        try {
            $RequestResponse = Invoke-RestMethod -Uri $URI -Method $Method -Headers $Headers -Body $body
            return $RequestResponse
        }
        catch {
            
            if ($Error[0].ErrorDetails.message) {
                $ErrorHandler = $Error[0].ErrorDetails.message | ConvertFrom-Json
                $ErrorHandler.Message
                switch ($ErrorHandler.Message) {
            
                    'Authentication failed' { 
                        Stop-Process -name vmrest -Force
                        Start-Process -FilePath $(Join-Path -Path $VMwareWorkstationConfigParameters.InstallLocation -ChildPath "\vmrest.exe") -ArgumentList "-C" -Wait
                        Remove-StoredCredential -Target "VMWARE-API-VMREST-PASSWORD" -ErrorAction SilentlyContinue
                        VMWare_SetPassword
                        VMWare_ExportSettings
                        VMWare_ImportSettings                        
                     } 
                     default { Write-Message -Message "Unknown error occured in the restapi call $($error[0])" -MessageType ERROR } 
                }
            }
        }
    }
    else {
        Write-Message -Message "Credentials not found" -MessageType WARNING
        VMWare_ImportSettings
        if (($VMwareWorkstationConfigParameters.username) -and ($VMwareWorkstationConfigParameters.password)) {
            Stop-Process -name vmrest -ErrorAction SilentlyContinue      
            Start-Process -FilePath $(Join-Path -Path $VMwareWorkstationConfigParameters.InstallLocation -ChildPath "\vmrest.exe") -ArgumentList "-C" -Wait
            Vmware_SetPassword
            RunVMRestConfig -Config ConfigCredentialsCheck
            VMWare_ExportSettings
        }
        else {
            Stop-Process -name vmrest -ErrorAction SilentlyContinue      
            Start-Process -FilePath $(Join-Path -Path $VMwareWorkstationConfigParameters.InstallLocation -ChildPath "\vmrest.exe") -ArgumentList "-C" -Wait
            Vmware_SetPassword
            RunVMRestConfig -Config ConfigCredentialsCheck
            VMWare_ExportSettings
        }
    }
}

Function Get-VMWareWorkstationConfiguration {
    VMWare_ImportSettings
    
    VMWare_SetPassword    
    VMWare_ExportSettings
    RunVMRestConfig -Config ConfigCredentialsCheck

    Write-Host "`n"
    (Get-Variable VMwareWorkstationConfigParameters -ErrorAction SilentlyContinue -Verbose) | Select-Object -ExpandProperty Name 
    (Get-Member -InputObject $VMwareWorkstationConfigParameters -MemberType NoteProperty -ErrorAction SilentlyContinue | Select-Object Name, Definition)
}