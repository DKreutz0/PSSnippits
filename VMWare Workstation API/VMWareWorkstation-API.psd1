#Requires -RunAsAdministrator
#
# Module manifest for module 'VMWareWorkstation-API'
#
# Generated by: Dennis Kreutz
#
# Generated on: 14-1-2023
#
@{

# Script module or binary module file associated with this manifest.
RootModule = 'VMWareWorkstation-API.psm1'

# Version number of this module.
ModuleVersion = '1.0.1'

# Supported PSEditions
# CompatiblePSEditions = @()

# ID used to uniquely identify this module
GUID = '622b8ab6-d48b-475d-9795-cac38b1500a8'

# Author of this module
Author = 'Dennis Kreutz'

# Copyright statement for this module
Copyright = '(c) 2023 Dennis Kreutz. All rights reserved.'

# Description of the functionality provided by this module
Description = 'VMWare Workstation RESTAPI'

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '7.3.3'

# Name of the Windows PowerShell host required by this module
#PowerShellHostName = 'VMWareWorkstation-API'

# Minimum version of the Windows PowerShell host required by this module
#PowerShellHostVersion = '5.1.22621.963'

# Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# DotNetFrameworkVersion = ''

# Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# CLRVersion = ''

# Processor architecture (None, X86, Amd64) required by this module
# ProcessorArchitecture = ''

# Modules that must be imported into the global environment prior to importing this module
RequiredModules = @('credentialmanager')

# Assemblies that must be loaded prior to importing this module
# RequiredAssemblies = @()

# Script files (.ps1) that are run in the caller's environment prior to importing this module.
ScriptsToProcess = @('Functions-VMWareWorkstation-API.ps1')

# Type files (.ps1xml) to be loaded when importing this module
# TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
# FormatsToProcess = @()

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
#NestedModules = @('')

# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
FunctionsToExport =  @('Get-VMWareWorkstationConfiguration','Get-VMTemplate','Get-VM','Get-VMConfigParam','Get-VMRestrictions','Set-VMConfig','Set-VMConfigParam','New-VMClonedMachine','Register-VMClonedMachine','Remove-VMClonedMachine','Get-VMPowerSettings','Set-VMPowerSettings','Get-VMSSharedFolders','Set-VMSSharedFolders','Add-VMSSharedFolders','Remove-VMSSharedFolders')

# Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
CmdletsToExport = '*'

# Variables to export from this module
VariablesToExport = '*'

# Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
AliasesToExport = '*'

# DSC resources to export from this module
# DscResourcesToExport = @()

# List of all modules packaged with this module
ModuleList = @()

# List of all files packaged with this module
FileList = @('VMWareWorkstation-API.psm1','VMWareWorkstation-API.psd1','Functions-VMWareWorkstation-API.ps1')

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{
	"PackageManagementProviders" = 'VMWareWorkstation-API.psm1'
    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        Tags = @('VMWare','Workstation','REST','API','RESTAPI','VM','Virtual Machine','Clone','Cloning','Automation','Golden image','Golden image')

        # A URL to the license for this module.
        # LicenseUri = ''

        # A URL to the main website for this project.
        ProjectUri = 'https://github.com/DKreutz0/VMWareWorkstation-API.git'

        # A URL to an icon representing this module.
        # IconUri = ''

        # ReleaseNotes of this module
        ReleaseNotes = 'https://github.com/DKreutz0/VMWareWorkstation-API#readme'

    } # End of PSData hashtable

} # End of PrivateData hashtable

# HelpInfo URI of this module
HelpInfoURI = 'https://github.com/DKreutz0/VMWareWorkstation-API#readme'

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''

}

