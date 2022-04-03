<#
.SYNOPSIS
  Upgrade PortableApps from the uroesch collection.

.DESCRIPTION
  Check for new versions from the uroesch collection of PortableApps,
  download them and the install.

.PARAMETER PADir
  Specify the PortableApps base directory.
#>

Param(
  [String] $PADir = '.\PortableApps'
)

# -----------------------------------------------------------------------------
# Globals
# -----------------------------------------------------------------------------
$ScriptDomain  = 'https://raw.githubusercontent.com'
$ScriptUrlPath = '/uroesch/PortableApps/master/CommonFiles/Other/Update'
$ScriptBaseUrl = "$ScriptDomain$ScriptUrlPath"

$Scripts = @(
  'PA-Upgrade.ps1',
  'PortableAppsCommon.psm1',
  'IniConfig.psm1'
)

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
Function Find-Apps {
  Param (
    [String] $PADir
  )
  $Pattern = "[A-Z0-9].*Portable$"
  $DirSeparator = [IO.Path]::DirectorySeparatorChar
  Get-ChildItem -Path $PADir -Recurse -Filter 'update.ini' | ForEach-Object {
    $Name = (
      $_.Directory -split [Regex]::Escape($DirSeparator) | `
        Select-String  -Pattern $Pattern | `
        Out-String `
      ).Trim()
    $Name
  } | Where { $_ -match $Pattern }
}

Function Create-UpdateDir {
  Param(
    [String] $PADir,
    [String] $Name
  )
  If (!($Name -match "Portable$")) { $Name += 'Portable' }
  $AppDir    = [System.IO.Path]::Combine($PADir, $Name)
  $Updatedir = [System.IO.Path]::Combine($AppDir, 'Other', 'Update')
  If (!(Test-Path $UpdateDir)) {
    New-Item -Path $UpdateDir -ItemType Directory
  }
  Return $UpdateDir
}


Function Download-UpdateScripts {
  Param(
    [String] $UpdateDir
  )
  $Scripts | ForEach-Object {
    $ScriptPath = Join-Path $UpdateDir $_
    Invoke-WebRequest -Uri "$ScriptBaseUrl/$_" -OutFile $ScriptPath
  }
}

Function Upgrade-Application {
  Param(
    [String] $UpdateDir
  )
  $ScriptName    = 'PA-Upgrade.ps1'
  $UpgradeScript = Join-Path $UpdateDir 'PA-Upgrade.ps1'
  & powershell -ExecutionPolicy ByPass -File $UpgradeScript
}


# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
Find-Apps -PADir $PADir | Sort | ForEach-Object {
  $UpdateDir = Create-UpdateDir -PADir $PAdir -Name $_
  Download-UpdateScripts -UpdateDir $UpdateDir
  Upgrade-Application -UpdateDir $UpdateDir
}