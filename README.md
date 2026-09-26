# DelayedLauncher

DelayedLauncher is a small macOS utility that lets you choose which applications should open after login and assign a custom delay to each one.

I built it because I wanted to avoid having several apps launch at the same time immediately after logging in to my Mac.

The downloadable build is currently intended for Apple Silicon Macs.

## Features

- Add or remove applications from the startup list
- Set a different startup delay for each app
- Enable or disable individual applications
- Automatically skips apps that are already running
- Shows whether a configured app is currently open
- Sort applications by name from A to Z or Z to A
- Native macOS login integration
- Runs silently when launched automatically at login
- Uses separate timers for each enabled application
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

When you log in to macOS, DelayedLauncher runs in the background and starts a separate timer for every enabled application.

For example:

```text
Rectangle      5 seconds
AltTab        10 seconds
Antinote      15 seconds
```

Each application is launched when its own timer expires.

If an application is already running, DelayedLauncher leaves it untouched.

After all configured startup tasks have finished, DelayedLauncher closes automatically.

Opening DelayedLauncher manually from Finder, Spotlight or the Applications folder only opens the configuration window.

It does not restart or reopen the applications in the list.

## Application status

DelayedLauncher checks whether configured applications are currently running.

A small status indicator is shown next to each application:
- green: the application is running
- gray: the application is not running
- 
The status is updated automatically while DelayedLauncher is open.

## Startup delays

Each application can have its own startup delay.

New applications are added with a default delay of:

```text
10 seconds
```

The delay can then be changed directly from the interface.

## Login behavior

When Avvia al login is enabled, DelayedLauncher registers itself as a native macOS login item.

At the next login:
1. DelayedLauncher starts in the background
2. no configuration window is shown
3. the configured timers start
4. enabled applications are launched when their delays expire
5. applications that are already running are skipped
6. DelayedLauncher closes automatically when its work is complete
7. 
When DelayedLauncher is opened manually, only the configuration interface is shown and the startup sequence is not executed.

## Building from source

Requirements:
- macOS
- Xcode
- Apple Silicon Mac
- 
Clone the repository:

```bash
git clone https://github.com/Giuppy908/DelayedLauncher.git
```

Then open:

```text
DelayedLauncher.xcodeproj
```

in Xcode and build the DelayedLauncher target.

## Compatibility

The downloadable release is currently intended for Apple Silicon Macs.

Intel Macs are not currently supported by the distributed build.

## Current version

v1.0

## Why I made it

I use several applications that I want available after every login, but I do not need all of them to start immediately.

DelayedLauncher gives me a simple way to spread those launches over a few seconds instead of having everything open at once.
