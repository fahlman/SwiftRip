# SwiftRip

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
- Ships a signed/notarized universal app ZIP with Sparkle updates.
- Supports localized user-facing strings.

## Tests

The unit test suite covers DVD selection, HandBrake arguments, progress parsing, preflight checks, rip lifecycle behavior, cancellation cleanup, logging, and localization formatting. GitHub Actions handles the automated macOS build and release workflow; macOS UI tests remain available for local interactive checks.

## Project docs

- [Release checklist](RELEASE_CHECKLIST.md)
- [Bundled tool maintenance](Docs/BundledTools.md)
- [GitHub Actions release publishing](Docs/GitHubActionsRelease.md)
- [Security policy](SECURITY.md)
- [Support guide](SUPPORT.md)
- [Legal notes](LEGAL.md)
- [Source offer](SOURCE_OFFER.md)
- [Third-party notices](THIRD_PARTY_NOTICES.md)

Process details intentionally live in one place: release steps in the release checklist, bundled tool updates in the bundled tool maintenance note, vulnerability handling in the security policy, and user support intake in the support guide.

## License notes

SwiftRip includes bundled third-party tools. Review the included COPYING files and license obligations before distributing the app.
