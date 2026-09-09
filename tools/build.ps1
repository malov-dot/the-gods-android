param(
    [Parameter(Mandatory=$true)][string]$Godot,
    [Parameter(Mandatory=$true)][string]$ReleaseTemplate
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$godotPath = (Resolve-Path -LiteralPath $Godot).Path
$templatePath = (Resolve-Path -LiteralPath $ReleaseTemplate).Path.Replace('\','/')
$presetPath = Join-Path $projectRoot 'export_presets.cfg'
$originalPreset = [IO.File]::ReadAllText($presetPath)
$buildPath = Join-Path $projectRoot 'build'
New-Item -ItemType Directory -Force -Path $buildPath | Out-Null
[IO.File]::WriteAllText((Join-Path $buildPath '.gdignore'), '')
try {
    $parts = $originalPreset -split '(?=\[preset\.1\])', 2
    $parts[0] = [regex]::Replace($parts[0], 'custom_template/release="[^"]*"', ('custom_template/release="' + $templatePath + '"'))
    $updatedPreset = $parts -join ''
    [IO.File]::WriteAllText($presetPath, $updatedPreset)
    & $godotPath --headless --path $projectRoot --editor --import --quit
    if ($LASTEXITCODE -ne 0) { throw 'Godot project import failed.' }
    & $godotPath --headless --path $projectRoot --export-release 'Windows Desktop' (Join-Path $buildPath 'The Gods.exe')
    if ($LASTEXITCODE -ne 0) { throw 'Windows export failed.' }
    Copy-Item -LiteralPath (Join-Path $projectRoot 'README.md') -Destination $buildPath -Force
    Copy-Item -LiteralPath (Join-Path $projectRoot 'GODOT_LICENSE.txt') -Destination $buildPath -Force
    Copy-Item -LiteralPath (Join-Path $projectRoot 'GODOT_COPYRIGHT.txt') -Destination $buildPath -Force
    Copy-Item -Path (Join-Path $projectRoot 'assets\fonts\*-OFL.txt') -Destination $buildPath -Force
    if (Test-Path -LiteralPath (Join-Path $projectRoot 'RELEASE_NOTES.md')) {
        Copy-Item -LiteralPath (Join-Path $projectRoot 'RELEASE_NOTES.md') -Destination $buildPath -Force
    }
    Write-Output ('Built: ' + (Join-Path $buildPath 'The Gods.exe'))
} finally {
    [IO.File]::WriteAllText($presetPath, $originalPreset)
}
