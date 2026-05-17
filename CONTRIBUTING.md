# Contributing

Thanks for your interest. This is a small project — no formal review board, no
required ceremony. The bar is:

1. **Tests pass.** Run `swift test` locally before opening a PR. CI runs the same.
2. **Don't break crypto.** Anything touching `TOTP.swift`, `Base32.swift`,
   `Protobuf.swift`, or the URI parsers needs an accompanying test (RFC vectors
   where possible, round-trip otherwise).
3. **No third-party dependencies.** Part of the point of this app is that it's
   auditable in an afternoon. If you reach for a dependency, open an issue
   explaining why first.

## Getting started

```sh
git clone <your fork>
cd authenticator
swift test                # run the suite
./build-app.sh            # build the .app bundle
open ./Authenticator.app  # run it
```

## What's helpful

- **Bugs**, especially around: Google Authenticator import edge cases (unusual
  algorithms/digits, very large exports), notch-related menu-bar weirdness,
  Keychain prompt behavior on different macOS versions.
- **App icon.** There isn't one yet — a clean SF-Symbol-style lock-shield
  would be very welcome.
- **Screenshots** for the README (`docs/screenshots/`).
- **Other authenticator import formats** (Aegis, 2fas, Authy JSON dump) —
  these are well-defined and easy to add to `Import/`.
- **Drag-to-reorder, account rename/edit**, account-level icons (favicon
  fetch for the issuer).

## What I'm probably going to say no to

- Cloud sync. The whole point of this app is local-only. If you want sync,
  fork it — but I won't merge it into main.
- Pulling in a protobuf library. The hand-rolled codec in `Protobuf.swift`
  is intentional — it's ~80 lines and there's nothing in SwiftProtobuf that
  would simplify the schema we use.
- Anything that adds network calls. There are no network calls today.

## Style

- 4-space indent, brace on same line, Apple's Swift API design guidelines.
- Keep files small and focused. If you find yourself adding a third
  responsibility to a file, split it.
- Errors propagate as `throws` or surface in the UI via the existing status
  enums. Don't `try?` away failures silently.

## License

By contributing you agree your work is licensed under the [MIT License](LICENSE).
