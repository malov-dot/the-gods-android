# The Gods native Android updater

This standalone Android library supplies the `TheGodsUpdater` Godot v2 singleton. The bootstrap scene owns update metadata, HTTPS downloads, progress and the game/offline choice. The library verifies the downloaded APK and opens Android's own permission and installation screens.

## Build

`tools/build_android_plugin.ps1 -JavaSdk <JDK17> -AndroidSdk <SDK> -TemplateDirectory <Godot4.7.2Templates>` builds the library, runs its JVM tests and copies the release AAR to `addons/the_gods_updater/bin/the-gods-updater-release.aar`. The template directory must contain the official `android_source.zip`. The helper obtains the exact Gradle wrapper and compile-only Godot release AAR from that archive; the latter remains in the external tool cache.

The library uses Java 17, Gradle 8.11.1, Android Gradle Plugin 8.6.1, compile SDK 36, Build Tools 36.1.0 and minimum SDK 24, matching the Godot 4.7.2 template. Its only runtime dependency is AndroidX Core 1.16.0. The Godot editor addon supplies both the AAR and Maven dependency during a Gradle Android export. `res://addons/the_gods_updater/plugin.cfg` must be enabled in `project.godot`.

## GDScript contract

| Method | Result |
|---|---|
| `get_installed_info()` | JSON with `package_name`, `version_code`, `version_name`; an error is `{ok:false,message}` |
| `get_display_density()` | Android display density, clamped to 0.5–8.0 |
| `get_update_path()` | Absolute private-files path `updates/update.apk`, or an empty string if its directory cannot be created |
| `verify_apk(path, expected_sha, expected_version)` | Asynchronous; emits `verification_finished(result_json)` with `{ok,message}` |
| `can_install_packages()` | Android 8+ per-app installation permission; Android 7's system installer handles its global setting |
| `request_install_permission()` | Opens this app's Android installation-source settings if needed; emits `permission_returned(allowed)` once on return |
| `install_verified_apk()` | Revalidates the file and returns `"opened"` after opening Android's installer, or an error string |

`installer_returned()` has no arguments. It means the installer activity returned, including cancellation; it is not proof of a successful update. A successful replacement can terminate the old process. The bootstrap should reopen/check the installed version on its next launch.

Connect signals before requesting verification or permission. Only one verification runs at a time. The initial verification runs on a worker; the final install method synchronously rehashes and checks package metadata before dispatching the installer on Android's UI thread.

## Validation and file access

The verifier accepts only the app's canonical private `files/updates/update.apk` and a bounded nonempty file. It compares the announced SHA-256, APK package name, strictly newer version code, exact announced version and the SHA-256 set of current signing certificates against the installed game. Android's package parser collects signing information; Android 16 additionally uses its explicit verified-signing API with APK Signature Scheme v2 or newer. A second digest after parsing detects a changed candidate. Length, modification time, digest and package/signing checks run again immediately before requesting installation.

Signing-key rotation is intentionally not accepted: future releases must retain the installed game's current signing key. Releasing an APK with another key will fail verification and Android's update rules. Never put the private release key into the project, AAR, APK or public hosting repository.

The manifest requests only `REQUEST_INSTALL_PACKAGES`. Its nonexported FileProvider has a temporary read grant and serves only `/updates/update.apk`; other URIs, write modes and deletion are rejected. No shared/external-storage permission is used. The installer uses `ACTION_INSTALL_PACKAGE` with a content URI and Android confirmation; there is no silent-install privilege. This intent remains supported by the chosen SDK, although Android recommends PackageInstaller for new general-purpose installers.

## Validation evidence

The initial library build completed successfully and all 10 JVM tests passed with zero failures or errors. They cover private-path confinement, missing/empty/oversized files, known hashes, changed downloads, package mismatch, downgrade/replay/version mismatch, missing/wrong signing keys and multisigner set equality. These are validation-rule tests, not a substitute for Android device execution.

- Build log: `test-output/android-plugin-build.log`
- JUnit XML: `android-updater/build/test-results/testReleaseUnitTest/TEST-games.thegods.updater.UpdateChecksTest.xml`
- Godot 4.7.2 `--check-only` parses the export addon successfully.

The exported app still needs device verification of the settings return callback, installer cancellation and an actual same-key higher-version update. Compilation alone does not establish that those Android lifecycle flows work on a particular manufacturer's device.

## Primary references

- [Godot v2 Android plugin setup and export hooks](https://docs.godotengine.org/en/latest/tutorials/platform/android/android_plugin.html)
- [Exact Godot 4.7.2 Android build configuration](https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/platform/android/java/app/config.gradle)
- [GodotPlugin lifecycle and signal implementation](https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/platform/android/java/lib/src/main/java/org/godotengine/godot/plugin/GodotPlugin.java)
- [Android FileProvider and temporary file grants](https://developer.android.com/reference/androidx/core/content/FileProvider)
- [Android installation-source permission](https://developer.android.com/reference/android/content/pm/PackageManager#canRequestPackageInstalls())
- [Android source-settings activity](https://developer.android.com/reference/android/provider/Settings#ACTION_MANAGE_UNKNOWN_APP_SOURCES)
- [Android package installer intent](https://developer.android.com/reference/android/content/Intent#ACTION_INSTALL_PACKAGE)
- [Package metadata and verified signing APIs](https://developer.android.com/reference/android/content/pm/PackageManager)
- [AndroidX Core release history](https://developer.android.com/jetpack/androidx/releases/core)
