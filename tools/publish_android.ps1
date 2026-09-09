param(
    [string]$ApkPath = '',
    [string]$MetadataPath = '',
    [string]$ConfigPath = '',
    [string]$NotesPath = '',
    [string]$Repository = 'malov-dot/the-gods-android',
    [string]$AndroidSdk = (Join-Path $env:USERPROFILE '.cache\the-gods-tools\android\sdk'),
    [string]$JavaSdk = '',
    [string]$SigningDirectory = (Join-Path $env:USERPROFILE '.codex\the-gods\android-signing'),
    [switch]$Publish
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$maximumApkBytes = 250MB

function Invoke-Checked {
    param([string]$Command, [string[]]$Arguments, [string]$Label)
    # Windows PowerShell turns native stderr into ErrorRecords even on success.
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $lines = & $Command @Arguments 2>&1
        $commandExit = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previousPreference }
    if ($commandExit -ne 0) { throw "$Label failed (exit $commandExit)." }
    return (($lines | ForEach-Object { $_.ToString() }) -join "`n")
}

function Read-JsonFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Required file is missing: $Path" }
    return ([IO.File]::ReadAllText($Path) | ConvertFrom-Json)
}

function Assert-Integer {
    param($Value, [long]$Minimum, [long]$Maximum, [string]$Label)
    if (($Value -isnot [int] -and $Value -isnot [long] -and $Value -isnot [double] -and $Value -isnot [decimal]) -or
        $Value -lt $Minimum -or $Value -gt $Maximum -or [double]$Value -ne [Math]::Floor([double]$Value)) {
        throw "Invalid $Label."
    }
}

function Assert-Manifest {
    param($Manifest, [string]$Tag)
    Assert-Integer $Manifest.schema 1 1 'manifest schema'
    Assert-Integer $Manifest.version_code 1 2100000000 'Android version code'
    Assert-Integer $Manifest.apk_bytes 1 $maximumApkBytes 'APK length'
    if ($Manifest.channel -cne 'stable' -or $Manifest.package_name -cne $config.package_name -or
        $Manifest.version_name -isnot [string] -or $Manifest.version_name -cnotmatch '^\d+\.\d+\.\d+$' -or
        $Tag -cne ('v'+$Manifest.version_name) -or
        $Manifest.apk_url -cne ($baseUrl+'/releases/download/'+$Tag+'/The-Gods-Android.apk') -or
        $Manifest.apk_sha256 -isnot [string] -or $Manifest.apk_sha256 -cnotmatch '^[a-f0-9]{64}$' -or
        $Manifest.notes -isnot [string] -or $Manifest.notes.Length -gt 4000 -or
        $Manifest.notes -match '[\x00-\x08\x0B\x0C\x0E-\x1F]') { throw "Invalid update manifest for $Tag." }
}

function Get-ApkIdentity {
    param([string]$Path)
    $signature = Invoke-Checked $apksigner @('verify','--verbose','--print-certs',$Path) 'APK signature verification'
    $certificates = [regex]::Matches($signature,'(?m)^Signer #\d+ certificate SHA-256 digest:\s*([a-fA-F0-9]{64})\s*$')
    if ($certificates.Count -ne 1) { throw 'Expected exactly one APK signing certificate.' }
    $badging = Invoke-Checked $aapt @('dump','badging',$Path) 'APK manifest inspection'
    $package = [regex]::Match($badging,"(?m)^package: name='([^']+)' versionCode='([^']+)' versionName='([^']+)'")
    if (-not $package.Success -or $badging -match '(?m)^application-debuggable') { throw 'APK is not an inspectable release build.' }
    $native = [regex]::Match($badging,'(?m)^native-code:\s*(.+)$')
    $architectures = @([regex]::Matches($native.Groups[1].Value,"'([^']+)'") | ForEach-Object { $_.Groups[1].Value })
    return [pscustomobject]@{
        package_name=$package.Groups[1].Value; version_code=[long]$package.Groups[2].Value
        version_name=$package.Groups[3].Value; cert_sha256=$certificates[0].Groups[1].Value.ToLowerInvariant()
        architectures=$architectures
    }
}

function Get-PublishedState {
    # Inspect every published stable manifest, not only a manually chosen latest
    # release. A rollback of GitHub's latest pointer cannot permit code reuse.
    $pages = Invoke-Checked $gh @('api',"repos/$Repository/releases?per_page=100",'--paginate','--slurp') 'Release inventory'
    $releases = @((ConvertFrom-Json $pages) | ForEach-Object { $_ } | Where-Object { -not $_.draft -and -not $_.prerelease })
    $highest = $null
    foreach ($release in $releases) {
        $manifestAssets = @($release.assets | Where-Object { $_.name -ceq 'update.json' })
        if ($manifestAssets.Count -ne 1) { throw "Published stable release $($release.tag_name) lacks one update.json. Resolve its release metadata before publishing." }
        $readDirectory = Join-Path $stage ('remote-'+[Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $readDirectory | Out-Null
        # Retry only this read-only download; a transient asset CDN failure
        # must not cause a repeated release creation or upload.
        for ($attempt=0; $attempt -lt 3; $attempt++) {
            try {
                $null = Invoke-Checked $gh @('release','download',$release.tag_name,'--repo',$Repository,'--pattern','update.json','--dir',$readDirectory,'--clobber') 'Existing manifest download'
                break
            } catch {
                if ($attempt -eq 2) { throw }
                Start-Sleep -Milliseconds 500
            }
        }
        $manifestFile = Join-Path $readDirectory 'update.json'
        if ((Get-Item -LiteralPath $manifestFile).Length -gt 32768) { throw 'Published manifest exceeds its size budget.' }
        $manifest = Read-JsonFile $manifestFile
        Assert-Manifest $manifest $release.tag_name
        if ($null -eq $highest -or $manifest.version_code -gt $highest.manifest.version_code) {
            $highest = [pscustomobject]@{tag=$release.tag_name; manifest=$manifest}
        }
    }
    return $highest
}

function Assert-VersionAdvance {
    param($Previous)
    if ($null -ne $Previous -and $config.version_code -le $Previous.manifest.version_code) {
        throw "Version code $($config.version_code) must exceed published code $($Previous.manifest.version_code). Increment release/android.json and rebuild."
    }
}

function Assert-SourceSnapshot {
    # Match the builder's production-input inventory, including newly added
    # files. Comparing only keys supplied by metadata could miss omitted code.
    if ($null -eq $metadata.source_hashes -or $metadata.source_hashes -isnot [pscustomobject]) { throw 'Build metadata lacks source_hashes. Rebuild before publishing.' }
    $expected = @('project.godot','export_presets.cfg','release/android.json','GODOT_LICENSE.txt','GODOT_COPYRIGHT.txt')
    foreach ($folder in @('assets','scenes','scripts','addons','release')) {
        $directory = Join-Path $projectRoot $folder
        if (Test-Path -LiteralPath $directory -PathType Container) {
            $expected += @(Get-ChildItem -LiteralPath $directory -Recurse -File | Where-Object {
                $_.Extension -in @('.gd','.tscn','.tres','.res','.aar','.png','.svg','.ttf','.otf','.ogg','.wav') -or
                $_.Name -in @('GODOT_LICENSE.txt','GODOT_COPYRIGHT.txt') -or $_.Name -like '*-OFL.txt'
            } | ForEach-Object { $_.FullName.Substring($projectRoot.Length+1).Replace('\','/') })
        }
    }
    $expected = @($expected | Sort-Object -Unique)
    $properties = @($metadata.source_hashes.PSObject.Properties)
    if ($properties.Count -ne $expected.Count) { throw 'Production source inventory changed or is incomplete. Rebuild before publishing.' }
    foreach ($relative in $expected) {
        $record = $metadata.source_hashes.PSObject.Properties[$relative]
        $path = Join-Path $projectRoot $relative
        if ($null -eq $record -or $record.Value -isnot [string] -or $record.Value -cnotmatch '^[a-f0-9]{64}$' -or
            -not (Test-Path -LiteralPath $path -PathType Leaf) -or
            (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -cne $record.Value) {
            throw "Source snapshot is stale or incomplete at $relative. Rebuild and retest before publishing."
        }
    }
    return $expected.Count
}

if ($Repository -cnotmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') { throw 'Invalid GitHub repository.' }
$baseUrl = 'https://github.com/'+$Repository
if (-not $ApkPath) { $ApkPath = Join-Path $projectRoot 'build\android\TheGods.apk' }
if (-not $MetadataPath) { $MetadataPath = Join-Path $projectRoot 'build\android\build-metadata.json' }
if (-not $ConfigPath) { $ConfigPath = Join-Path $projectRoot 'release\android.json' }
$config = Read-JsonFile $ConfigPath
$metadata = Read-JsonFile $MetadataPath
$sourceCount = Assert-SourceSnapshot
Assert-Integer $config.schema 1 1 'release schema'
Assert-Integer $config.version_code 1 2100000000 'release version code'
if ($config.channel -cne 'stable' -or $config.package_name -cne 'games.thegods.sandbox' -or
    $config.version_name -isnot [string] -or $config.version_name -cnotmatch '^\d+\.\d+\.\d+$' -or
    $config.manifest_url -cne ($baseUrl+'/releases/latest/download/update.json') -or
    $config.download_page_url -cne ($baseUrl+'/releases/latest') -or
    $config.apk_url_prefix -cne ($baseUrl+'/releases/download/')) { throw 'Release configuration does not match the stable distribution contract.' }
$tag = 'v'+$config.version_name
if (-not (Test-Path -LiteralPath $ApkPath -PathType Leaf)) { throw 'The release APK is missing. Build and test it first.' }
$ApkPath = (Resolve-Path -LiteralPath $ApkPath).Path
$apkLength = (Get-Item -LiteralPath $ApkPath).Length
Assert-Integer $apkLength 1 $maximumApkBytes 'APK length'
$apkHash = (Get-FileHash -LiteralPath $ApkPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($metadata.apk_sha256 -cne $apkHash -or $metadata.apk_size -ne $apkLength -or
    $metadata.package_name -cne $config.package_name -or $metadata.version_code -ne $config.version_code -or
    $metadata.version_name -cne $config.version_name -or $metadata.signing_alias -cne 'thegods') { throw 'APK, build metadata, and release configuration do not agree. Rebuild before publishing.' }
$storePath = Join-Path $SigningDirectory 'the-gods-release.keystore'
$secretPath = Join-Path $SigningDirectory 'password.dpapi'
if (-not (Test-Path -LiteralPath $storePath -PathType Leaf) -or -not (Test-Path -LiteralPath $secretPath -PathType Leaf)) {
    throw 'The durable release keystore or password.dpapi is missing. Restore the original signing directory; do not replace the key.'
}
if ([IO.Path]::GetFullPath($metadata.signing_keystore_path) -ine [IO.Path]::GetFullPath($storePath)) { throw 'Build metadata names a different signing keystore.' }
if (-not $JavaSdk) { $JavaSdk = ([IO.File]::ReadAllText((Join-Path $env:USERPROFILE '.cache\the-gods-tools\android\jdk-path.txt'))).Trim() }
$JavaSdk = (Resolve-Path -LiteralPath $JavaSdk).Path
$apksigner = (Resolve-Path -LiteralPath (Join-Path $AndroidSdk 'build-tools\36.1.0\apksigner.bat')).Path
$aapt = (Resolve-Path -LiteralPath (Join-Path $AndroidSdk 'build-tools\36.1.0\aapt.exe')).Path
$keytool = (Resolve-Path -LiteralPath (Join-Path $JavaSdk 'bin\keytool.exe')).Path
$gh = (Get-Command gh -CommandType Application).Source
$stage = Join-Path $projectRoot ('build\android\publish\'+$tag+'-'+[Guid]::NewGuid().ToString('N').Substring(0,10))
New-Item -ItemType Directory -Force -Path $stage | Out-Null
$oldJava = [Environment]::GetEnvironmentVariable('JAVA_HOME','Process')
$oldPassword = [Environment]::GetEnvironmentVariable('THE_GODS_PUBLISH_KEYSTORE_PASSWORD','Process')
$passwordPointer = [IntPtr]::Zero
$draftCreated = $false
$published = $false
$publishAttempted = $false
try {
    $env:JAVA_HOME = $JavaSdk
    $identity = Get-ApkIdentity $ApkPath
    if ($identity.package_name -cne $config.package_name -or $identity.version_code -ne $config.version_code -or
        $identity.version_name -cne $config.version_name -or $identity.cert_sha256 -cne $metadata.cert_sha256 -or
        (@($identity.architectures | Sort-Object) -join ',') -cne 'arm64-v8a,x86_64' -or
        (@($metadata.architectures | Sort-Object) -join ',') -cne 'arm64-v8a,x86_64') { throw 'Signed APK identity, architectures, or certificate disagree with the release metadata.' }

    $securePassword = (Get-Content -LiteralPath $secretPath -Raw).Trim() | ConvertTo-SecureString
    try {
        $passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
        $env:THE_GODS_PUBLISH_KEYSTORE_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPointer)
        $keyInfo = Invoke-Checked $keytool @('-J-Duser.language=en','-list','-v','-keystore',$storePath,'-alias','thegods','-storepass:env','THE_GODS_PUBLISH_KEYSTORE_PASSWORD') 'Trusted signing-key inspection'
    } finally {
        if ($passwordPointer -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer); $passwordPointer=[IntPtr]::Zero }
        if ($null -ne $securePassword) { $securePassword.Dispose() }
        [Environment]::SetEnvironmentVariable('THE_GODS_PUBLISH_KEYSTORE_PASSWORD',$oldPassword,'Process')
    }
    $trustedCertificate = [regex]::Match($keyInfo,'(?m)^\s*SHA256:\s*([A-Fa-f0-9:]+)\s*$')
    if (-not $trustedCertificate.Success -or $trustedCertificate.Groups[1].Value.Replace(':','').ToLowerInvariant() -cne $identity.cert_sha256) { throw 'APK signer is not the durable release signing key.' }

    $repoInfo = (Invoke-Checked $gh @('api',"repos/$Repository") 'Public repository inspection') | ConvertFrom-Json
    if ($repoInfo.private -or $repoInfo.archived -or -not $repoInfo.permissions.push) { throw 'Publishing requires the active public distribution repository and push permission.' }
    $tagMatches = (Invoke-Checked $gh @('release','list','--repo',$Repository,'--limit','1000','--json','tagName') 'Release tag inspection') | ConvertFrom-Json
    if (@($tagMatches | Where-Object { $_.tagName -ceq $tag }).Count -gt 0) { throw "Release $tag already exists. Inspect its draft or choose a new version; existing assets are never overwritten." }
    if (@($tagMatches).Count -ge 1000) { throw 'Release tag inventory reached its bound; review publisher pagination before publishing.' }
    $previous = Get-PublishedState
    Assert-VersionAdvance $previous
    if ($null -ne $previous) {
        # A replaced local keystore cannot silently strand installed users.
        $previousDirectory = Join-Path $stage 'previous-apk'
        New-Item -ItemType Directory -Path $previousDirectory | Out-Null
        $null = Invoke-Checked $gh @('release','download',$previous.tag,'--repo',$Repository,'--pattern','The-Gods-Android.apk','--dir',$previousDirectory) 'Previous signed APK download'
        $previousApk = Join-Path $previousDirectory 'The-Gods-Android.apk'
        if ((Get-Item -LiteralPath $previousApk).Length -ne $previous.manifest.apk_bytes -or
            (Get-FileHash -LiteralPath $previousApk -Algorithm SHA256).Hash.ToLowerInvariant() -cne $previous.manifest.apk_sha256) { throw 'Previous public APK does not match its manifest.' }
        $previousIdentity = Get-ApkIdentity $previousApk
        if ($previousIdentity.cert_sha256 -cne $identity.cert_sha256 -or $previousIdentity.package_name -cne $config.package_name -or
            $previousIdentity.version_code -ne $previous.manifest.version_code) { throw 'Candidate is not a signed upgrade of the previously published application.' }
    }

    $notes = 'Native Android edition of The Gods with local worlds, touch controls, and optional startup update checks.'
    if ($NotesPath) { $notes = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $NotesPath).Path).Trim() }
    $manifest = [ordered]@{
        schema=1; channel='stable'; package_name=$config.package_name; version_code=[int]$config.version_code
        version_name=$config.version_name; apk_url=($baseUrl+'/releases/download/'+$tag+'/The-Gods-Android.apk')
        apk_sha256=$apkHash; apk_bytes=$apkLength; notes=$notes
    }
    Assert-Manifest ([pscustomobject]$manifest) $tag
    $stagedApk = Join-Path $stage 'The-Gods-Android.apk'
    Copy-Item -LiteralPath $ApkPath -Destination $stagedApk
    if ((Get-FileHash -LiteralPath $stagedApk -Algorithm SHA256).Hash.ToLowerInvariant() -cne $apkHash) { throw 'APK changed while preparing the release. Rebuild and retry.' }
    $manifestPath = Join-Path $stage 'update.json'
    [IO.File]::WriteAllText($manifestPath,($manifest | ConvertTo-Json -Depth 3))
    $manifestHash = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $releaseNotes = $notes+"`n`n"+'Download **The-Gods-Android.apk** for ARM64 or x86_64 Android. Android asks you to confirm installation. Install over the existing app to retain local saves.'+"`n`n"+
        '[Installation and update instructions]('+$baseUrl+'#install)'+"`n`n"+'Package: `'+$config.package_name+'` | Version code: `'+$config.version_code+'`'+"`n`n"+'APK SHA-256: `'+$apkHash+'`'
    $releaseNotesPath = Join-Path $stage 'release-notes.md'
    [IO.File]::WriteAllText($releaseNotesPath,$releaseNotes)
    $plan = [ordered]@{repository=$Repository;tag=$tag;version_code=$config.version_code;apk_bytes=$apkLength;apk_sha256=$apkHash;cert_sha256=$identity.cert_sha256;manifest_sha256=$manifestHash;source_count=$sourceCount;source_hashes=$metadata.source_hashes;previous_version_code=$(if ($null -ne $previous) {$previous.manifest.version_code} else {0});prepared_at_utc=[DateTime]::UtcNow.ToString('o');publish_requested=[bool]$Publish}
    [IO.File]::WriteAllText((Join-Path $stage 'publish-plan.json'),($plan | ConvertTo-Json))
    Write-Output ("Verified Android {0} ({1}), {2:N1} MiB, ARM64 + x86_64." -f $config.version_name,$config.version_code,($apkLength/1MB))
    Write-Output ("Verified {0} production source hashes against the build snapshot." -f $sourceCount)
    Write-Output ('Prepared release files: '+$stage)
    if (-not $Publish) { Write-Output 'Preflight complete. No GitHub release or asset was created. Add -Publish only after this build passes release testing.'; return }

    # Recheck immediately before making the draft. Only these two assets are
    # uploaded; build metadata, source files, and signing material stay local.
    Assert-VersionAdvance (Get-PublishedState)
    $null = Assert-SourceSnapshot
    $null = Invoke-Checked $gh @('release','create',$tag,'--repo',$Repository,'--draft','--target',$repoInfo.default_branch,'--title',('The Gods '+$config.version_name+' for Android'),'--notes-file',$releaseNotesPath) 'Draft release creation'
    $draftCreated = $true
    $null = Invoke-Checked $gh @('release','upload',$tag,$stagedApk,$manifestPath,'--repo',$Repository) 'Draft asset upload'
    $uploaded = (Invoke-Checked $gh @('release','view',$tag,'--repo',$Repository,'--json','isDraft,assets') 'Draft asset inspection') | ConvertFrom-Json
    if (-not $uploaded.isDraft -or @($uploaded.assets).Count -ne 2 -or
        @($uploaded.assets | Where-Object { $_.name -ceq 'The-Gods-Android.apk' -and $_.size -eq $apkLength }).Count -ne 1 -or
        @($uploaded.assets | Where-Object { $_.name -ceq 'update.json' -and $_.size -eq (Get-Item -LiteralPath $manifestPath).Length }).Count -ne 1) { throw 'Draft assets are incomplete or differ from the release plan.' }
    $verificationDirectory = Join-Path $stage 'uploaded-verification'
    New-Item -ItemType Directory -Path $verificationDirectory | Out-Null
    $null = Invoke-Checked $gh @('release','download',$tag,'--repo',$Repository,'--pattern','The-Gods-Android.apk','--pattern','update.json','--dir',$verificationDirectory) 'Uploaded asset verification download'
    foreach ($asset in @(@('The-Gods-Android.apk',$apkHash),@('update.json',$manifestHash))) {
        if ((Get-FileHash -LiteralPath (Join-Path $verificationDirectory $asset[0]) -Algorithm SHA256).Hash.ToLowerInvariant() -cne $asset[1]) { throw ('Uploaded asset failed byte verification: '+$asset[0]) }
    }
    Assert-VersionAdvance (Get-PublishedState)
    $null = Assert-SourceSnapshot
    $publishAttempted = $true
    $null = Invoke-Checked $gh @('release','edit',$tag,'--repo',$Repository,'--draft=false','--latest') 'Complete release publication'
    $published = $true
    $final = (Invoke-Checked $gh @('release','view',$tag,'--repo',$Repository,'--json','isDraft,url') 'Published release verification') | ConvertFrom-Json
    if ($final.isDraft) { throw 'GitHub still reports a draft after publication; inspect the release before retrying.' }
    $publicManifestPath = Join-Path $stage 'public-update.json'
    Invoke-WebRequest -UseBasicParsing -Uri $config.manifest_url -OutFile $publicManifestPath -TimeoutSec 60 | Out-Null
    if ((Get-FileHash -LiteralPath $publicManifestPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $manifestHash) { throw 'Public stable manifest has not resolved to the new verified manifest. Inspect GitHub publication and caching before retrying.' }
    [IO.File]::WriteAllText((Join-Path $stage 'published.json'),(@{url=$final.url;manifest_url=$config.manifest_url;published_at_utc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json))
    Write-Output ('Published: '+$final.url)
    Write-Output ('Stable manifest: '+$config.manifest_url)
} catch {
    if ($published -or $publishAttempted) { Write-Warning "Publication of $tag was attempted and may already be public. Inspect its state before retrying; the following failure may concern final verification only." }
    elseif ($draftCreated) { Write-Warning "Draft $tag was retained for inspection. The previously published release was not replaced. No assets were overwritten." }
    throw
} finally {
    if ($passwordPointer -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer) }
    [Environment]::SetEnvironmentVariable('JAVA_HOME',$oldJava,'Process')
    [Environment]::SetEnvironmentVariable('THE_GODS_PUBLISH_KEYSTORE_PASSWORD',$oldPassword,'Process')
}
