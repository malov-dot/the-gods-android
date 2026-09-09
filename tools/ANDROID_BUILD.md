# Android builds

`build_android.ps1` creates one signed release APK for ARM64 phones and x86_64 emulators. Version, package and update URLs come from `release/android.json`. Android's `version_code` must increase for every published update.

## Local toolchain

Godot 4.7.2's bundled `android_source.zip/config.gradle` is the authoritative version pin: Java 17, Gradle 8.11.1, Android Gradle Plugin 8.6.1, Kotlin 2.1.21, SDK 36, Build Tools 36.1.0, NDK 29.0.14206865 and minimum Android API 24. These are more recent than some stable documentation examples.

This machine uses `%USERPROFILE%\.cache\the-gods-tools\android\sdk` and the portable Temurin JDK recorded in `android\jdk-path.txt`. Templates are in `%USERPROFILE%\.cache\the-gods-tools\4.7.2`. `fetch_android_templates.py --source` downloads only Android members from the official Godot template archive and verifies ZIP CRCs. The installed Temurin archive was verified against its official SHA256 checksum.

Run from PowerShell:

```powershell
.\tools\build_android.ps1
```

The tool builds the updater AAR when its build helper is available, copies the current project into a new cached staging directory, imports it with an isolated Godot editor configuration, installs the official Android build template and exports the APK. It never rewrites the working project's presets or the user's Godot settings. Gradle downloads and build files remain in the task cache. A failed stage remains available for diagnosis.

Outputs are `build/android/TheGods.apk`, `build-metadata.json`, `apk-signature.txt` and `apk-manifest.txt`. The script checks the APK signature, package, version, both ABIs and updater permissions. The publisher independently checks this metadata before uploading. `-Architecture arm64-v8a` or `-Architecture x86_64` may be used for private diagnostic builds; the release uses the default `universal`.

## Keep the signing identity

The durable key is `%USERPROFILE%\.codex\the-gods\android-signing\the-gods-release.keystore`, alias `thegods`. `password.dpapi` contains Windows DPAPI ciphertext, not a plaintext password. The key and password never belong in a source archive or public release.

Back up that private directory. DPAPI is tied to this Windows user's protected keys: a copy on another computer alone cannot decrypt it. Before replacing Windows, arrange a protected password-manager recovery copy on the original computer. Losing the signing key prevents existing installations from accepting later updates with their saved data.

The build decrypts the password in its process and restores signing environment variables in `finally`. Build metadata includes the public certificate fingerprint, never the password or key contents.

## Verification

The existing emulator installation and API 35 image are reused read-only. The isolated AVD is `TheGods_Update_Test`, under `%USERPROFILE%\.cache\the-gods-tools\android\avd`; existing AVDs are not altered. Device and emulator runtime results must be reported separately from APK compile/signature checks. Building successfully does not establish that Android's installation permission flow has run on a device.

Official references: [Godot Android export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html), [Godot 4.7.2 source version pins](https://github.com/godotengine/godot/blob/4.7.2-stable/platform/android/java/app/config.gradle), [Godot export templates](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable), [Temurin archive installation](https://adoptium.net/installation/archives/), [Android SDK tools](https://developer.android.com/tools/sdkmanager).
