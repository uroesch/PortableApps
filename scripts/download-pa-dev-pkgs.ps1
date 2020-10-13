#!/usr/bin/env powershell

# -----------------------------------------------------------------------------
# Globals
# -----------------------------------------------------------------------------
$PARoot    = Resolve-Path -Path "$PSScriptRoot/.."
$Domain    = 'https://portableapps.com'
$UrlBase   = "{0}/apps/development/portableapps.com_{1}"

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
Function Assemble-Url() {
  Param(
    [String] $Name
  )
  $UrlBase -f $Domain, $Name.ToLower()
}

Function Extract-Link() {
  Param(
    [String] $Name,
    [String] $Uri
  )
  Write-Host "Downloading '$Uri'"
  Try {
    $HTML = Invoke-Webrequest -Uri $Uri
    $Base = ($HTML.Links | Where-Object { $_.href -Imatch "$Name.*.exe$" }).href
    Return '{0}{1}' -f $Domain, $Base
  }
  Catch {
    Write-Host "Failed to Download '$Uri'"
  }
}

Function Download-Binary() {
  Param(
    [String] $Name
  )
  $Url         = Assemble-Url -Name $Name
  $JumpUrl     = Extract-Link -Name $Name -Uri $Url
  $DownloadUrl = Extract-Link -name $Name -Uri $JumpUrl
  $OutFile     = ($DownloadUrl.Split('/').Split('='))[-1]
  $OUtFile     = Join-Path $PARoot $OutFile
  If (Test-Path $OutFile) { 
    Write-Host "File '${OutFile}' already exists not downloading"
    Return
  }
  Try {
    Write-Host "Downloading '$DownloadUrl'"
    Invoke-Webrequest -Uri $DownloadUrl -OutFile $OutFile
  }
  Catch {
    Write-Host "Failed to Download '$DownloadUrl'"
  }
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
Download-Binary -Name installer
Download-Binary -Name Launcher
