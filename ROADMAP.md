# SwiftRip Roadmap

## Completed

- Bundled ARM64 `HandBrakeCLI` inside the app.
- Bundled ARM64 `libdvdcss.2.dylib` inside the app.
- Added the SwiftRip HandBrake preset.
- Verified the bundled tools run without `/opt/local` runtime dependencies.
- Added DVD volume detection for mounted discs with a `VIDEO_TS` folder.
- Added DVD folder normalization when selecting `VIDEO_TS` directly.
- Added rip progress parsing and display.
- Added Stop behavior for active rips.
- Added cancellation cleanup for incomplete output files.
- Preserved completed output files and failed output files.
- Added detailed rip logs.
- Added an About window with bundled tool and license information.
- Added localized user-facing strings.
- Added tests for selection, preflight, progress parsing, rip lifecycle, cancellation cleanup, logging, and localization formatting.
- Added architecture-specific Sparkle update feeds for Apple Silicon and Intel releases.

## In Progress

- Harden the 1.0 release path.

## Next

- Run the full 1.0 smoke test on signed/notarized Apple Silicon and Intel builds.
- Publish final appcasts and verify update behavior from the previous public release.
- Continue small UI polish around the main window and About window.

## Later

- Explore better title/audio/subtitle selection.
- Consider more presets or user-selectable encoding options.
- Consider a first-run setup/check screen for bundled tools and license notes.
