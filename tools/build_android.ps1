param(
    [string]$Godot = (Join-Path $env:USERPROFILE '.cache\the-gods-tools\4.7.2\Godot_v4.7.2-stable_win64_console.exe'),
    [string]$TemplateDirectory = (Join-Path $env:USERPROFILE '.cache\the-gods-tools\4.7.2'),
    [string]$AndroidSdk = (Join-Path $env:USERPROFILE '.cache\the-gods-tools\android\sdk'),
    [string]$JavaSdk = '',
    [string]$SigningDirectory = (Join-Path $env:USERPROFILE '.codex\the-gods\android-signing'),
    [ValidateSet('universal','arm64-v8a','x86_64')][string]$Architecture = 'universal',
    [string]$OutputPath = '',
    [switch]$SkipPluginBuild
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$toolCache = Join-Path $env:USERPROFILE '.cache\the-gods-tools\android'
if (-not $JavaSdk) { $JavaSdk = ([IO.File]::ReadAllText((Join-Path $toolCache 'jdk-path.txt'))).Trim() }
$Godot = (Resolve-Path -LiteralPath $Godot).Path
$JavaSdk = (Resolve-Path -LiteralPath $JavaSdk).Path
$AndroidSdk = (Resolve-Path -LiteralPath $AndroidSdk).Path
$TemplateDirectory = (Resolve-Path -LiteralPath $TemplateDirectory).Path
$config = Get-Content -LiteralPath (Join-Path $projectRoot 'release\android.json') -Raw | ConvertFrom-Json
if ($config.schema -ne 1 -or $config.version_code -lt 1 -or -not $config.package_name) { throw 'Invalid release/android.json.' }
$storePath = Join-Path $SigningDirectory 'the-gods-release.keystore'
$secretPath = Join-Path $SigningDirectory 'password.dpapi'
if (-not (Test-Path -LiteralPath $storePath) -or -not (Test-Path -LiteralPath $secretPath)) {
    throw 'The durable Android release signing key is missing. Restore the original signing directory; never create a replacement for an existing release.'
}
if (-not $OutputPath) { $OutputPath = Join-Path $projectRoot ('build\android\TheGods' + $(if ($Architecture -eq 'universal') { '' } else { '-'+$Architecture }) + '.apk') }
$OutputPath = [IO.Path]::GetFullPath($OutputPath)
$outputDirectory = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
[IO.File]::WriteAllText((Join-Path $outputDirectory '.gdignore'), '')
$envNames = @('JAVA_HOME','ANDROID_HOME','ANDROID_SDK_ROOT','GRADLE_USER_HOME','GRADLE_OPTS','GODOT_ANDROID_KEYSTORE_RELEASE_PATH','GODOT_ANDROID_KEYSTORE_RELEASE_USER','GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD')
$oldEnvironment = @{}
foreach ($name in $envNames) { $oldEnvironment[$name] = [Environment]::GetEnvironmentVariable($name,'Process') }
$passwordPointer = [IntPtr]::Zero
try {
    $env:JAVA_HOME = $JavaSdk
    $env:ANDROID_HOME = $AndroidSdk
    $env:ANDROID_SDK_ROOT = $AndroidSdk
    $env:GRADLE_USER_HOME = Join-Path $toolCache 'gradle'
    # Persistent Gradle daemons inherit the Windows Godot console pipe and can
    # keep its wrapper open after export. A single-use daemon exits with the build.
    $env:GRADLE_OPTS = ($oldEnvironment['GRADLE_OPTS']+' -Dorg.gradle.daemon=false').Trim()
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = $storePath
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = 'thegods'
    $secret = (Get-Content -LiteralPath $secretPath -Raw).Trim() | ConvertTo-SecureString
    $passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret)
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPointer)

    # Keep Android editor settings and build intermediates separate from the user's
    # Godot editor and working project. Every build gets a fresh project snapshot.
    $editorDirectory = Join-Path $toolCache 'exporter\4.7.2'
    $editorData = Join-Path $editorDirectory 'editor_data'
    New-Item -ItemType Directory -Force -Path $editorData | Out-Null
    foreach ($file in @('Godot_v4.7.2-stable_win64_console.exe','Godot_v4.7.2-stable_win64.exe')) {
        $target = Join-Path $editorDirectory $file
        if (-not (Test-Path -LiteralPath $target)) { Copy-Item -LiteralPath (Join-Path (Split-Path -Parent $Godot) $file) -Destination $target }
    }
    [IO.File]::WriteAllText((Join-Path $editorDirectory '_sc_'), '')
    $settings = '[gd_resource type="EditorSettings" format=3]' + "`n`n[resource]`n" +
        'export/android/java_sdk_path="' + $JavaSdk.Replace('\','/') + '"' + "`n" +
        'export/android/android_sdk_path="' + $AndroidSdk.Replace('\','/') + '"' + "`n"
    [IO.File]::WriteAllText((Join-Path $editorData 'editor_settings-4.7.tres'),$settings)
    $installedTemplates = Join-Path $editorData 'export_templates\4.7.2.stable'
    New-Item -ItemType Directory -Force -Path $installedTemplates | Out-Null
    foreach ($file in @('android_source.zip','android_release.apk','android_debug.apk')) {
        $target = Join-Path $installedTemplates $file
        if (-not (Test-Path -LiteralPath $target)) { Copy-Item -LiteralPath (Join-Path $TemplateDirectory $file) -Destination $target }
    }
    $portableGodot = Join-Path $editorDirectory 'Godot_v4.7.2-stable_win64_console.exe'
    $stage = Join-Path $toolCache ('staging\'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8))
    New-Item -ItemType Directory -Force -Path $stage | Out-Null

    if (-not $SkipPluginBuild) {
        $pluginBuilder = Join-Path $PSScriptRoot 'build_android_plugin.ps1'
        if (Test-Path -LiteralPath $pluginBuilder) { & $pluginBuilder -JavaSdk $JavaSdk -AndroidSdk $AndroidSdk -TemplateDirectory $TemplateDirectory }
        elseif (-not (Test-Path -LiteralPath (Join-Path $projectRoot 'addons\the_gods_updater\bin\the-gods-updater-release.aar'))) {
            throw 'The updater AAR is missing. Build android-updater before exporting the APK.'
        }
    }
    foreach ($folder in @('assets','scenes','scripts','addons','release')) {
        $source = Join-Path $projectRoot $folder
        if (Test-Path -LiteralPath $source) { Copy-Item -LiteralPath $source -Destination (Join-Path $stage $folder) -Recurse }
    }
    Copy-Item -LiteralPath (Join-Path $projectRoot 'project.godot') -Destination $stage
    foreach ($notice in @('GODOT_LICENSE.txt','GODOT_COPYRIGHT.txt')) {
        Copy-Item -LiteralPath (Join-Path $projectRoot $notice) -Destination $stage
    }
    $preset = [IO.File]::ReadAllText((Join-Path $projectRoot 'export_presets.cfg'))
    Copy-Item -LiteralPath (Join-Path $projectRoot 'export_presets.cfg') -Destination (Join-Path $stage 'export_presets.cfg')
    # Fingerprint the inputs actually copied for this build, not a later view of
    # the working tree. The publisher compares these with current source before
    # publishing. Android-only version/ABI overrides are separately audited below.
    $sourceHashes = [ordered]@{}
    $trackedFiles = Get-ChildItem -LiteralPath $stage -Recurse -File | Where-Object {
        $_.Extension -in @('.gd','.tscn','.tres','.res','.aar','.png','.svg','.ttf','.otf','.ogg','.wav') -or
        $_.Name -in @('GODOT_LICENSE.txt','GODOT_COPYRIGHT.txt') -or $_.Name -like '*-OFL.txt' -or
        $_.FullName -in @((Join-Path $stage 'project.godot'),(Join-Path $stage 'export_presets.cfg'),(Join-Path $stage 'release\android.json'))
    } | Sort-Object FullName
    foreach ($tracked in $trackedFiles) {
        $relative = $tracked.FullName.Substring($stage.Length+1).Replace('\','/')
        $sourceHashes[$relative] = (Get-FileHash -LiteralPath $tracked.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    $androidMatch = [regex]::Match($preset,'(?ms)^\[preset\.(\d+)\]\s*\r?\nname="Android".*?(?=^\[preset\.\d+\]|\z)')
    if (-not $androidMatch.Success) { throw 'Android export preset is missing.' }
    $section = $androidMatch.Value
    $section = [regex]::Replace($section,'(?m)^version/code=.*$','version/code='+$config.version_code)
    $section = [regex]::Replace($section,'(?m)^version/name=.*$','version/name="'+$config.version_name+'"')
    $section = [regex]::Replace($section,'(?m)^package/unique_name=.*$','package/unique_name="'+$config.package_name+'"')
    $section = [regex]::Replace($section,'(?m)^architectures/arm64-v8a=.*$','architectures/arm64-v8a='+$(if ($Architecture -ne 'x86_64') {'true'} else {'false'}))
    $section = [regex]::Replace($section,'(?m)^architectures/x86_64=.*$','architectures/x86_64='+$(if ($Architecture -ne 'arm64-v8a') {'true'} else {'false'}))
    [IO.File]::WriteAllText((Join-Path $stage 'export_presets.cfg'),$preset.Replace($androidMatch.Value,$section))
    $stageProject = Join-Path $stage 'project.godot'
    $projectText = [IO.File]::ReadAllText($stageProject)
    $projectText = [regex]::Replace($projectText,'(?m)^config/version=.*$','config/version="'+$config.version_name+'"')
    if ($projectText -match '(?m)^textures/vram_compression/import_etc2_astc=') {
        $projectText = [regex]::Replace($projectText,'(?m)^textures/vram_compression/import_etc2_astc=.*$','textures/vram_compression/import_etc2_astc=true')
    } else {
        $projectText = $projectText.Replace('[rendering]',"[rendering]`ntextures/vram_compression/import_etc2_astc=true")
    }
    [IO.File]::WriteAllText($stageProject,$projectText)
    $stagedHashes = [ordered]@{}
    foreach ($relative in $sourceHashes.Keys) {
        $stagedHashes[$relative] = (Get-FileHash -LiteralPath (Join-Path $stage $relative) -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    Write-Output ('Building Android '+$config.version_name+' ('+$config.version_code+'), '+$Architecture)
    & $portableGodot --headless --path $stage --editor --import --quit
    if ($LASTEXITCODE -ne 0) { throw 'Android project import failed.' }
    & $portableGodot --headless --path $stage --install-android-build-template --export-release Android $OutputPath
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $OutputPath)) { throw 'Android APK export failed.' }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $apkArchive = [IO.Compression.ZipFile]::OpenRead($OutputPath)
    try {
        $requiredEntries = @('assets/release/android.json','assets/GODOT_LICENSE.txt','assets/GODOT_COPYRIGHT.txt','assets/scripts/android_bootstrap.gdc','assets/scripts/mobile_display.gdc','assets/scenes/bootstrap.tscn.remap')
        foreach ($fontNotice in (Get-ChildItem -LiteralPath (Join-Path $stage 'assets\fonts') -Filter '*-OFL.txt' -File)) {
            $requiredEntries += 'assets/assets/fonts/'+$fontNotice.Name
        }
        foreach ($requiredEntry in $requiredEntries) {
            if ($null -eq $apkArchive.GetEntry($requiredEntry)) { throw ('APK missing required content or license: '+$requiredEntry) }
        }
        foreach ($entry in $apkArchive.Entries) {
            if ($entry.FullName -match '\.(keystore|dpapi|jks)$' -or $entry.FullName.StartsWith('assets/tools/') -or $entry.FullName.StartsWith('assets/android-updater/')) {
                throw ('APK unexpectedly contains private signing/build input: '+$entry.FullName)
            }
        }
    } finally { $apkArchive.Dispose() }

    $buildTools = Join-Path $AndroidSdk 'build-tools\36.1.0'
    $signature = (& (Join-Path $buildTools 'apksigner.bat') verify --verbose --print-certs $OutputPath 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw 'APK signature verification failed.' }
    $certMatch = [regex]::Match($signature,'Signer #1 certificate SHA-256 digest:\s*([0-9a-fA-F]+)')
    if (-not $certMatch.Success) { throw 'APK signer certificate fingerprint was not reported.' }
    $badging = (& (Join-Path $buildTools 'aapt.exe') dump badging $OutputPath 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw 'APK manifest verification failed.' }
    $packageMatch = [regex]::Match($badging,"package: name='([^']+)' versionCode='([^']+)' versionName='([^']+)'")
    if (-not $packageMatch.Success -or $packageMatch.Groups[1].Value -ne $config.package_name -or [int]$packageMatch.Groups[2].Value -ne $config.version_code -or $packageMatch.Groups[3].Value -ne $config.version_name) { throw 'Exported APK does not match release/android.json.' }
    $abis = @()
    foreach ($abi in @('arm64-v8a','x86_64')) { if ($badging -match [regex]::Escape("'$abi'")) { $abis += $abi } }
    $expectedAbis = if ($Architecture -eq 'universal') { @('arm64-v8a','x86_64') } else { @($Architecture) }
    if (($abis -join ',') -ne ($expectedAbis -join ',')) { throw 'APK native architectures do not match requested build.' }
    foreach ($permission in @('android.permission.INTERNET','android.permission.REQUEST_INSTALL_PACKAGES')) {
        if (-not $badging.Contains($permission)) { throw ('APK missing required permission '+$permission) }
    }
    $manifestXml = (& (Join-Path $buildTools 'aapt.exe') dump xmltree $OutputPath AndroidManifest.xml 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0 -or -not $manifestXml.Contains('org.godotengine.plugin.v2.TheGodsUpdater') -or -not $manifestXml.Contains('games.thegods.updater.UpdateFileProvider')) {
        throw 'The native updater singleton or its FileProvider is missing from the APK manifest.'
    }
    $metadata = [ordered]@{
        schema=1; package_name=$config.package_name; version_code=[int]$config.version_code; version_name=$config.version_name
        architectures=$abis; apk_path=$OutputPath; apk_sha256=(Get-FileHash -LiteralPath $OutputPath -Algorithm SHA256).Hash.ToLowerInvariant()
        apk_size=(Get-Item -LiteralPath $OutputPath).Length; cert_sha256=$certMatch.Groups[1].Value.ToLowerInvariant()
        signing_alias='thegods'; signing_keystore_path=$storePath; built_at_utc=[DateTime]::UtcNow.ToString('o'); staging_path=$stage
        source_hashes=$sourceHashes; staged_hashes=$stagedHashes
    }
    $metadataPath = Join-Path $outputDirectory 'build-metadata.json'
    [IO.File]::WriteAllText($metadataPath,($metadata | ConvertTo-Json -Depth 4))
    [IO.File]::WriteAllText((Join-Path $outputDirectory 'apk-signature.txt'),$signature)
    [IO.File]::WriteAllText((Join-Path $outputDirectory 'apk-manifest.txt'),$badging)
    [IO.File]::WriteAllText((Join-Path $outputDirectory 'apk-manifest-xml.txt'),$manifestXml)
    Write-Output ('Verified APK: '+$OutputPath)
    Write-Output ('Build metadata: '+$metadataPath)
} finally {
    if ($passwordPointer -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer) }
    foreach ($name in $envNames) { [Environment]::SetEnvironmentVariable($name,$oldEnvironment[$name],'Process') }
}
