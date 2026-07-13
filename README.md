# Eluvio Media Wallet for Roku

A Roku TV app for browsing and viewing media properties, collected NFTs, and
redeemable offers on the [Eluvio Content Fabric](https://eluv.io). Users sign in
to their Eluvio media wallet and stream the content they own directly on their TV.

## Features

- Sign in via on-screen QR code or manual code entry
- Browse media properties, sections, and search
- View owned NFTs and their media galleries
- Play video with custom controls and overlays
- Redeem offers and view fulfillment QR codes

## Tech stack

- **Roku SceneGraph** for the UI, built on **SGDEX** (the SceneGraph Developer Extensions).
- **[BrighterScript](https://github.com/rokucommunity/brighterscript)** (`.bs`) —
  a typed superset of BrightScript that compiles down to `.brs`.
- **Mux** for playback analytics.

## Project layout

```
source/
  source/Main.bs            App entry point; bootstraps Fabric config
  manifest                  Roku channel manifest (version, splash, icons)
  components/
    router/                 MainRouter — top-level scene and navigation
    screens/                Feature screens (dashboard, property, nftdetail,
                            signin, videoplayer, gallery, redeemoffer, ...)
    stores/                 App state (Env, tokens, content, properties,
                            playback, permissions)
    http/                   HTTP layer and Eluvio API clients (apis/)
    common/                 Shared UI components (buttons, labels, cards, dialogs)
    utils/                  Helpers (logging, time, rich text, promises, ...)
    mux/                    Mux analytics integration
  images/  fonts/           Static assets
```

## Prerequisites

- [Node.js](https://nodejs.org/) (for the BrighterScript compiler)
- A Roku device in [Developer Mode](https://developer.roku.com/docs/developer-program/getting-started/developer-setup.md)
- [VS Code](https://code.visualstudio.com/) with the
  [BrightScript Language extension](https://marketplace.visualstudio.com/items?itemName=RokuCommunity.brightscript)
  (recommended, for sideloading and debugging)

## Setup

1. Install dependencies:

   ```sh
   npm install
   ```

2. Create a `secrets` file in the project root with the Mux environment keys.
   This file is gitignored and must be supplied manually:

   ```
   MUX_ENV_KEY_MAIN=<key>
   MUX_ENV_KEY_DEMO=<key>
   ```

   > Internal Eluvio devs: see
   > [elv-wallet-android-secrets](https://github.com/qluvio/elv-wallet-android-secrets)
   > for how to generate this file.

3. Configure your Roku device for sideloading. Copy your device IP and developer
   password into `.vscode/.env`:

   ```
   ROKU_IP=192.168.x.x
   ROKU_PW=<developer password>
   ```

## Build & run

Compile BrighterScript to the `dist/` staging directory:

```sh
npx bsc
```

To build, sideload, and debug on your device, use VS Code: press **F5**
(or run the *BrightScript Debug: Launch* configuration). This runs the `build`
task and deploys to the host defined in `.vscode/.env`.

## Environments

The app targets the Eluvio Content Fabric. Available environments are defined in
[`source/components/stores/Env.bs`](source/components/stores/Env.bs):

| Env      | Network      |
| -------- | ------------ |
| `main`   | Production   |
| `demov3` | Demo         |

On a fresh launch the app fetches the `main` config and caches it in the Roku
registry; subsequent launches restore it from there.

## Custom Wallet Build (Single Property)

The channel can be built as a white-label app that is branded for, and locked to,
a single Media Property: custom name/poster/splash, and a landing page that leads
directly into the Property instead of the Discover grid.

See [`custom_build/README.md`](custom_build/README.md).
