param([Parameter(Mandatory=$true)][string]$Godot,[string]$FromSuite='')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$godotPath = (Resolve-Path -LiteralPath $Godot).Path
$outputPath = Join-Path $projectRoot 'test-output'
New-Item -ItemType Directory -Force -Path $outputPath | Out-Null
[IO.File]::WriteAllText((Join-Path $outputPath '.gdignore'), '')
$suites = @(
    @{ Name='audio'; Script='tests/test_audio.gd'; Args=@() },
    @{ Name='simulation'; Script='tests/test_simulation.gd'; Args=@() },
    @{ Name='simulation-frames'; Script='tests/test_simulation_frames.gd'; Args=@() },
    @{ Name='population-performance'; Script='tests/test_population_performance.gd'; Args=@() },
    @{ Name='powers'; Script='tests/test_powers.gd'; Args=@('--long') },
    @{ Name='sandbox-stories'; Script='tests/test_sandbox_stories.gd'; Args=@() },
    @{ Name='casting-flow'; Script='tests/test_casting_flow.gd'; Args=@() },
    @{ Name='interface'; Script='tests/test_ui.gd'; Args=@() },
    @{ Name='responsive-interface'; Script='tests/test_mobile_ui.gd'; Args=@() },
    @{ Name='android-time'; Script='tests/test_android_time.gd'; Args=@() },
    @{ Name='resident-navigation'; Script='tests/test_resident_navigation.gd'; Args=@() },
    @{ Name='living-world'; Script='tests/test_living_world.gd'; Args=@() },
    @{ Name='person-feedback'; Script='tests/test_person_feedback.gd'; Args=@() },
    @{ Name='hud'; Script='tests/test_hud.gd'; Args=@() },
    @{ Name='citizens'; Script='tests/test_citizens.gd'; Args=@() },
    @{ Name='living-society'; Script='tests/test_life_society.gd'; Args=@() },
    @{ Name='society-ui'; Script='tests/test_society_ui.gd'; Args=@() },
    @{ Name='save-compression'; Script='tests/test_save_compression.gd'; Args=@() },
    @{ Name='personal-powers'; Script='tests/test_person_powers.gd'; Args=@() },
    @{ Name='touch'; Script='tests/test_touch_people.gd'; Args=@() },
    @{ Name='pictured-people'; Script='tests/test_pictured_people.gd'; Args=@() },
    @{ Name='renderer'; Script='tests/test_renderer.gd'; Args=@() },
    @{ Name='street-detail'; Script='tests/test_detail.gd'; Args=@() },
    @{ Name='architecture'; Script='tests/test_settlement_painter.gd'; Args=@() },
    @{ Name='people'; Script='tests/test_people_detail.gd'; Args=@() },
    @{ Name='calamities'; Script='tests/test_calamity_painter.gd'; Args=@() },
    @{ Name='resources'; Script='tests/test_balance.gd'; Args=@('--resources') }

)
$started=($FromSuite -eq '')
if ($FromSuite -ne '' -and $FromSuite -notin $suites.Name) { throw ('Unknown starting suite: '+$FromSuite) }
foreach ($suite in $suites) {
    if ($suite.Name -eq $FromSuite) { $started=$true }
    if (-not $started) { continue }
    $engineArguments = @('--headless','--path',$projectRoot,'--script',$suite.Script)
    if ($suite.Args.Count -gt 0) { $engineArguments += '--'; $engineArguments += $suite.Args }
    $result = & $godotPath @engineArguments 2>&1 | Tee-Object -FilePath (Join-Path $outputPath ($suite.Name + '.log'))
    $exitCode = $LASTEXITCODE
    $result | Set-Content -LiteralPath (Join-Path $outputPath ($suite.Name + '.log'))
    $result | Write-Output
    if ($exitCode -ne 0 -or ($result -join "`n") -match 'SCRIPT ERROR:|ERROR:') {
        throw ('Validation failed: ' + $suite.Name)
    }
}
Write-Output $(if ($FromSuite -eq '') { 'All acceptance suites passed.' } else { 'All selected acceptance suites passed.' })
