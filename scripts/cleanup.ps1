#!/usr/bin/env pwsh

<#
.SYNOPSIS
  Cleanup PortableApps installers and build depencies installers.

.DESCRIPTION
  A simple script to cleanup the file in the root of the repository
  with pattern '*Portable*.paf.exe' and 'PortableApps.com*.paf.exe'.
  After a few builds it can become quite messy to navigate around
  the git submodules and the build artifacts.

.PARAMETER SkipApps
  Skip deletion of the PortableApp installers with pattern
  '*Portable*.paf.exe'.

.PARAMETER SkipInfra
  Skip deletion of the PortableApps.com build infractructure
  installers with pattern 'PortableApps.com*.paf.exe'.

.PARAMETER CleanDownloads
  Also cleanup the Download directory under each application
  directory e.g '*Portable/Downloads/*'

#>

Param(
  [Switch] $SkipApps,
  [Switch] $SkipInfra,
  [Switch] $CleanDownloads
)
# -----------------------------------------------------------------------------
# Globals
# -----------------------------------------------------------------------------
$InstallersDir = Resolve-Path "$PSScriptRoot/.."

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
Function Remove-Files() {
  Param(
    [String] $Message,
    [Object] $Files
  )
  If ($Files.Count -eq 0) { Return }
  $Message -f $Files.Count, $InstallersDir
  $Files | ForEach-Object {
    " - Removing File '$_'"
    Remove-Item -Path $_
  }
}

Function Remove-Installers() {
  Param(
    [String] $Filter,
    [String] $Message
  )
  $Files = Get-ChildItem -Path $InstallersDir -File -Filter $Filter
  Remove-Files -Message $Message -Files $Files
}

Function Remove-AppInstallers() {
  If ($SkipApps) { Return }
  $Message = "Removing {0} PortableApps installers from '{1}'"
  Remove-Installers -Filter "*Portable_*.paf.exe" -Message $Message
  $Message = "Removing {0} PortableApps installers checksum from '{1}'"
  Remove-Installers -Filter "*Portable_*.paf.exe.sha256" -Message $Message
}

Function Remove-InfraInstallers() {
  If ($SkipInfra) { Return }
  $Message = "Removing {0} build infrastructure installers from '{1}'"
  Remove-Installers -Filter "PortableApps.com*.paf.exe" -Message $Message
}

Function Clean-DownloadDirectory() {
  If (!($CleanDownloads)) { Return }
  $Files = Get-Childitem -Path "$InstallersDir" -Recurse -File | `
    ForEach-Object { If ($_.Directory -Match "Download$") { $_.FullName } }
  $Message = "Removing {0} Files from '{1}/*Portable/Download' directories"
  Remove-Files -Message $Message -Files $Files
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
Remove-AppInstallers
Remove-InfraInstallers
Clean-DownloadDirectory
