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
#>

Param(
  [Switch] $SkipApps,
  [Switch] $SkipInfra
)
# -----------------------------------------------------------------------------
# Globals
# -----------------------------------------------------------------------------
$InstallersDir = Resolve-Path "$PSScriptRoot/.."

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
Function Remove-Installers() {
  Param(
    [String] $Filter,
    [String] $Message
  )
  $Files = Get-ChildItem -Path $InstallersDir -File -Filter $Filter
  If ($Files.Count -eq 0) { Return }
  $Message -f $Files.Count, $InstallersDir
  $Files | ForEach-Object {
    " - Removing File '$_'"
    Remove-Item -Path $_
  }
}

Function Remove-App-Installers() {
  If ($SkipApps) { Return }
  $Message = "Removing {0} PortableApps installers from '{1}'"
  Remove-Installers -Filter "*Portable_*.paf.exe" -Message $Message
}

Function Remove-Infra-Installers() {
  If ($SkipInfra) { Return }
  $Message = "Removing {0} build infrastructure installers from '{1}'"
  Remove-Installers -Filter "PortableApps.com*.paf.exe" -Message $Message
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
Remove-App-Installers
Remove-Infra-Installers
