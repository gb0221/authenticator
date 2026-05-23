# Security

This app stores TOTP secrets — please treat security reports seriously.

## Reporting a vulnerability

**Do not open a public GitHub issue.** Use GitHub's private security advisory
flow:

➡️ <https://github.com/gb0221/authenticator/security/advisories/new>

If that's not available, email the maintainer (see the commit log).

I'll respond within a week. There's no bounty — this is a hobby project — but
disclosed issues will be credited in the changelog.

## Threat model

What this app does:

- Stores TOTP secrets in the macOS Keychain, protected by your login password,
  with `kSecAttrAccessibleWhenUnlocked`.
- Stores non-secret metadata (issuer, name, algorithm, digits) in a JSON file
  in `~/Library/Application Support/Authenticator/`. Anyone with read access to
  your home directory can learn *which* services you have 2FA on, but not the
  secrets.
- Makes zero network calls. There is no telemetry, no auto-update, no sync.

What this app does **not** protect against:

- An attacker with your unlocked macOS session and your login password.
- Malware running on your Mac with your user privileges.
- Physical access to an unlocked Mac (Keychain entries are accessible while
  the session is unlocked).

If those threats are in your model, a hardware token (YubiKey) is a better fit
than any TOTP app.

## Cryptographic correctness

- TOTP/HOTP implementation follows RFC 6238 / RFC 4226 and is tested against
  the published test vectors on every CI run.
- HMAC uses Apple's CryptoKit (`Insecure.SHA1` for the SHA1 case is the
  *correct* API — TOTP requires SHA1; the "insecure" label refers to general
  hashing, not HMAC).
- The migration URI codec is hand-rolled (~80 lines, no dependency). The
  encoder is round-trip-tested against the decoder.
