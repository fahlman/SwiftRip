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
- Supports localized user-facing strings.

## Tests

The test suite covers DVD selection, HandBrake arguments, progress parsing, preflight checks, rip lifecycle behavior, cancellation cleanup, logging, and localization formatting.

## Release and maintenance

See [Docs/ReleaseAndMaintenance.md](Docs/ReleaseAndMaintenance.md) for the smoke test checklist, signing release track, and bundled HandBrakeCLI/libdvdcss update policy.

## License notes

SwiftRip includes bundled third-party tools. Review the included COPYING files and license obligations before distributing the app.
