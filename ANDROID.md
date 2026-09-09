# The Gods for Android

## Current release: 1.7.1 — Cast & See

[Version 1.7.1 is published](https://github.com/malov-dot/the-gods-android/releases/tag/v1.7.1), Android code **10701**. It fixes busy-year power selection, lost fast-forward time, queued casting, and visible personal outcomes. The reported issue was on desktop; desktop mouse and graphical fixtures were tested. No new phone review was requested or performed. See [CASTING_UPDATE.md](CASTING_UPDATE.md).

The signed universal APK is **54,235,139 bytes**, SHA-256 `db9b5452c91829bdce18a0506e91a7cd86846782583d93effc9bbacf3639d7e6`. Publication verified the original certificate, both architectures, 47 production-source hashes and uploaded assets. The production startup-download path passes **17 live HTTPS checks**; native installer calls remain mocked in that host test. A matching APK is in `dist/The Gods - Android.apk`.


## Release 1.7.0 — Lives & Stories

Version **1.7.0**, code **10700**, makes The Gods exclusively a single-player sandbox, with a quiet story journal, saved personal projects, actual-person resurrection, family succession, and clearer profiles. Old versus saves convert on load; powers remain free. See [SANDBOX_UPDATE.md](SANDBOX_UPDATE.md) for exact behavior, test scope, and remaining work.

[Version 1.7.0 is published](https://github.com/malov-dot/the-gods-android/releases/tag/v1.7.0). The universal APK is **54,228,472 bytes**, SHA-256 `69adcf3e6331298766e2c934419bdac22cff8512a51be291ee44a103f59507b9`. Publication verified the existing signing certificate, both architectures, 46 production source hashes, and the uploaded assets. The live public startup-update transport passes **17 checks**; native Android installer calls are mocked in that test. A matching APK is at `dist/The Gods - Android.apk`.

No new physical-device installation, touch, voice, or high-population benchmark is claimed. The updater and Android lifecycle are covered by host fixtures. The earlier long-history exact-state discrepancy remains unresolved; references below to an in-progress endurance run are historical, not current status.


## Release 1.6.2

[Version 1.6.2](https://github.com/malov-dot/the-gods-android/releases/tag/v1.6.2), code **10602**, makes news silent and limits it to royal weddings and major war, peace, alliance and revolution events. Fishing boats travel longer water routes; naval and cargo ships visibly sail, with directional wakes. Existing short fishing routes are upgraded on load. See [NEWS_AND_BOATS.md](NEWS_AND_BOATS.md).

The **54,217,619-byte** universal APK has SHA-256 `27f82a0f6f92cda5a57eed83a3a6e4aa0abe3974300595c74a16aaa578ce2b7d`. Publication verified the original signing key, both architectures, **43 production source hashes**, and the uploaded assets. The public updater passed **17 HTTPS checks**, downloading the exact APK and hash; Android installer APIs were mocked. Windows and browser exports match. This version was not installed or physically reviewed on the Fold during this change.

Focused news/transport, marriage, save and large-population tests passed, as did the interface-through-balance regression suites. Graphical captures verify moving boats, and the exported Windows executable launched successfully. The earlier 1,800-year exact-state continuation discrepancy remains unresolved; full archive packaging remains gated.

## Previous release: 1.6.1

[Version 1.6.1](https://github.com/malov-dot/the-gods-android/releases/tag/v1.6.1), code **10601**, adds visible personal consequences, direct action explanations, actual before-and-after stats, and free powers in every mode. See [PERSON_FEEDBACK.md](PERSON_FEEDBACK.md).

The **54,216,363-byte** universal APK has SHA-256 `c246ee7499950fdd34ec1963f84c112538f68825e0acd3fcfecedeae6bc920cb`. Publication verified the original signing key, both architectures, **43 production source hashes**, and the uploaded assets. This version is available through the startup updater; it was not installed or physically tested on the Fold during this change. The Windows executable and browser export are updated to the same version.

Focused feedback, zero-cost authorization, save/load, touch, society and rendering checks passed. The earlier 1,800-year exact-state continuation comparison failed despite matching population and RNG; that discrepancy remains unresolved, so the full archive packaging gate has not been waived.

## Previous release: 1.6.0

[Version 1.6.0](https://github.com/malov-dot/the-gods-android/releases/tag/v1.6.0), code **10600**, adds voices, battle Foley, clickable world stories, detailed close-up people, coastal transport and large-population scheduling improvements. [Full behavior and performance measurements](LIVING_WORLD_UPDATE.md).

The **54,209,480-byte** universal APK has SHA-256 `f0000927fe64980124ed7d2a5922d9929425166371c81ef7727e80bf8514c664`. Publication verified the original signing certificate, both architectures, all **42 production source hashes**, and the uploaded assets by downloading and hashing them before making the release public.

The exact release APK installed successfully over 1.5.1 on the Samsung Fold8 (SM-F971U, Android 17/API 37), preserving application data. Android reports version 10600; the game process remains alive and connected to the installed Google speech engine. **Direct touch testing, listening to character voices, and an 8,000+ resident phone benchmark remain unverified for this release:** the lock/notification screen covered the game during the attempted review. The user was asked to unlock it; no input was sent to that screen.

Automated checks cover the new world features (221), native touch/time behavior (343), resident navigation (68), individual society (2,572), personal powers and saves (338), and the broader HUD/rendering/balance suites. Large-population tests preserve exact outcomes at 12,000 and 20,000 people while yielding simulation work across frames. A fresh 1,800-year endurance run is still in progress; prior-release endurance logs do not validate this gameplay fingerprint. Android's system installer permission flow is not newly tested.

The Android edition installs as a native app. Public Windows and Android downloads and release notes live at [The Gods releases](https://github.com/malov-dot/the-gods-android/releases). The repository also contains the game's source, assets, tests, build tools, and documentation. Private signing keys remain outside the repository.

## Install

1. Open the [latest release](https://github.com/malov-dot/the-gods-android/releases/latest) on your Android device.
2. Download **The-Gods-Android.apk**. One APK targets **Android 7.0 or later**, with **ARM64 and x86_64** support.
3. Open the downloaded file. If Android asks, allow your browser or file manager to install apps from this source.
4. Confirm Android's installation prompt, then open **The Gods**.

The Android package is `games.thegods.sandbox`. Install newer releases over the existing app to preserve its local worlds. Uninstalling the app or clearing its storage can remove those saves. Windows, browser, and Android saves do not synchronize automatically.

## Updates

On a cold launch, the app checks the public stable update manifest when a connection is available. A newer release downloads automatically; installation still requires Android's confirmation. Android may first ask you to allow **The Gods** to install updates from this source.

The update check is optional to gameplay: offline launches and a temporarily unavailable download service let you continue with the installed version. Returning to an already running app is not a new cold launch.

The updater compares Android's integer `versionCode` and checks the downloaded APK's SHA-256, package identity, and signing certificate before handing it to Android. Android also verifies the installation. The app contains no GitHub login, upload token, or private signing key.

Stable update address:

```text
https://github.com/malov-dot/the-gods-android/releases/latest/download/update.json
```

Each manifest points to the APK for one specific release, so a later publication does not change the file described by an older manifest. Release notes and the publisher's verification results accompany each published build.

## Version 1.5.1 — Follow Your People

Swipe vertically through residents, profiles, and long choice sheets. Dragging over a resident or star scrolls without activating it. Each community's leader appears first with a gold LEADER label; the Leaders tab shows leaders across all communities.

Tap a resident's star, or **Favorite this person** in their profile, then use the **Favorites** tab to find them again. Favorites belong to the world and persist when it is saved. They retain a person's history after death. Tap the star again to remove them.

Version **1.5.1**, code **10504**, is published and installed over the existing app on the Galaxy Z Fold 8 without clearing data. On its cover display, ADB-injected Android touches verified resident and profile scrolling, drag cancellation over stars, adding and removing a favorite, opening its profile, and opening the menu after selecting 5x speed and pausing. Evidence: `test-output/android-1.5.1-device-validation.json` and its screenshots.

The 68-check native touch regression suite also covers inner Fold dimensions, phone portrait and landscape layouts, independent choice-sheet scrolling, all-community leaders, and actual save/load persistence. The public update transport passed 17 checks using the published APK; that transport fixture mocks Android's system installer and permission screens.

## Version 1.5.0 — Living Society

People now have selectable stat charts, families, jobs, personal conditions, and direct influence actions. Laws, family bargains, crimes, and organized rebellion connect their lives to civilization outcomes. Existing worlds gain the new society model when loaded.

The signed **1.5.0 test candidate**, code **10500**, was installed over the existing app on the Galaxy Z Fold 8 (SM-F971U), Android 17/API 37, using wireless ADB without clearing data. A cold launch rendered the world on its cover display, and the app remained alive in the background. Android's recorded crashes predate this update. The music-loop correction is retained.

Version **1.5.0**, code **10503**, is published at the public download page and was installed over the existing Fold app through wireless ADB with its data retained. The APK is **54,166,664 bytes**, SHA-256 `f9268b9a282fa6dee366314f81f987c46221dcedfb68511cbda920140752b388`. The publisher verified both architectures, the original signing key, all **36 production-source hashes**, and the uploaded files before publication.

Android now uses its actual logical display density. On the Fold cover display, 48dp touch targets occupy 126 physical pixels instead of about 76. Time, world creation, and community selectors use touch-aware controls instead of mouse-only popups. Speed choices have explanations, a pause action, and an explicit close control; Back dismisses the current sheet first. Opening time and closing panels remain responsive while a simulation year is pending.

Brush radius and volume sliders accept native taps and drags, with at least 48dp touch areas. Mouse emulation stays disabled so one touch cannot also cast a world power through a synthesized mouse event.

Native `ScreenTouch` tests with mouse emulation disabled pass **343 checks**, covering the speed choices, subsequent HUD input, world setup, community selection, rotation, Back/Escape, sliders, cancellation, and controls during pending simulation work. The original popup reproduced the reported trap: native touch left it open; a mouse click at the same point selected an item and closed it. Phone-sized graphical fixtures also validate profiles, families, influence, and society sheets.

The published update path passed **17 live HTTPS checks**. A current-version fixture continued into the game, and an older-version fixture downloaded the complete APK with the correct SHA-256. Android package/signature/permission/installer calls are mocked in that transport test; wireless ADB was used for the actual phone installation.

The final phone installation was completed while the device was asleep; no touch input was sent to another app or the lock screen. Hands-on testing of the final controls, the Android in-app installer route, and very large old-world performance remain unverified. Evidence is recorded in `test-output/android-1.5.0-install-10503.json`, `test-output/android-public-transport.json`, and the named test logs. The earlier candidate startup record is retained separately in `test-output/android-1.5.0-device-validation.json`.

All focused gameplay/UI checks pass. The extended simulation has reached year 1,100, and a 900-year world passed full schema and exact save/load equality. The 1,800-year simulation/save test is still running; its completion is not claimed for this Android publication. Windows/browser exports are refreshed; final ZIP packaging awaits that extended check.

## Version 1.4.1 — music crash correction

The initial release could close about ten seconds after launch because its eight-second ambient clip set the WAV loop end one sample beyond the PCM buffer. Version **1.4.1**, code **10401**, uses the last valid sample index. Music remains enabled.

The signed APK is **54,096,096 bytes**, SHA-256 `410e7ffeaec796ae61b9f54131bec1d16b371afec1ac73a79bc77ae239507b06`. It retains the original package and signing certificate. It was installed over 1.4.0 on a Galaxy Z Fold 8 (SM-F971U), Android 17/API 37, using wireless ADB without clearing app data. The world remained open across repeated music loops; touch selection, world creation, simulation playback, and background/resume worked. Android's recorded native crashes predate the corrected installation.

The new audio regression test fails the old release's loop bounds and passes **13 checks** with the correction, mixing **11,633,400 frames** through Godot's native mixer. It is included in `tools/validate.ps1`. Phone evidence is saved under `test-output/android-device-crash-*` and `test-output/android-1.4.1-phone-*.png`; `tools/capture_android_crash.ps1` collects game-specific logs without clearing logs or app storage.

The in-app Android permission/installer route and broad device compatibility remain unverified. This is a focused fix for the observed audio crash; it does not claim a new simulation endurance run.

## Version 1.4.0 validation history

The final signed APK is **54,096,056 bytes**, version **1.4.0**, Android version code **10400**. Its SHA-256 is:

```text
a332d93e5e5c756189c829217e48375deb8c6c066dc6dc8fef9ceffb78bbc0f1
```

Actual release preflight checked APK signature, package/version, both architectures, the original durable signing certificate, and all **32 recorded production-source hashes**. Build inspection verified updater/FileProvider registration and bundled Godot/font license notices. Controlled updater tests passed **61 graphical / 58 headless checks**, and native validation rules passed **10 JVM tests**. Current game interface, mobile, HUD, and Android lifecycle suites passed **49, 154, 1,632, and 151 checks**, respectively, without warnings or errors.

Version 1.4.0 was published on September 8, 2026. The publisher downloaded both uploaded assets and verified their hashes before making the release public, then verified the anonymous stable manifest. A live Godot HTTPS test passed **17 checks**: the current version continued without downloading an APK, and a simulated older version downloaded all 54,096,056 bytes with the expected SHA-256 before reaching the permission screen. That test mocked Android's package, signature, permission, and installer APIs. Evidence is in `test-output/android-public-transport.json`. A matching local copy is available at `dist/The Gods - Android.apk`.

**Physical Android device execution and a real permission/installer/update cycle have not been verified.** The available emulator crashed. The graphical and lifecycle tests ran on Windows with controlled Android-interface fixtures, display density, and safe-area inputs; they are not evidence of successful installation or performance on a particular phone. No new simulation endurance run is claimed for 1.4.

## Release process

Run `tools/publish_android.ps1` after building and testing. Its default mode checks the release APK, both architectures, the durable signing identity, and the current production files against the build snapshot; rejects any version code that does not advance the published stable releases; and prepares local release files without changing GitHub. The configuration is `release/android.json` and the verified build metadata is `build/android/build-metadata.json`.

After the candidate passes release testing, run the script with `-Publish` and, optionally, `-NotesPath` pointing to a plain text release note of at most 4,000 characters. It creates a GitHub draft, uploads only the APK and manifest, downloads them again to verify their exact hashes, and makes the complete draft public. A failed upload leaves an unpublished draft for inspection. Existing assets are never overwritten; inspect and remove a failed draft manually before retrying its version.

The signing directory lives outside the project at `%USERPROFILE%\.codex\the-gods\android-signing`. Retain the original keystore and securely back up its password: the local `password.dpapi` file is protected by this Windows account and is not a portable password backup. Replacing the signing key prevents an ordinary update over the installed app. The publisher checks continuity with the previous public APK before releasing an upgrade.

Public distribution uses GitHub release assets, which support APK files of this size without splitting them. The GitHub release page is the download page; the app uses its public HTTPS manifest directly.
