# The Gods — Android releases

Native Android downloads for **The Gods**, a 2D god sandbox with a living world, fourteen ages, persistent residents, and local versus play.

**[Download the latest release](https://github.com/malov-dot/the-gods-android/releases/latest)**

Downloads appear under Releases as tested versions are published. This repository contains distribution instructions and signed release files. It does not contain the game's development source or private signing keys.

## Install

1. Open the latest release on your Android device and download its `.apk` asset.
2. Open the file. If Android asks, allow your browser or file manager to install apps from this source.
3. Confirm installation and launch **The Gods**.

One APK supports ARM64 and x86_64 Android devices. The application package is `games.thegods.sandbox`. Install a newer release over the existing app to keep its local worlds. Uninstalling the app or clearing its storage can remove saves. Android, Windows, and browser saves do not automatically sync.

## Updates and offline play

On a cold launch, the Android app checks the public stable update manifest when online. A newer release is offered for download; Android always asks before installing it. Android may also ask you to allow **The Gods** to install updates from this source.

An unavailable network or update service does not prevent playing the installed version. Returning to an already running app is not a new cold launch.

Updates use an increasing Android version code, a SHA-256 check of the downloaded APK, and package/signature verification before Android's installation prompt. The app contains no GitHub credentials or private signing key.

Stable manifest:

```text
https://github.com/malov-dot/the-gods-android/releases/latest/download/update.json
```

Every manifest references a version-specific APK. Release notes describe each build and its verified testing coverage. Download and install only builds published in this repository.