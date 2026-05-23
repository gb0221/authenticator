# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Removed
- Touch ID gate before code reveal (and `Biometrics.swift`).

## [0.1.0] — 2026-05-17

Initial public release.

### Added
- Menu-bar TOTP app for macOS 13+.
- Import accounts from Google Authenticator export QR codes
  (`otpauth-migration://offline?data=…`) via image drop, ⌘V clipboard paste,
  or URI paste.
- Import individual `otpauth://totp/...` URIs.
- Export accounts back to `otpauth-migration://` URIs (multi-batch when large).
- TOTP support for SHA1 / SHA256 / SHA512, 6 or 8 digits, configurable period.
- HOTP support with auto-incrementing counter on copy.
- macOS Keychain storage for secrets; metadata in Application Support.
- Search/filter in the popover.
- Optional Touch ID gate before code reveal.
- "Open at login" toggle (`SMAppService`).
- Single-instance guard.
- Test suite covering RFC 6238 / RFC 4226 vectors, Base32 (RFC 4648),
  protobuf wire-format round-trip, and URI parser round-trip.

[Unreleased]: https://github.com/gb0221/authenticator/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/gb0221/authenticator/releases/tag/v0.1.0
