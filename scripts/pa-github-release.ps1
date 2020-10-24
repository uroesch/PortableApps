#!/usr/bin/env pwsh

<#

.SYNOPSIS
  Create a github release for a PortableApps based on the git tag.

.DESCRIPTION
  A wrapper script to automate PortableApps releases to to github.
  While it can be ran as a standalone script is it generally meant
  to be executed within a series of commands.

.PARAMETER Tag
  Git tag of the release to publish.

.PARAMETER Message
  Message to use for the github release.
#>

Param(
 [String] $Tag,
 [String] $Message
)

# -----------------------------------------------------------------------------
# Globals
# -----------------------------------------------------------------------------
$Version        = "0.0.1-alpha"
$Debug          = $True
$InstallerDir   = Resolve-Path "$PSScriptRoot/.."
$PackageInfo    = @{}
$DefaultMessage = "{0}`n`nUpstream release {0}"
$MessageFile    = (New-TemporaryFile).Fullname
$SumsFile       = (New-TemporaryFile).Fullname

# -----------------------------------------------------------------------------
# setup
# -----------------------------------------------------------------------------
Trap { cleanup }

# -----------------------------------------------------------------------------
# Filters
# -----------------------------------------------------------------------------
Filter Format-Release() {
  If ($_[0] -NotMatch "[0-9]") { $_ = $_.Remove(0,1) }
  $_.Replace('+', 'Plus') # For WinMergeJP
}

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------

Function Initialize() {
  $ReleaseTag  = Fetch-Git-Tag
  $Version     = $ReleaseTag | Format-Release
  $Package = @{
    'Name'       = (Get-Item (Get-Location)).Name
    'ReleaseTag' = $ReleaseTag
    'Release'    = $ReleaseTag.Remove(0,1)
    'Version'    = $Version
    'Path'       = (Find-Installer -Name $Name -Version $Version).Fullname
  }
  $Package
}

# -----------------------------------------------------------------------------

Function Fetch-Git-Tag() {
  Try { & git describe --abbrev=0 --tags }
  Catch { "" }
}

# -----------------------------------------------------------------------------

Function Create-Release-Text() {
  Param(
    [Object] $Package
  )
  $FormatedMessage = ''
  If ($Message) {
    # prepend message with tag if not on first line
    If ($Message -NotMatch "^$(Package.ReleaseTag)") {
      "{0}`n" -f $Package.ReleaseTag
    }
    $Message
  }
  Else {
    "$DefaultMessage" -f $ReleaseTag
  }
}

# -----------------------------------------------------------------------------

Function Find-Installer() {
  Param(
    [String] $Name,
    [String] $Version = '.*'
  )
  $Search  = "{0}_{1}.paf.exe" -f $Name, $Version
  Get-ChildItem -Path $InstallerDir -File | Where-Object {
    $_.Name -match $Search
  }
}

# -----------------------------------------------------------------------------

Function Create-Checksums() {
  Param(
    [String] $Path
  )
  Get-FileHash -Path $Path -Algorithm SHA256
}

# -----------------------------------------------------------------------------

Function Assemble-Release-Message {
  Param(
    [Object] $Package
  )
  $CellWidth   = 64
  $Line        = "-" * $CellWidth
  $TableFormat = "| {0,-$CellWidth} | {1,-$CellWidth} |"
  Create-Release-Text -Package $Package
  ""
  $TableFormat -f "Filename", "SHA-256"
  $TableFormat -f $Line, $Line
  Create-Checksums -Path $Package.Path | ForEach-Object {
    $TableFormat -f (Get-Item $_.Path).Name, $_.Hash
  }
}

# -----------------------------------------------------------------------------

Function Create-Release-Message() {
  Param(
    [Object] $Package
  )
  Assemble-Release-Message -Package $Package | Set-Content -Path $MessageFile
}

# -----------------------------------------------------------------------------

Function Create-Checksums-File() {
  Param(
    [Object] $Package
  )

  $Format = "{0} {1}"
  Create-Checksums -Path $Package.Path | Foreach-Object {
    $Format -f $_.Hash, (Get-Item $_.Path).Name
  } | Set-Content -Path $SumsFile
}

# -----------------------------------------------------------------------------

Function Create-Release {
  $Package = Initialize
  $Options = @()
  Switch -Regex ($Package.Version) {
   "beta|alpha|rc" { $Options += "-p" }
  }
  Create-Checksums-File -Package $Package
  Create-Release-Message -Package $Package
  & git hub release create $Options `
    -a $Package.Path `
    -a "$SumsFile" `
    -F "$MessageFile" `
    $Package.ReleaseTag
}

# -----------------------------------------------------------------------------

Function Cleanup() {
  $Files = @( $MessageFile, $SumsFile )
  ForEach ($File in $Files) {
    If (Test-Path $File) {
      Remove-Item -Force $File
    }
  }
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
Create-Release
Cleanup
