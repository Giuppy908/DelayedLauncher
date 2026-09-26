# DelayedLauncher

DelayedLauncher is a small macOS utility that lets you choose which applications should open after login and add a custom delay for each one.

I built it because I wanted to avoid having several apps launch at the same time immediately after starting my Mac.

The app is currently intended for Apple Silicon Macs.

## Features

- Add or remove applications from the startup list
- Set a different startup delay for each app
- Enable or disable individual applications
- Automatically skips apps that are already running
- Shows whether a configured app is currently open
- Sort applications by name
- Native macOS login integration
- Runs silently when launched automatically at login
- No external scripts or manually configured LaunchAgents required

## Installation

1. Download the latest `DelayedLauncher.zip` from the [Releases](../../releases) section
2. Extract the ZIP file
3. Move `DelayedLauncher.app` to the `/Applications` folder
4. Open DelayedLauncher
5. Add the applications you want to manage
6. Set the desired delay for each application
7. Enable **Avvia al login**

macOS may also require permission for DelayedLauncher to run in the background.

You can check this in:

**System Settings → General → Login Items**

Make sure DelayedLauncher is allowed to run in the background.

## First launch on macOS

The downloadable build is not currently notarized with an Apple Developer certificate.

Because of this, macOS may block the app the first time you try to open it.

If that happens:

1. Try to open `DelayedLauncher.app`
2. Open **System Settings → Privacy & Security**
3. Scroll down until you find the message related to DelayedLauncher
4. Click **Open Anyway**
5. Confirm the launch

This usually only needs to be done once.

## How it works

When macOS starts, DelayedLauncher runs in the background and starts a separate timer for every enabled application.

For example:

```text
Rectangle      5 seconds
AltTab        10 seconds
Antinote      15 seconds
