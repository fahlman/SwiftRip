# SwiftRip

[![CI](https://github.com/fahlman/SwiftRip/actions/workflows/ci.yml/badge.svg)](https://github.com/fahlman/SwiftRip/actions/workflows/ci.yml)

SwiftRip is a small macOS app for ripping DVDs to `.m4v` files.

It bundles the required ripping tools, checks that they are present before starting, shows progress while ripping, and can safely stop an active rip.

## Current features

- Detects mounted DVD volumes with a `VIDEO_TS` folder.
- Runs bundled `HandBrakeCLI` with the SwiftRip preset.
- Uses bundled `libdvdcss.2.dylib` for encrypted DVD support.
- Shows rip progress.
- Stops an active rip and deletes incomplete output.
- Preserves completed and failed output files.
- Writes rip logs.
- Includes bundled tool license information in the About window.
- Ships architecture-specific signed/notarized DMGs with Sparkle update feeds.
- Supports localized user-facing strings.

## Tests

The unit test suite covers DVD selection, HandBrake arguments, progress parsing, preflight checks, rip lifecycle behavior, cancellation cleanup, logging, and localization formatting. CI runs those unit tests; macOS UI tests remain available for local interactive checks.

## Project docs

- [Release checklist](RELEASE_CHECKLIST.md)
- [Release and maintenance notes](Docs/ReleaseAndMaintenance.md)
- [Security policy](SECURITY.md)
- [Support guide](SUPPORT.md)
- [Legal notes](LEGAL.md)
- [Source offer](SOURCE_OFFER.md)
- [Third-party notices](THIRD_PARTY_NOTICES.md)

## License notes

SwiftRip includes bundled third-party tools. Review the included COPYING files and license obligations before distributing the app.
