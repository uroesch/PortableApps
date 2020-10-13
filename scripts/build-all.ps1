#!/usr/bin/env pwsh

# -----------------------------------------------------------------------------
# Setup
# -----------------------------------------------------------------------------
# -----------------------------------------------------------------------------
# Globals
# -----------------------------------------------------------------------------
$BaseDir      = Resolve-Path -Path "$PSScriptRoot/.."
$UpdateScript = Join-Path 'Other' 'Update' 'Update.ps1'


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

Function Build-Package() {
  Param(
    [Object] $Module
  )
  $Script = Join-Path $Module.FullName $UpdateScript
  If (!(Test-Path $Script)) { Return } 
  ""
  "-" * $Host.UI.RawUI.WindowSize.Width
  "Building $($Module.Name)"
  "-" * $Host.UI.RawUI.WindowSize.Width
  Invoke-Expression $Script
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
