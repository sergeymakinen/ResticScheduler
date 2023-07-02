# Restic Scheduler

[![Downloads](https://img.shields.io/github/downloads/sergeymakinen/ResticScheduler/total)](https://github.com/sergeymakinen/ResticScheduler/releases)
[![Latest Version](https://img.shields.io/github/v/release/sergeymakinen/ResticScheduler)](https://github.com/sergeymakinen/ResticScheduler/releases/latest)

Native macOS menu bar app heavily inspired by Apple's Time Machine to perform scheduled backups using [restic](https://github.com/restic/restic).

## Features

* Built-in restic binary (but using a custom one is also possible)
* Back up every hour, day or week
* SFTP, rest or local repository types
* List of included/excluded files/folders
* Custom command-line arguments

## Screenshots

<p align="center">
  <img alt="Backing Up" src="https://github.com/sergeymakinen/ResticScheduler/assets/983964/2c0da061-5a70-4cf6-a0a3-2b3d7f84e247">
  <img alt="Status" src="https://github.com/sergeymakinen/ResticScheduler/assets/983964/d1fac75f-a9f3-4e73-93cd-2f0392cc2f1e">
  <img width="624" alt="General" src="https://github.com/sergeymakinen/ResticScheduler/assets/983964/4edae23f-dedc-4e2d-b4ef-dedc4ce73585">
  <img width="624" alt="Restic" src="https://github.com/sergeymakinen/ResticScheduler/assets/983964/530433d7-9734-4738-b463-abc4915fc3c9">
  <img width="624" alt="Advanced" src="https://github.com/sergeymakinen/ResticScheduler/assets/983964/0fa108ac-d9cf-4383-8992-97b5bd952db5">
</p>

## Installation

macOS 13 or higher is required.

Download the [latest archive](https://github.com/sergeymakinen/ResticScheduler/releases/latest), unzip it and move the app to Applications folder.

## Building

1. Download a [restic binary](https://github.com/restic/restic/releases/latest) for macOS and place the extracted binary named `restic` at the project folder
2. If you don't need a code signing, run `make disable-code-signing`
3. Otherwise create a `Config.xcconfig` file at the project folder with the following content:

    ```env
    CODE_SIGN_STYLE = Automatic
    DEVELOPMENT_TEAM = 12ABCDE45F
    MARKETING_VERSION = 0.0.0
    APP_BUNDLE_ID = ru.makinen.ResticScheduler
    APP_RESTIC_BINARY = restic
    ```

    Note: set `DEVELOPMENT_TEAM` to your Development Team ID.

4. Open `ResticScheduler.xcodeproj` in Xcode and build the project
5. Or run `make` to build from the command-line

## License

MIT
