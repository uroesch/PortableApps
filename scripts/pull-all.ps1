#!/usr/bin/env pwsh

<#
.SYNOPSIS
  Update git submodules for PortableApps

.DESCRIPTION
  A simple script to loop through all git submodules definded
  by pattern. There are two Modes App and Infra. App updates
  the Application portion while Infra does take care of the
  submodules requires for the build.

.PARAMETER SkipApps
  Skip update of the App submodules.
  Apps submodules are ending in 'Portable'.

.PARAMETER SkipTemplates
  Skip the template submodules.
  Template submodules ending with 'Template'.

.PARAMETER SkipInfra
  Skip the Infra submodules
  Infra submodules starting with 'PortableApps.com'.

.PARAMETER Debug
  Switch on Debugging
#>

Param(
  [Switch] $SkipApps,
  [Switch] $SkipTemplates,
  [Switch] $SkipInfra,
  [Switch] $Debug
)

# -----------------------------------------------------------------------------
# Globals
# -----------------------------------------------------------------------------
$BaseDir = Resolve-Path -Path "$PSScriptRoot/.."
$GitRefs = @{
  'PortableApps.comLauncher' = 'patched'
}

# -----------------------------------------------------------------------------
# Function
# -----------------------------------------------------------------------------
Function Logger() {
  param(
    [string] $Severity,
    [string] $Message
  )
  $Color = 'White'
  $Severity = $Severity.ToUpper()
  Switch ($Severity) {
    'INFO'  { $Color = 'Green';      break }
    'WARN'  { $Color = 'Yellow';     break }
    'ERROR' { $Color = 'DarkYellow'; break }
    'FATAL' { $Color = 'Red';        break }
    default { $Color = 'White';      break }
  }
  If (!($Debug)) { Return }
  Write-Host "$(Get-Date -Format u) - " -NoNewline
  Write-Host $Severity": " -NoNewline -ForegroundColor $Color
  Write-Host $Message
}

# -----------------------------------------------------------------------------
Function Run() {
  Param(
    [String] $Command
  )
  Logger info "Running command -> '$Command'"
  Invoke-Expression $Command
}

# -----------------------------------------------------------------------------
Function Pull-Repository() {
  Param(
    [String] $Ref = 'master'
  )
  # There may be an easier wasy with submodule
  # but I have not yet found it.
  Run "git checkout $Ref"
  Run "git pull --rebase origin $Ref"
  Run 'git branch' | ForEach-Object {
    If ($_ -notmatch "$Ref|master") {
      Run "git branch -d $_"
      Run "git push origin :$_"
    }
  }
}

# -----------------------------------------------------------------------------
Function Sync-Repository() {
  Param(
    [String] $Submodule,
    [String] $Ref = 'master'
  )
  Try {
    Push-Location $BaseDir
    Push-Location $Submodule
    Print-Header -Name $Submodule
    Pull-Repository -Ref $Ref
    Pop-Location
    Pop-Location
  }
  Catch {
    $Error[0].Exception.Message
    "Failed to sync '$Submodule'"
    Exit 123
  }
}

# -----------------------------------------------------------------------------
Function Print-Header() {
   Param(
     [String] $Name
   )
   ""
   "-" * $Host.UI.RawUI.WindowSize.Width
   $Name
   "-" * $Host.UI.RawUI.WindowSize.Width
}

# -----------------------------------------------------------------------------
Function Update-Submodule() {
  Param(
    [String] $Pattern
  )
  Try {
    Get-ChildItem $BaseDir -Directory | ForEach-Object -Process {
      If ($_.Name -match $Pattern) {
        $Ref = Switch ($GitRefs[$_.Name]) {
          ''      { 'master' }
          Default { $_ }
        }
        Sync-Repository -Submodule $_.Name -Ref $Ref
      }
    }
  }
  Catch {
    "Failed to sync '$RepoName'"
    Exit 124
  }
}

# -----------------------------------------------------------------------------
Function Update-Applications() {
  If ($SkipApps) { Return }
  Update-Submodule -Pattern '.*Portable$'
}

# -----------------------------------------------------------------------------
Function Update-Templates() {
  If ($SkipTemplates) { Return }
  Update-Submodule -Pattern '.*Template$'
}

# -----------------------------------------------------------------------------
Function Update-Infrastructure() {
  If ($SkipInfra) { Return }
  Update-Submodule -Pattern '^PortableApps.com.*'
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
Update-Applications
Update-Templates
Update-Infrastructure
