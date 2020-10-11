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

.PARAMETER SkipInfra
  Skip the Infra submodules 
  Infra submodules starting with 'PortableApps.com'.
#>

Param(
  [Switch] $SkipApps,
  [Switch] $SkipInfra
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

Function Pull-Repository() {
  Param(
    [String] $Ref = 'master'
  )
  # There may be an easier wasy with submodule
  # but I have not yet found it.
  Invoke-Expression "git checkout $Ref"
  Invoke-Expression "git pull --rebase origin $Ref"
  Invoke-Expression 'git branch' | ForEach-Object {
    If ($_ -notmatch "$Ref|master") {
      Invoke-Expression "git branch -d $_"
      Invoke-Expression "git push origin :$_"
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
        $Ref = $GitRefs[$_.Name] || 'master'
        Sync-Repository -Submodule $_.Name -Ref $Ref
      } 
    }
  }
  Catch {
    "Failed to fetch '$RepoName'"
  }
}

# -----------------------------------------------------------------------------

Function Update-Applications() {
  If ($SkipApps) { Return }
  Update-Submodule -Pattern '.*Portable$'
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
Update-Infrastructure
