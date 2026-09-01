# iTranslator

Status: Under development
Platform: iOS

iTranslator is currently under active development.

iTranslator is a free, lightweight iOS translation app that runs entirely on your device. It processes translations in real time without relying on external servers, an internet connection, or cloud APIs.

---

## Requirements

### To run the app on your phone

* Device: iPhone 11 or newer (needs the A13 Bionic chip or a newer chip for local processing)
* Account: a standard, free Apple ID (a paid Apple Developer account is not required)
* Setup: a Mac or PC for the initial sideload process

### To build the app from source

* npm (Node.js environment)
* Tailscale, used as a network bridge between remote environments and local devices
* iTunes or the Apple Devices app, required for iOS connection drivers
* Sideloadly, required to sideload the generated .ipa file onto iOS
* An iPhone with Developer Mode enabled (Settings > Privacy & Security > Developer Mode)

---

## Building from Source

### 1. Clone and install

```bash
git clone https://github.com/ramiz-alsafi/iTranslator.git
cd iTranslator
npm install
```

Once the build completes, you will have an `iTranslator.ipa` file ready to sideload using the steps below.

### Running in development mode (Windows)

To start the app in development mode on Windows, run:

```bash
npx expo start --dev-client
```

This starts the Expo development server. Keep your iPhone connected to the same network as your Windows machine (or connected through Tailscale) and open the app on your device to connect to the development server.

---

## Installing the App

Since iTranslator is completely local and does not require a paid developer account, you can sideload it onto your iPhone using tools such as Sideloadly or AltStore.

### Step 1: Get the app

Download the latest `iTranslator.ipa` file from the Releases page to your computer, or build it yourself from source as shown above.

### Step 2: Sideload with Sideloadly

1. Download and install Sideloadly on your PC or Mac.
2. Connect your iPhone to your computer with a USB cable and select Trust if prompted.
3. Open Sideloadly and drag the `iTranslator.ipa` file into the Sideloadly window.
4. Enter your standard, free Apple ID in the Apple account field. This is sent to Apple only to sign the app for your specific device.
5. Click Start and wait for the progress bar to finish and show Done.

### Step 3: Trust the app on your iPhone

1. On your iPhone, go to Settings > General > VPN & Device Management.
2. Under the Developer App section, tap your Apple ID.
3. Tap Trust to allow the app to run.
4. On iOS 16 and later, go to Settings > Privacy & Security, scroll down to Developer Mode, turn it on, and restart your phone.

Free Apple IDs require sideloaded apps to be refreshed every 7 days. You can set Sideloadly or AltStore to refresh the app wirelessly over your local Wi Fi before it expires.
