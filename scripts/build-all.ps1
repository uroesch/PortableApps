#!/usr/bin/env pwsh

# -----------------------------------------------------------------------------
# Setup
# -----------------------------------------------------------------------------
# -----------------------------------------------------------------------------
# Globals
# -----------------------------------------------------------------------------
$BaseDir      = Resolve-Path -Path "$PSScriptRoot/.."
$UpdateScript = [IO.Path]::Combine('Other', 'Update', 'Update.ps1')

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
Function List-Modules() {
  Get-ChildItem `
    -Path $BaseDir `
    -Directory `
    -Filter '*Portable'
}

# -----------------------------------------------------------------------------

Function Find-Powershell-Path() {
  If (Get-Command pwsh 2>&1 | Out-Null) { $PSName = 'pwsh' }
  Else { $PSName = 'powershell' } 
  (Get-Command $PSName).Path
}

# -----------------------------------------------------------------------------
Function Build-Package() {
  Param(
    [Object] $Module
  )
  $PSPath = Find-Powershell-Path
  $Script = Join-Path $Module.FullName $UpdateScript
  If (!(Test-Path $Script)) { Return } 
  ""
  "-" * $Host.UI.RawUI.WindowSize.Width
  "Building $($Module.Name)"
  "-" * $Host.UI.RawUI.WindowSize.Width
  & $PSPath -ExecutionPolicy ByPass -File $Script
}

# -----------------------------------------------------------------------------

Function Build-All-Packages() {
  List-Modules | Foreach-Object {
    Build-Package -Module $_
  }
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
Build-All-Packages
