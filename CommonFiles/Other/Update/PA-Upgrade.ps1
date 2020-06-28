# -----------------------------------------------------------------------------
# Description: Generic Update Script for PortableApps
# Author: Urs Roesch <github@bun.ch>
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Modules
# -----------------------------------------------------------------------------
Using module ".\PortableAppsCommon.psm1"

# -----------------------------------------------------------------------------
# Globals
# -----------------------------------------------------------------------------
$Version    = "0.0.1-alpha"
$Debug      = $True
$SiteUrl    = "https://github.com"
$ReleaseUrl = "$SiteUrl/uroesch/$AppName/releases/"

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
Function Fetch-InstallerLink() { 
  Debug info "Fetching installer download URL"
  $HtmlContent   = Invoke-WebRequest -Uri $ReleaseUrl
  $InstallerLink = $(
    $HtmlContent.Links |
    Where { $_.href -like "*/download/*exe" } |
    Select href -First 1
  ).href
  $InstallerLink = $SiteUrl + $InstallerLink
  Debug info "Got installer URL '$InstallerLink'"
  Return $InstallerLink
}

# -----------------------------------------------------------------------------
Function Download-Release {
  $InstallerLink = Fetch-InstallerLink   
  $InstallerFile = "$AppRoot/../" + ($InstallerLink.split("/"))[-1]

  If (Test-Path $InstallerFile) { 
    Debug info "File '$InstallerFile' is already present; Skip download"  
    Return $InstallerFile
  }

  Debug info "Downloading Installer from '$InstallerLink'"
  Try {
    Invoke-WebRequest `
      -Uri $InstallerLink `
      -OutFile $InstallerFile | Out-Null
  }
  Catch { 
    Debug error "Failed to download '$InstallerLink'"
    Exit 123
  }

  Return $InstallerFile
}

# -----------------------------------------------------------------------------
Function Install-Release() {
  $Installer = Download-Release
  Invoke-Installer -Command $Installer
}

# -----------------------------------------------------------------------------
Function Invoke-Installer() {
  param(
    [string] $Command
  )
  Set-Location "$AppRoot\.."
  $PARoot = (Get-Location)

  Switch (Test-Unix) {
    $True   {
      $Arguments = "$Command $(ConvertTo-WindowsPath $PARoot)"
      $Command   = "wine"
      break
    }
    default {
      $Arguments = ConvertTo-WindowsPath $PARoot
    }
  }

  Debug info "Run PA $Command $Arguments"
  Start-Process $Command -ArgumentList $Arguments -NoNewWindow -Wait
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
Install-Release
