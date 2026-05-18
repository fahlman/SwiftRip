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

## In Progress

- Add an Eject primary-button state after a successful rip.

## Next

- Improve output destination selection and completed-file surfacing.
- Add a rip-complete notification.
- Continue small UI polish around the main window and About window.
- Review distribution and license requirements before sharing builds outside development.

## Later

- Explore better title/audio/subtitle selection.
- Consider more presets or user-selectable encoding options.
- Consider a first-run setup/check screen for bundled tools and license notes.
