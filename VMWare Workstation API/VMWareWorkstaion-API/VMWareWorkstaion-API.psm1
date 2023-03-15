#Requires -RunAsAdministrator

Function VMWareSetPassword {
   
    $Credentials = Get-StoredCredential -Target "VMWARE-API-VMREST-PASSWORD" –AsCredentialObject
    
    if (!($Credentials.Password)) {
        [void]::(New-StoredCredential -Target "VMWARE-API-VMREST-PASSWORD" -Credentials $(Get-Credential -UserName $VMwareWorkstationConfigParameters.username -message "Provide the vmrest credentials") -Persist LocalMachine)
    }
                    
    if (!(Get-Member -InputObject $VMwareWorkstationConfigParameters -Name Password)) {
        $Global:VMwareWorkstationConfigParameters | Add-Member -MemberType NoteProperty -Name "Password" -Value $Credentials.Password -Force -ErrorAction Stop
    }
    else {
        $VMwareWorkstationConfigParameters.password = $Credentials.Password 
    }    
}
                   
Function VMWare_ExportSettings {
    $VMwareWorkstationConfigParameters | Export-Clixml -Path "$PSScriptRoot\Settings-$($([System.Security.Principal.WindowsIdentity]::GetCurrent().Name).replace("\","-")).xml" -Force
}

Function VMWare_RetrieveSettings {

    try {
          [void]::(Get-Variable -Name VMwareWorkstationConfigParameters -ErrorAction Stop)
        }
    catch {
        $Global:VMwareWorkstationConfigParameters = New-Object PSObject
    }  
   
    try {        
        if ([string]::IsNullOrEmpty($VMwareWorkstationConfigParameters.Name) ) {
            Write-Message -Message "Gathering Information about the VMWare Workstation installation on your computer: $(hostname)" -MessageType INFORMATION
            
            $Global:VMwareWorkstationConfigParameters = Get-CimInstance  -ClassName Win32_Product -ErrorAction Stop | Where-Object { $_.Name -like "*VMware Workstation" } | Select-Object Name, Version, InstallLocation
            Write-Message -Message "Vmware Workstation $($VMwareWorkstationConfigParameters.Version) found" -MessageType INFORMATION 
        }
    }
    catch {
        Write-Message -Message "Cannot load the CimInstance Win32_Product $($error[0])" -MessageType ERROR
        break
    }

    try {
        
        if ([string]::IsNullOrEmpty($VMwareWorkstationConfigParameters.InstallLocation)) {
            
            Write-Message -Message "Could not find the installation folder in the registry. Please provide the VMWare $($VMwareWorkstationConfigParameters.Version) installation folder" -MessageType INFORMATION

            [int]$RetryRetrieveFolder            
            do {
                if ($FolderBrowserDialogPath = ShowFolder -Parameter GetVMWareWorkstationInstallationPath) {
                    if (Test-Path $FolderBrowserDialogPath.FullName -ErrorAction Stop) {
            
                        if (!(Get-Member -InputObject $VMwareWorkstationConfigParameters -Name installlocation)) {
                            $Global:VMwareWorkstationConfigParameters | Add-Member -MemberType NoteProperty -Name "InstallLocation" -Force -ErrorAction Stop
                        }

                        $Global:VMwareWorkstationConfigParameters.InstallLocation = $FolderBrowserDialogPath.DirectoryName
                        Write-Message -Message "Vmware Workstation $($VMwareWorkstationConfigParameters.Version) Installlocation defined as: $($VMwareWorkstationConfigParameters.InstallLocation)" -MessageType INFORMATION
                        [void]::($RetryRetrieveFolder = 0)
                    } 
                }
                else {
                        Write-Message -Message "Vmware Workstation installationfolder $($VMwareWorkstationConfigParameters.Version) could not be defined, Last retry" -MessageType ERROR
                }
                [void]::($RetryRetrieveFolder++)

                if ($RetryRetrieveFolder -gt 1) {
                    Write-Message -Message "The Path $($FolderBrowserDialogPath) does not contain the vmware installation, please retry" -MessageType INFORMATION
                }

            } until (($RetryRetrieveFolder -ge 2) -or (!([string]::IsNullOrEmpty($VMwareWorkstationConfigParameters.InstallLocation))))
        }
    }
    catch {
         Write-Message -Message "Unknown Error occured $($error[0])" -MessageType ERROR 
    }
    Try {
        $GetVMRESTConfig = Get-ChildItem -Path $([Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)) -Recurse | Where-Object { $_.Name -eq "vmrest.cfg" } | Select-Object -ExpandProperty fullname

        if (Test-Path $GetVMRESTConfig) {
            $GetVMRESTConfigLoader = $(Get-Content -Path $GetVMRESTConfig -ErrorAction Stop | Select-String -Pattern 'PORT','USERNAME' -AllMatches ).line.Trim()

            if (!([String]::IsNullOrEmpty(($GetVMRESTConfigLoader)))) {
                $GetVMRESTConfigLoader | ForEach-Object { 
                    $VMwareWorkstationConfigParameters | Add-Member Noteproperty -Force $($_.split("=")[0]) $($_.split("=")[1]) 
            }
            
            $VMwareWorkstationConfigParameters | Add-Member NoteProperty "HostAddress" -Value "127.0.0.1" -Force
            Remove-Variable -name GetVMRESTConfigLoader,GetVMRESTConfig -ErrorAction SilentlyContinue
            }
        }
        else {
            
        }
    }
    catch {
        Write-Message -Message "Cannot load the vmrest.cfg file" -MessageType ERROR
        break        
    }
    finally {
        
        Write-Message -Message "VMWareWorkstaion-API Settings Loaded" -MessageType INFORMATION
        Remove-Variable -Name FolderBrowserDialog,FolderBrowserDialogPath,RetryRetrieveFolder -ErrorAction SilentlyContinue
    }    
}

Function VMWare_ImportSettings {
    $VMWareImportSettings = "$PSScriptRoot\Settings-$($([System.Security.Principal.WindowsIdentity]::GetCurrent().Name).replace("\","-")).xml"

    try {
        if (Test-Path -Path $VMWareImportSettings -ErrorAction Stop) {
            
            $GLOBAL:VMwareWorkstationConfigParameters = Import-Clixml -Path $VMWareImportSettings -ErrorAction Stop
            VMWareSetPassword
            RunVMRestConfig -Config ConfigCredentialsCheck

        }
        else {
            VMWare_RetrieveSettings
        }
    }
    catch {
        VMWare_RetrieveSettings
    }

    if (!([string]::IsNullOrEmpty($VMwareWorkstationConfigParameters))) {
        
        if (!(Test-Path -Path $VMwareWorkstationConfigParameters.InstallLocation)) {
            VMWare_RetrieveSettings 
        }
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
                        Remove-StoredCredential -Target "VMWARE-API-VMREST-PASSWORD"
                        VMWareSetPassword
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
        Start-Process -FilePath $(Join-Path -Path $VMwareWorkstationConfigParameters.InstallLocation -ChildPath "\vmrest.exe") -ArgumentList "-C" -Wait
        Vmware_SetPassword
        RunVMRestConfig -Config ConfigCredentialsCheck
        VMWare_ExportSettings
        VMWare_ImportSettings
    }
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

Function Get-VMWareWorkstationConfiguration {
    VMWare_ImportSettings
    VMWareSetPassword
    RunVMRestConfig -Config ConfigCredentialsCheck  
    VMWare_ExportSettings
    VMWare_ImportSettings
    Write-Message -Message "VMwareWorkstationConfigParameters: `n" -MessageType INFORMATION
    (Get-Variable VMwareWorkstationConfigParameters -ErrorAction SilentlyContinue -Verbose) | Select-Object -ExpandProperty Name 
    (Get-Member -InputObject $VMwareWorkstationConfigParameters -MemberType NoteProperty -ErrorAction SilentlyContinue | Select-Object Name, Definition)
    $GLOBAL:VMWAREWorkstationAPIURL = "http://$($VMwareWorkstationConfigParameters.HostAddress):$($VMwareWorkstationConfigParameters.port)/api/" 
}

Function Get-VMTemplate 
{
    [cmdletbinding()]
    param (
        [Parameter(Mandatory)]
        $VirtualMachinename
    )

    if (!($VMwareWorkstationConfigParameters)) {
        [void](Get-VMWareWorkstationConfiguration)
    }

    $URL = "$($VMWAREWorkstationAPIURL)vms"
    $RequestResponse=Invoke-VMWareRestRequest -method Get
    $RequestResponse
    foreach ($VM in $RequestResponse)
    {
        $PathSplit = ($vm.path).split("\")
        $vmxfile = $PathSplit[($PathSplit.Length)-1]
        $thisVM = ($vmxfile).split(".")[0]
        if ($thisVM -eq $VirtualMachinename) { return $VM ;break}
    } 
    return $VM
}