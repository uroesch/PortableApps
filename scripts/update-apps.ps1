$PADir = 'PortableApps'
$ScriptBaseUrl = 'https://raw.githubusercontent.com/uroesch/PortableApps/master/CommonFiles/Other/Update'
$Scripts = @(
  'PA-Upgrade.ps1',
  'PortableAppsCommon.psm1'
)
$Apps = @(
  'ApacheDirectoryStudio',
  'ApacheJMeter',
  'CmderMini',
  'Cmder',
  'DBeaver',
  'DrawIO',
  'Git',
  'KeyStoreExplorer',
  'Joplin',
  'LdapAdmin',
  'Mattermost',
  'PlantUML',
  'PlinkProxy',
  'ShareX',
  'WinMergeJP'
)

$Apps | Sort | ForEach-Object {
  $Name = $_ + 'Portable'
  $UpdateDir = [System.IO.Path]::Combine($PADir, $Name, 'Other', 'Update')
  If (!(Test-Path $UpdateDir)) {
    New-Item -Path $UpdateDir -ItemType Directory
  }
  $Scripts | ForEach-Object {
    $ScriptPath = Join-Path $UpdateDir $_
    Invoke-WebRequest -Uri "$ScriptBaseUrl/$_" -OutFile $ScriptPath
  }
  & powershell -ExecutionPolicy ByPass -File (Join-Path $UpdateDir 'PA-Upgrade.ps1')
}