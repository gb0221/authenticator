# Authenticator

A small, local-only macOS menu-bar TOTP app. Reads accounts from Google Authenticator's export QR, generates codes locally, and exports back out — so your 2FA secrets are never trapped in one app.

[![Tests](https://github.com/gb0221/authenticator/actions/workflows/test.yml/badge.svg)](https://github.com/gb0221/authenticator/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-blue.svg)]()

> Screenshots go in [`docs/screenshots/`](docs/screenshots) — drop your own captures of the menu bar popover, import window, and settings sheet, and replace this line with `![Menu bar popover](docs/screenshots/popover.png)`.

## Why

Authy killed their desktop apps in 2024. The remaining Mac TOTP apps are either paid (Step Two, OTP Auth) or abandoned. This one is:

- **Local-only.** No cloud, no account, no telemetry. Secrets live in the macOS Keychain, metadata in `~/Library/Application Support/Authenticator/`.
- **Two-way Google Authenticator interop.** Imports the `otpauth-migration://` export QR *and* re-emits the same format, so you can move your vault out again whenever you like.
- **Tested against the spec.** TOTP/HOTP correctness is verified against RFC 6238 / RFC 4226 test vectors on every build.
- **Small.** ~1500 lines of Swift, no third-party dependencies, hand-rolled protobuf for the migration codec.

## Features

- Menu-bar popover with all codes, search filter, click-to-copy.
- Import from Google Authenticator (*Transfer accounts → Export accounts*) — drop a screenshot of the QR, paste via ⌘V, or paste the URI as text.
- Import individual `otpauth://totp/...` URIs from any other 2FA setup screen.
- Export your vault back to `otpauth-migration://` URIs (multi-batch when large).
- **Open at login** toggle (`SMAppService`).
- **HOTP** support with auto-incrementing counter on copy.
- Single-instance — launching twice activates the running instance.
- Algorithms: SHA1 / SHA256 / SHA512. Digits: 6 or 8. Periods: configurable.

## Install

This is a build-it-yourself project. There's no signed download — Apple Developer ID + notarization costs $99/yr and isn't worth it for a hobby tool. Building locally takes ~10 seconds after the toolchain is installed.

**Requirements:** macOS 13 or later, Xcode Command Line Tools (`xcode-select --install`).

```sh
git clone https://github.com/gb0221/authenticator.git
cd authenticator
./build-app.sh
open ./Authenticator.app
```

The script builds the SPM executable, wraps it in `Authenticator.app` with the right `Info.plist`, and ad-hoc-signs the bundle. The ad-hoc sign is what gives the Keychain a stable identity for "Always Allow" decisions — so your first-time prompt sticks across rebuilds.

A lock-shield icon appears in your menu bar.

## Usage

### Importing from Google Authenticator

1. On your phone, open Google Authenticator → menu → *Transfer accounts → Export accounts*. Choose accounts → *Next*. You'll get one or more QR codes.
2. On the Mac, click the menu-bar icon → *Add*.
3. Either:
   - Screenshot the QR on your phone, AirDrop it to your Mac, drop the image on the dotted zone.
   - Copy the QR image to your clipboard (⌘⇧⌃4 captures to clipboard) and click *Paste from Clipboard*.
   - Use any QR decoder to get the `otpauth-migration://` URI as text and paste it.
4. Repeat once per QR if Google split the export across multiple QRs.

### Exporting

Click *Export* in the popover footer, pick which accounts to include, click *Generate*. You get one or more `otpauth-migration://` URIs in the same format Google Authenticator emits — paste them into any compatible 2FA app, or render them as QRs with any QR generator.

## Architecture

```
Sources/Authenticator/
├── AuthenticatorApp.swift       App entry (@main)
├── AppDelegate.swift            NSStatusItem, popover, windows
├── Models/
│   ├── Account.swift            Issuer/name/algorithm/digits/period/type
│   └── TOTP.swift               RFC 6238 HMAC-based generator (CryptoKit)
├── Storage/
│   ├── Keychain.swift           Security.framework wrapper
│   ├── AccountStore.swift       ObservableObject — metadata + Keychain access
│   └── Settings.swift           UserDefaults + SMAppService
├── Import/
│   ├── Base32.swift             RFC 4648 decoder (for otpauth secret param)
│   ├── Protobuf.swift           Hand-rolled proto wire-format reader + writer
│   ├── OtpAuthURI.swift         otpauth://totp/... parser
│   ├── MigrationURI.swift       otpauth-migration:// parser AND encoder
│   └── QRImageScanner.swift     Vision VNDetectBarcodesRequest
└── Views/
    ├── MenuContentView.swift    Popover root: search, list, footer
    ├── AccountRow.swift         One row: title, code, copy, countdown ring
    ├── ImportView.swift         Paste / drop / clipboard-paste flow
    ├── ExportView.swift         Account picker → otpauth-migration:// URIs
    └── SettingsView.swift       Open-at-login toggle
```

## Development

Run the test suite:

```sh
swift test
```

Tests cover the cryptographically-sensitive paths:

- **TOTPTests** — RFC 6238 vectors for SHA1, SHA256, SHA512 (6 + 8 digits) and RFC 4226 HOTP vectors.
- **Base32Tests** — RFC 4648 §10 vectors plus lowercase/padding/whitespace tolerance.
- **ProtobufTests** — varint and length-delimited round-trip.
- **URIParserTests** — `otpauth://` parsing and `otpauth-migration://` encode→decode round-trip including multi-batch split.

CI runs `swift test` on every push and PR — see [`.github/workflows/test.yml`](.github/workflows/test.yml).

## Notes & limitations

- First Keychain access prompts for permission. Click *Always Allow* once and it stops asking. The ad-hoc codesign keeps the decision durable across rebuilds **as long as you don't change the bundle identifier**.
- The status item uses `NSStatusItem.squareLength` (icon only). On notched MacBooks, wider items get silently pushed behind the notch and become invisible — even though the system reports `visible=true`. If you swap the icon for a label, watch for this.
- No cloud sync. Deliberately. If your Mac dies, restore from the export URIs or your phone.
- No app icon yet. Contributions welcome.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE) — © 2026 Jake.
