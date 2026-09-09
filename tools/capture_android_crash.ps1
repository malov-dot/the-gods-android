param(
    [string]$AdbPath = '',
    [string]$Serial = '',
    [switch]$Launch,
    [ValidateRange(0,60)][int]$RecordSeconds = 0
)
$ErrorActionPreference = 'Stop'
$package = 'games.thegods.sandbox'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $AdbPath) {
    $choices = @(
        (Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'),
        (Join-Path $env:USERPROFILE '.cache\the-gods-tools\android\sdk\platform-tools\adb.exe')
    )
    $AdbPath = $choices | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}
if (-not $AdbPath -or -not (Test-Path -LiteralPath $AdbPath)) { throw 'Android platform-tools adb.exe was not found. Pass -AdbPath.' }

function Invoke-Adb {
    param([string[]]$Arguments)
    $result = & $AdbPath @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) { throw ('ADB failed: '+($result -join "`n")) }
    return ($result -join "`n")
}
$devices = Invoke-Adb @('devices')
if (-not $Serial) {
    $ready = @([regex]::Matches($devices,'(?m)^([^\s]+)\s+device\s*$') | ForEach-Object { $_.Groups[1].Value })
    if ($ready.Count -ne 1) {
        throw 'Connect one Android device with USB debugging enabled and approve this PC on the phone. If multiple devices are connected, pass -Serial.'
    }
    $Serial = $ready[0]
}
$appEntry = Invoke-Adb @('-s',$Serial,'shell','pm','list','packages','-U',$package)
$uidMatch = [regex]::Match($appEntry,('(?m)^package:'+ [regex]::Escape($package) +'\s+uid:(\d+)'))
if (-not $uidMatch.Success) { throw 'The Gods is not installed for the active Android user.' }
$appUid = $uidMatch.Groups[1].Value
$outputDirectory = Join-Path $projectRoot ('test-output\android-device-crash-'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
$utf8 = New-Object System.Text.UTF8Encoding($false)
function Write-Evidence {
    param([string]$Name,[string]$Value)
    [IO.File]::WriteAllText((Join-Path $outputDirectory $Name),$Value,$utf8)
}
$device = [ordered]@{captured_utc=[DateTime]::UtcNow.ToString('o');package=$package}
foreach ($property in @('ro.product.manufacturer','ro.product.model','ro.build.version.release','ro.build.version.sdk','ro.product.cpu.abilist')) {
    $device[$property] = (Invoke-Adb @('-s',$Serial,'shell','getprop',$property)).Trim()
}
$device['page_size'] = (Invoke-Adb @('-s',$Serial,'shell','getconf','PAGE_SIZE')).Trim()
$device['screen_size'] = (Invoke-Adb @('-s',$Serial,'shell','wm','size')).Trim()
$device['screen_density'] = (Invoke-Adb @('-s',$Serial,'shell','wm','density')).Trim()
Write-Evidence 'device.json' ($device | ConvertTo-Json)
$packageState = Invoke-Adb @('-s',$Serial,'shell','dumpsys','package',$package)
Write-Evidence 'app-version.txt' (($packageState -split "`n" | Where-Object { $_ -match '^\s*(versionCode=|versionName=|primaryCpuAbi=|secondaryCpuAbi=)' }) -join "`n")
if ($Launch) {
    Write-Evidence 'launch.txt' (Invoke-Adb @('-s',$Serial,'shell','am','start','-W','-n','games.thegods.sandbox/com.godot.game.GodotAppLauncher'))
}
if ($RecordSeconds -gt 0) { Start-Sleep -Seconds $RecordSeconds }
# App UID keeps unrelated applications out of the saved log. Do not clear logs
# or app storage: earlier failures and the user's saved worlds must be retained.
Write-Evidence 'app-logcat.txt' (Invoke-Adb @('-s',$Serial,'logcat','-d','-t','4000','-v','threadtime',"--uid=$appUid"))
Write-Evidence 'exit-info.txt' (Invoke-Adb @('-s',$Serial,'shell','dumpsys','activity','exit-info',$package))
# Native tombstones are written by Android's crash dumper, not the app UID.
# Keep only writer PIDs whose crash entries explicitly identify this package.
$crashLines = (Invoke-Adb @('-s',$Serial,'logcat','-b','crash','-d','-t','2000','-v','threadtime')) -split "`n"
$crashWriters = @{}
foreach ($line in $crashLines) {
    if ($line.Contains($package) -and $line -match '^\d\d-\d\d\s+[\d:.]+\s+(\d+)\s+\d+\s+') { $crashWriters[$Matches[1]] = $true }
}
$matchingCrash = $crashLines | Where-Object {
    $_ -match '^\d\d-\d\d\s+[\d:.]+\s+(\d+)\s+\d+\s+' -and $crashWriters.ContainsKey($Matches[1])
}
Write-Evidence 'app-crash.txt' ($matchingCrash -join "`n")
Write-Output ('Saved game-specific crash evidence: '+$outputDirectory)
