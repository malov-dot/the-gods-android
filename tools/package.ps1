$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$buildPath = Join-Path $projectRoot 'build'
$distPath = Join-Path $projectRoot 'dist'

function Read-TestEvidence {
    param([string]$Root, [string]$Suite)
    $relativeLog = 'test-output/' + $Suite + '.log'
    $logPath = Join-Path $Root $relativeLog
    $logFile = Get-Item -LiteralPath $logPath
    $log = [IO.File]::ReadAllText($logPath)
    $errorPath = Join-Path $Root ('test-output/' + $Suite + '-errors.log')
    $errorLog = if (Test-Path -LiteralPath $errorPath) { [IO.File]::ReadAllText($errorPath) } else { '' }
    $combined = $log + "`n" + $errorLog
    if ($combined -match '(?m)^\s*(SCRIPT ERROR:|ERROR:)') { throw ('Unresolved error in ' + $Suite) }
    $failureMatches = [regex]::Matches($combined, '(?i)(?<![\d.])(\d+)\s+failure(?:s|\(s\))?\b(?!\s*=)|\bfailures\s*=\s*(\d+)')
    foreach ($failure in $failureMatches) {
        $number = if ($failure.Groups[1].Success) { [int]$failure.Groups[1].Value } else { [int]$failure.Groups[2].Value }
        if ($number -ne 0) { throw ('Failed checks in ' + $Suite) }
    }
    $countMatches = [regex]::Matches($log, '(?i)(\d+)\s+(checks|assertions)\b')
    $count = $null
    $countKind = $null
    if ($countMatches.Count -gt 0) {
        $lastCount = $countMatches[$countMatches.Count - 1]
        $count = [int]$lastCount.Groups[1].Value
        $countKind = $lastCount.Groups[2].Value.ToLowerInvariant()
        if ($count -le 0) { throw ('Empty check result in ' + $Suite) }
        if ($failureMatches.Count -eq 0 -and $log -notmatch '(?m)^PASS simulation:') { throw ('Missing completion verdict in ' + $Suite) }
    } elseif ($Suite -eq 'resources' -and $log -match '(?m)^RESOURCES .+failures=0') {
        $countKind = 'resource outcomes'
    } elseif ($Suite -eq 'competitive-starts') {
        $comparisons = [regex]::Matches($log, '(?m)^START scenario=')
        if ($comparisons.Count -ne 12) { throw 'The competitive-start baseline must contain all scenario/kingdom comparisons.' }
        $count = $comparisons.Count
        $countKind = 'comparisons'
    } else {
        throw ('Missing completed check summary in ' + $Suite + '; the test may still be running.')
    }
    $summary = ($log -split "`n" | Where-Object { $_ -match 'PASS simulation:|acceptance|ACCEPTANCE|\d+ checks|\d+ assertions|^RESOURCES |^START scenario=|^HUD .+idle obstruction' } | ForEach-Object { $_.Trim() }) -join ' | '
    if ([string]::IsNullOrWhiteSpace($summary)) { throw ('Missing verification summary for ' + $Suite) }
    $evidence = [ordered]@{
        log = $relativeLog
        log_sha256 = (Get-FileHash -LiteralPath $logPath -Algorithm SHA256).Hash
        completed_at = $logFile.LastWriteTimeUtc.ToString('o')
        checks = $count
        count_kind = $countKind
        failures = 0
        summary = $summary
        warnings = @($combined -split "`n" | Where-Object { $_ -match '^WARNING:' } | ForEach-Object { $_.Trim() })
    }
    if (Test-Path -LiteralPath $errorPath) {
        $evidence['stderr_log'] = 'test-output/' + $Suite + '-errors.log'
        $evidence['stderr_sha256'] = (Get-FileHash -LiteralPath $errorPath -Algorithm SHA256).Hash
    }
    return $evidence
}

function Copy-TestLogs {
    param($Evidence, [string]$Root, [string]$Destination)
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    foreach ($suite in $Evidence.Keys) {
        foreach ($field in @('log', 'stderr_log')) {
            if ($Evidence[$suite].Contains($field)) {
                Copy-Item -LiteralPath (Join-Path $Root $Evidence[$suite][$field]) -Destination $Destination -Force
            }
        }
    }
}

# Package only completed checks from this living-society release.
$current = [ordered]@{}
$releaseStartedAt = (Get-Item -LiteralPath (Join-Path $projectRoot 'LIVING_SOCIETY.md')).LastWriteTimeUtc
foreach ($suite in @('audio', 'simulation', 'simulation-frames', 'powers', 'interface', 'responsive-interface', 'android-time', 'hud', 'citizens', 'living-society', 'society-ui', 'save-compression', 'personal-powers', 'touch', 'pictured-people', 'renderer', 'street-detail', 'architecture', 'people', 'calamities', 'resources', 'competitive-starts', 'android-lifecycle', 'android-updates', 'android-public-transport')) {
    $current[$suite] = Read-TestEvidence -Root $projectRoot -Suite $suite
    if ([datetime]::Parse($current[$suite].completed_at).ToUniversalTime() -lt $releaseStartedAt) { throw ('Rerun the current-release regression before packaging: ' + $suite) }
}

$sourceHashes = [ordered]@{}
Get-ChildItem -LiteralPath (Join-Path $projectRoot 'scripts') -Filter '*.gd' | Sort-Object Name | ForEach-Object {
    $sourceHashes[$_.Name] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
}
$configHashes = [ordered]@{}
foreach ($path in @('project.godot', 'export_presets.cfg', 'scenes/main.tscn', 'HUD_DESIGN.md', 'LIVING_SOCIETY.md', 'README.md', 'RELEASE_NOTES.md', 'tools/package.ps1')) {
    $configHashes[$path] = (Get-FileHash -LiteralPath (Join-Path $projectRoot $path) -Algorithm SHA256).Hash
}
$testHashes = [ordered]@{}
Get-ChildItem -LiteralPath (Join-Path $projectRoot 'tests') -Filter '*.gd' | Sort-Object Name | ForEach-Object {
    $testHashes[$_.Name] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
}

$renderFiles = @('main.gd', 'world_view.gd', 'interface_shell.gd', 'hud_powers.gd', 'hud_minimap.gd', 'interface_art.gd', 'community_ui.gd')
$renderUpdatedAt = ($renderFiles | ForEach-Object { (Get-Item -LiteralPath (Join-Path $projectRoot ('scripts/' + $_))).LastWriteTimeUtc } | Sort-Object -Descending | Select-Object -First 1)
$captureSources = [ordered]@{
    'Phone Preview.png' = 'test-output/society-844x390-society.png'
    'Person Profile.png' = 'test-output/society-390x844-profile.png'
    'Time Controls.png' = 'test-output/android-time-fold-cover.png'
}
$portraitSource = 'test-output/society-390x844-family.png'
if ((Test-Path -LiteralPath (Join-Path $projectRoot $portraitSource)) -and (Get-Item -LiteralPath (Join-Path $projectRoot $portraitSource)).LastWriteTimeUtc -ge $renderUpdatedAt) { $captureSources['Portrait Preview.png'] = $portraitSource }
foreach ($name in $captureSources.Keys) {
    $capture = Get-Item -LiteralPath (Join-Path $projectRoot $captureSources[$name])
    if ($capture.LastWriteTimeUtc -lt $renderUpdatedAt) { throw ('Refresh the final HUD capture before packaging: ' + $captureSources[$name]) }
}
$nativeFile = Get-Item -LiteralPath (Join-Path $buildPath 'The Gods.exe')
$sourceUpdatedAt = (Get-ChildItem -LiteralPath (Join-Path $projectRoot 'scripts') -Filter '*.gd' | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1).LastWriteTimeUtc
if ($nativeFile.LastWriteTimeUtc -lt $sourceUpdatedAt) { throw 'Export the current Windows source before packaging.' }
$nativePreview = Get-Item -LiteralPath (Join-Path $buildPath 'Preview.png')
if ($nativePreview.LastWriteTimeUtc -lt $nativeFile.LastWriteTimeUtc) { throw 'Preview.png must be captured from the newly exported Windows executable before packaging.' }
$webPack = Get-Item -LiteralPath (Join-Path $buildPath 'web/index.pck')
if ($webPack.LastWriteTimeUtc -lt $sourceUpdatedAt) { throw 'Export the current browser source before packaging.' }

New-Item -ItemType Directory -Force -Path $distPath | Out-Null
$documentation = @('README.md', 'RELEASE_NOTES.md', 'ANDROID.md', 'HUD_DESIGN.md', 'LIVING_SOCIETY.md', 'GODOT_LICENSE.txt', 'GODOT_COPYRIGHT.txt')
foreach ($name in $documentation) { Copy-Item -LiteralPath (Join-Path $projectRoot $name) -Destination $buildPath -Force }
Copy-Item -Path (Join-Path $projectRoot 'assets/fonts/*-OFL.txt') -Destination $buildPath -Force
$previews = [ordered]@{
    'Preview.png' = [ordered]@{ source = 'Windows exported executable'; captured_at = $nativePreview.LastWriteTimeUtc.ToString('o'); sha256 = (Get-FileHash -LiteralPath $nativePreview.FullName -Algorithm SHA256).Hash }
}
foreach ($name in $captureSources.Keys) {
    $source = Join-Path $projectRoot $captureSources[$name]
    Copy-Item -LiteralPath $source -Destination (Join-Path $buildPath $name) -Force
    $previews[$name] = [ordered]@{ source = $captureSources[$name]; captured_at = (Get-Item -LiteralPath $source).LastWriteTimeUtc.ToString('o'); sha256 = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash }
}
$verificationName = 'verification-1.5.0'
$verificationPath = Join-Path $buildPath $verificationName
Copy-TestLogs -Evidence $current -Root $projectRoot -Destination $verificationPath
foreach ($proofName in @('incremental-index-equivalence.json', 'incremental-index-equivalence.log', 'frame-budget-equivalence.json', 'frame-budget-equivalence.log', 'popup-touch-root-cause.log')) {
    Copy-Item -LiteralPath (Join-Path $projectRoot ('test-output/' + $proofName)) -Destination $verificationPath -Force
}
$deviceEvidencePath = Join-Path $projectRoot 'test-output/android-1.5.0-device-validation.json'
$deviceEvidence = if (Test-Path -LiteralPath $deviceEvidencePath) { [IO.File]::ReadAllText($deviceEvidencePath) | ConvertFrom-Json } else { $null }
$info = [ordered]@{
    title = 'The Gods'
    version = '1.5.0'
    engine = 'Godot 4.7.2'
    platforms = @('Windows x86_64', 'Web browser')
    packaged_at = (Get-Date).ToUniversalTime().ToString('o')
    executable_sha256 = (Get-FileHash -LiteralPath $nativeFile.FullName -Algorithm SHA256).Hash
    web_pack_sha256 = (Get-FileHash -LiteralPath $webPack.FullName -Algorithm SHA256).Hash
    verification = [ordered]@{
        current_release = [ordered]@{ release = '1.5.0'; note = 'Completed simulation, power/save endurance, living society, profile, input, renderer and Android fixture checks. Counts are read from individual logs.'; suites = $current }
    }
    graphical_society_checks = $current['society-ui'].checks
    phone_startup_tested_on_candidate = [bool]($deviceEvidence -and $deviceEvidence.passed)
    final_android_package_tested_on_device = [bool]($deviceEvidence -and $deviceEvidence.passed -and $deviceEvidence.version_code -eq 10503)
    phone_evidence = $deviceEvidence
    android_download = 'https://github.com/malov-dot/the-gods-android/releases/latest'
    source_sha256 = $sourceHashes
    test_source_sha256 = $testHashes
    configuration_sha256 = $configHashes
    previews = $previews
}
[IO.File]::WriteAllText((Join-Path $buildPath 'BUILD_INFO.json'), ($info | ConvertTo-Json -Depth 12), (New-Object System.Text.UTF8Encoding($false)))
$commonNames = $documentation + @('inter-OFL.txt', 'cormorantgaramond-OFL.txt', 'BUILD_INFO.json')
$previewNames = @($previews.Keys)
$windowsFiles = @('The Gods.exe') + $commonNames + $previewNames + @($verificationName) | ForEach-Object { Join-Path $buildPath $_ }
Compress-Archive -LiteralPath $windowsFiles -DestinationPath (Join-Path $distPath 'The Gods - Windows.zip') -Force

$browserPath = Join-Path $buildPath 'browser-package'
New-Item -ItemType Directory -Force -Path $browserPath | Out-Null
$browserNames = @()
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $buildPath 'web') -File) {
    Copy-Item -LiteralPath $file.FullName -Destination $browserPath -Force
    $browserNames += $file.Name
}
foreach ($name in $commonNames + $previewNames) {
    Copy-Item -LiteralPath (Join-Path $buildPath $name) -Destination $browserPath -Force
    $browserNames += $name
}
Copy-Item -LiteralPath $verificationPath -Destination $browserPath -Recurse -Force
$browserNames += $verificationName
Copy-Item -LiteralPath (Join-Path $projectRoot 'tools/serve_phone.py') -Destination $browserPath -Force
$browserNames += 'serve_phone.py'
foreach ($name in @('Play on Phone.ps1', 'Stop Phone Server.ps1')) {
    Copy-Item -LiteralPath (Join-Path $projectRoot $name) -Destination $browserPath -Force
    $browserNames += $name
}
$browserFiles = $browserNames | Select-Object -Unique | ForEach-Object { Join-Path $browserPath $_ }
Compress-Archive -LiteralPath $browserFiles -DestinationPath (Join-Path $distPath 'The Gods - Browser.zip') -Force
Get-ChildItem -LiteralPath $distPath -Filter '*.zip' | Select-Object Name, Length
