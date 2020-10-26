#!/usr/bin/env pwsh

<#

#>

Param(
  [Switch] $Apps,
  [Switch] $Infra
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
    [String] $Filter
  )
  Get-ChildItem -Path $InstallersDir -File -Filter $Filter | ForEach-Object {
    " - Removing File '$_'"
    Remove-Item -Path $_
  }
}

Function Remove-App-Installers() {
  If (!($Apps)) { Return }
  "Removing PortableApps installers from '$InstallersDir'"
  Remove-Installers -Filter "*Portable_*.paf.exe"
}

Function Remove-Infra-Installers() {
  If (!($Infra)) { Return }
  "Removing build infrastructure installers from '$InstallersDir'"
  Remove-Installers -Filter "PortableApps.com*.paf.exe"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
Remove-App-Installers
Remove-Infra-Installers

