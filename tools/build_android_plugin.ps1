param(
    [Parameter(Mandatory=$true)][string]$JavaSdk,
    [Parameter(Mandatory=$true)][string]$AndroidSdk,
    [Parameter(Mandatory=$true)][string]$TemplateDirectory
)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
$pluginRoot=Join-Path $projectRoot 'android-updater'
$toolCache=Join-Path $env:USERPROFILE '.cache\the-gods-tools\android'
$godotAar=Join-Path $toolCache 'godot-4.7.2-template-release.aar'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive=[IO.Compression.ZipFile]::OpenRead((Join-Path $TemplateDirectory 'android_source.zip'))
try {
    foreach ($relative in @('gradlew','gradlew.bat','gradle/wrapper/gradle-wrapper.jar','gradle/wrapper/gradle-wrapper.properties')) {
        $destination=Join-Path $pluginRoot $relative
        if (-not (Test-Path -LiteralPath $destination)) {
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
            [IO.Compression.ZipFileExtensions]::ExtractToFile($archive.GetEntry($relative),$destination,$false)
        }
    }
    if (-not (Test-Path -LiteralPath $godotAar)) {
        New-Item -ItemType Directory -Force -Path $toolCache | Out-Null
        [IO.Compression.ZipFileExtensions]::ExtractToFile($archive.GetEntry('libs/release/godot-lib.template_release.aar'),$godotAar,$false)
    }
} finally { $archive.Dispose() }
$names=@('JAVA_HOME','ANDROID_HOME','ANDROID_SDK_ROOT','GRADLE_USER_HOME')
$previous=@{}
foreach ($name in $names) { $previous[$name]=[Environment]::GetEnvironmentVariable($name,'Process') }
Push-Location -LiteralPath $pluginRoot
try {
    $env:JAVA_HOME=(Resolve-Path -LiteralPath $JavaSdk).Path
    $env:ANDROID_HOME=(Resolve-Path -LiteralPath $AndroidSdk).Path
    $env:ANDROID_SDK_ROOT=$env:ANDROID_HOME
    $env:GRADLE_USER_HOME=Join-Path $toolCache 'gradle'
    & (Join-Path $pluginRoot 'gradlew.bat') --no-daemon --console=plain "-PgodotAar=$godotAar" testReleaseUnitTest assembleRelease copyPlugin
    if ($LASTEXITCODE -ne 0) { throw 'Android updater plugin build or tests failed.' }
    $output=Join-Path $projectRoot 'addons\the_gods_updater\bin\the-gods-updater-release.aar'
    if (-not (Test-Path -LiteralPath $output)) { throw 'The updater AAR was not generated.' }
    Write-Output ('Updater AAR: '+$output)
} finally {
    Pop-Location
    foreach ($name in $names) { [Environment]::SetEnvironmentVariable($name,$previous[$name],'Process') }
}
