# Restic Scheduler

[![Downloads](https://img.shields.io/github/downloads/sergeymakinen/ResticScheduler/total)](https://github.com/sergeymakinen/ResticScheduler/releases)
[![Latest Version](https://img.shields.io/github/v/release/sergeymakinen/ResticScheduler)](https://github.com/sergeymakinen/ResticScheduler/releases/latest)

Native macOS menu bar app heavily inspired by Apple's Time Machine to perform scheduled backups using [restic](https://github.com/restic/restic).

## Features

* Built-in restic binary (but using a custom one is also possible)
* Back up every hour, day or week
* SFTP, REST, S3 (+ compatible) or local repository types
* List of included/excluded files/folders
* Custom command-line arguments
* Backup success/failure hooks

## Screenshots

<p align="center">
  <img alt="Backing Up" src="https://github.com/user-attachments/assets/acde0a7e-551b-49d1-8173-6a24ad7e4e4c">
  <img alt="Status" src="https://github.com/user-attachments/assets/19d1a2b8-a40d-43a4-80b3-07c95e808c37">
  <img width="624" alt="General" src="https://github.com/user-attachments/assets/527ddf84-f83e-4c4d-80e6-4f532defc364">
  <img width="624" alt="Restic" src="https://github.com/user-attachments/assets/c310068f-39c8-4350-990c-f5a9533de7e7">
  <img width="624" alt="Advanced" src="https://github.com/user-attachments/assets/de57a69c-c609-4106-be14-39429bc0716d">
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
