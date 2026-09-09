param(
    [Parameter(Mandatory=$true)][string]$Godot,
    [Parameter(Mandatory=$true)][string]$WebTemplate
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$enginePath = (Resolve-Path -LiteralPath $Godot).Path
$templatePath = (Resolve-Path -LiteralPath $WebTemplate).Path.Replace('\','/')
$presetPath = Join-Path $projectRoot 'export_presets.cfg'
$original = [IO.File]::ReadAllText($presetPath)
$outputPath = Join-Path $projectRoot 'build\web'
New-Item -ItemType Directory -Force -Path $outputPath | Out-Null
try {
    $parts = $original -split '(?=\[preset\.1\.options\])', 2
    $parts[1] = $parts[1] -replace 'custom_template/release="[^"]*"', ('custom_template/release="'+$templatePath+'"')
    [IO.File]::WriteAllText($presetPath,($parts -join ''))
    & $enginePath --headless --path $projectRoot --editor --import --quit
    if ($LASTEXITCODE -ne 0) { throw 'Project import failed.' }
    & $enginePath --headless --path $projectRoot --export-release 'Web Mobile' (Join-Path $outputPath 'index.html')
    if ($LASTEXITCODE -ne 0) { throw 'Web export failed.' }
    Write-Output ('Built phone browser files: '+$outputPath)
} finally {
    [IO.File]::WriteAllText($presetPath,$original)
}
