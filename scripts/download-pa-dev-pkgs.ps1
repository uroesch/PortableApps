#!/usr/bin/env powershell

<#
.SYNOPSIS
  Download and install the PortableApps.com Installer and Launcher
  package.

.DESCRIPTION
  A wrapper script to automate build infrastructure update and installation
  for PortableApps.
  Downloads and installs / update the packages PortableApps.comInstaller and
  PortableApps.comLauncher.

.PARAMETER WithoutInstaller
  Skip the update of the PortableApps.comInstaller.

.PARAMETER WithoutLauncher
  Skip the update of the PortableApps.comLauncher.

.PARAMETER Version
  Print Version and exit.
#>
#>

Param(
  [Switch] $WithoutInstaller,
  [Switch] $WithoutLauncher,
  [Switch] $Version
)

# -----------------------------------------------------------------------------
# Globals
# -----------------------------------------------------------------------------
$ScriptName         = $MyInvocation.MyCommand.Name -replace '.ps1', ''
$ScriptVersion      = '0.3.0'
$ScriptAuthor       = 'Urs Roesch'
$ScriptLicense      = 'GPL2'
$PARoot             = Resolve-Path -Path "$PSScriptRoot/.."
$BaseName           = "PortableApps.com"
$Domain             = 'https://portableapps.com'
$UrlBase            = "{0}/apps/development/portableapps.com_{1}"
$ProgressPreference = 'silentlyContinue'

# -----------------------------------------------------------------------------
# Filters
# -----------------------------------------------------------------------------
Filter Assemble-Url() {
  $UrlBase -f $Domain, $_.ToLower()
}

# -----------------------------------------------------------------------------

Filter Capitalize() {
  (Get-Culture).TextInfo.ToTitleCase($_.ToLower())
}

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
Function Print-Version() {
  If (!$Version) { Return }
  "`n{0} v{1}`nCopyright (c) {2}`nLicense - {3}`n" -f `
    $ScriptName, $ScriptVersion, $ScriptAuthor, $ScriptLicense
  Exit 0
}

# -----------------------------------------------------------------------------

Function Extract-Link() {
  Param(
    [String] $Name,
    [String] $Uri
  )
  Write-Host "Downloading '$Uri'"
  Try {
    $HTML = Invoke-Webrequest -Uri $Uri
    $Base = ($HTML.Links | Where-Object { $_.Href -Imatch "$Name.*.exe$" }).Href
    Return '{0}{1}' -f $Domain, $Base
  }
  Catch {
    Write-Host "Failed to Download '$Uri'"
  }
}

# -----------------------------------------------------------------------------

Function Download-Binary() {
  Param(
    [String] $Name
  )
  $Url         = $Name | Assemble-Url
  $JumpUrl     = Extract-Link -Name $Name -Uri $Url
  $DownloadUrl = Extract-Link -Name $Name -Uri $JumpUrl
  $OutFile     = ($DownloadUrl.Split('/').Split('='))[-1]
  $OutFile     = Join-Path $PARoot $OutFile
  If (Test-Path $OutFile) {
    Write-Host "File '${OutFile}' already exists not downloading"
    Return $OutFile
  }
  Try {
    Write-Host "Downloading '$DownloadUrl'"
    Invoke-Webrequest -Uri $DownloadUrl -OutFile $OutFile
    Return $OutFile
  }
  Catch {
    Write-Host "Failed to Download '$DownloadUrl'"
    Return $False
  }
}

# -----------------------------------------------------------------------------

Function Install-Dir() {
  Param(
    [String] $Name
  )
  Return "{0}{1}{2}{3}" -f `
    $PARoot, `
    [IO.Path]::DirectorySeparatorChar, `
    $BaseName, `
    ($Name | Capitalize)
}

# -----------------------------------------------------------------------------

Function Check-Version() {
  Param(
    [String] $Name,
    [String] $Installer
  )
  Try {
    $InstallDir = Install-Dir -Name $Name
    $AppInfo    = Join-Path $InstallDir 'App' 'AppInfo' 'appinfo.ini'
    $Version    = Select-String -Path $AppInfo -Pattern 'DisplayVersion' -Raw
    $Version    = ($Version -split "\s*=\s*")[1]
    Return $Installer -match "^$Version$"
  }
  Catch {
    Write-Host "Could not file $AppInfo; giving up"
    Return $False
  }
}

# -----------------------------------------------------------------------------

Function Check-Installation() {
  Param(
    [String] $Name,
    [String] $Installer
  )
  $InstallDir = Install-Dir -Name $Name
  If (Test-Path $InstallDir) {
    Return Check-Version -Name $Name -Installer $Installer
  }
  Return $False
}

# -----------------------------------------------------------------------------

Function Install-Package() {
  Param(
    [String] $Name
  )

  $Installer = Download-Binary -Name $Name
  If (Check-Installation -Name $Name -Installer $Installer) { Return }
  $Arguments = 'x -y -o"{0}" "{1}"' -f `
    (Install-Dir -Name $Name), `
    $Installer
  Start-Process 7z -ArgumentList $Arguments -NoNewWindow -Wait
}

Function Usage() {
  Param(
    [Boolean] $Help
  )
  If ($Help) {
    Write-Host $Help
    Get-Help
    exit
  }
}

Function Install-Launcher() {
  If ($WithoutLauncher) { Return }
  Install-Package -Name launcher
}

Function Install-Installer() {
  If ($WithoutInstaller) { Return }
  Install-Package -Name installer
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
Print-Version
Install-Installer
Install-Launcher
