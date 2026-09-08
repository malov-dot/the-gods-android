# The Gods — Android releases

Native Android downloads for **The Gods**, a 2D god sandbox with a living world, fourteen ages, persistent residents, and local versus play.

**[Download the latest release](https://github.com/malov-dot/the-gods-android/releases/latest)**

Downloads appear under Releases as tested versions are published. This repository contains distribution instructions and signed release files. It does not contain the game's development source or private signing keys.

## Install

1. Open the latest release on your Android device and download its `.apk` asset.
2. Open the file. If Android asks, allow your browser or file manager to install apps from this source.
3. Confirm installation and launch **The Gods**.

One APK targets Android 7.0 or later with ARM64 and x86_64 support. The application package is `games.thegods.sandbox`. Install a newer release over the existing app to keep its local worlds. Uninstalling the app or clearing its storage can remove saves. Android, Windows, and browser saves do not automatically sync.

## Updates and offline play

On a cold launch, the Android app checks the public stable update manifest when online. A newer release downloads automatically; Android always asks before installing it. Android may also ask you to allow **The Gods** to install updates from this source.

An unavailable network or update service does not prevent playing the installed version. Returning to an already running app is not a new cold launch.

Updates use an increasing Android version code, a SHA-256 check of the downloaded APK, and package/signature verification before Android's installation prompt. The app contains no GitHub credentials or private signing key.

Stable manifest:

```text
https://github.com/malov-dot/the-gods-android/releases/latest/download/update.json
```

Every manifest references a version-specific APK. Release notes describe each build and its verified testing coverage. Download and install only builds published in this repository.

## Android 1.4.1

Version 1.4.1 fixes a crash shortly after launch when the background music loops. It was installed over 1.4.0 and tested on a Galaxy Z Fold 8 running Android 17 through repeated music loops, world creation, touch selection, simulation playback, and background/resume. App data was not cleared. Music remains enabled.

The new audio regression catches the old release's invalid sample boundary and passes 13 checks with the correction. APK signature, package, architectures, and production sources are verified before publication. The in-app Android permission/installer flow remains unverified because the phone installation used wireless ADB. See release notes for exact evidence and limits.
