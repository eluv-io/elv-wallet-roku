# Custom Wallet Build (Single Property / White Label)

Build a version of the Media Wallet Roku channel that is branded for, and locked to, a single Media Property:

- There is no Discover page or Dashboard: signed-in users are dropped directly into the Property page. A **Profile** button (next to Search in the Property header) provides account access.
- Signed-out users see a landing page with the Property's start-screen logo and background (configured in Creator Studio) and a single **Sign In** button that leads into the Property.
- The channel name, home-screen poster and splash screen are replaced with your own branding.

## Prerequisites

- Everything under [Requirements in the main README](../README.md) (Node.js, `npm install` in the repo root).
- The Property ID you want to build for (starts with `iq__`, find it in Creator Studio).
- `zip` and `curl` (present by default on macOS/Linux).

## Steps

1. **Fill in the config**: edit [`config/custom.properties`](config/custom.properties) and set at least
   `APP_TITLE`, `PROPERTY_ID` and the version numbers.

2. **Add branding images**: drop 6 JPGs into [`config/images/`](config/images/) —
   3 channel poster sizes and 3 splash screen sizes. See
   [`config/images/README.md`](config/images/README.md) for exact filenames and dimensions.

3. **(Optional) Set start-screen branding in Creator Studio**: the in-app landing page uses the
   Property's `start_screen_logo` and `start_screen_background` (falling back to the TV header
   logo / TV background image when unset).

4. **Verify**: `./build.sh -v` checks the config without building.

5. **Build**: `./build.sh` produces a sideloadable package at
   `custom_build/build/<AppTitle>_v<version>.zip`.

6. **Test on a device**: `./build.sh -d` builds, installs and runs on a Roku device —
   the same flow as pressing F5 in VS Code, using the same `.vscode/.env` in the repo root
   for `ROKU_IP` / `ROKU_PW` (already-exported env vars take precedence).

## Publishing

Roku channels are published through the [Roku developer dashboard](https://developer.roku.com/):
sideload the zip on a device, then package it with your signing key (Development Application
Installer -> Packager) and upload the signed `.pkg` to your channel listing. The standard Eluvio
wallet and each custom build are separate channels with separate signing keys.

## How it works

- `build.sh` copies `source/` into `custom_build/build/` (a disposable dir that mirrors the
  repo root layout: `source/` → `dist/`), patches the copy's `manifest` (title, version,
  splash color), overwrites its poster/splash images, and writes the Property ID into its
  `source/config/custom_build.json`, then compiles and zips it. The repo working tree is
  not modified.
- At runtime, `CustomBuild.bs` reads `pkg:/config/custom_build.json`. When `property_id` is
  non-empty the app runs in "single property mode": instead of the Dashboard, the app boots
  straight into `PropertyDetail` when signed in, or into `SinglePropertyLanding` when signed
  out. The Property header gains a Profile button (sign-out lives there). Sign-in and deep
  links behave like the regular wallet; the My Items screen is not reachable in this mode.
- The default (committed) `custom_build.json` has an empty `property_id`, so regular builds are
  unaffected.
