# SwiftRip Roadmap

## Completed

- Bundled `HandBrakeCLI` and `libdvdcss.2.dylib` inside the app.
- Added the SwiftRip HandBrake preset.
- Verified the bundled tools run without `/opt/local`, `/usr/local`, Homebrew, or MacPorts runtime dependencies.
- Added DVD volume detection for mounted discs with a `VIDEO_TS` folder.
- Added DVD folder normalization when selecting `VIDEO_TS` directly.
- Added sandbox-friendly DVD input access and output-folder bookmark handling.
- Added rip progress parsing and display.
- Added Stop behavior for active rips.
- Added cancellation cleanup for incomplete output files.
- Preserved completed output files and failed output files.
- Added detailed rip logs.
- Added an About window with bundled tool and license information.
- Added localized user-facing strings.
- Added tests for selection, preflight, progress parsing, rip lifecycle, cancellation cleanup, logging, bundled-tool integrity, and localization formatting.
- Added a Sparkle update feed.
- Added Developer ID ZIP release scripts with signing, notarization, stapling, Gatekeeper assessment, and Sparkle appcast generation.
- Split bundled-tool packaging into the public `SwiftRip-Tools` repository.
- Added public source-pin repositories for the shipped HandBrake and libdvdcss sources.
- Added scheduled upstream checks for HandBrake and libdvdcss updates.
- Added branch and tag protection for release-critical SwiftRip repositories.
- Verified local app builds, SwiftRip-Tools CI, and GitHub Actions release builds.
- Published signed, notarized releases with Sparkle updates.
- Added release checklist, support guidance, and security reporting policy.

## In Progress

- Keep the app, tool packages, source pins, and release documentation aligned as maintenance releases ship.
- Watch real-world install, update, sandbox, and DVD read behavior after public releases.

## Next

- Improve failure messages for unusual DVD structures and HandBrake errors.
- Expand real-disc smoke coverage as more discs and drives are available.
- Keep the public source-offer trail matched to every shipped binary.

## Later

- Explore better title/audio/subtitle selection.
- Consider more presets or user-selectable encoding options.
- Consider a first-run setup/check screen for bundled tools and license notes.
- Explore a possible 2.0 architecture that replaces `HandBrakeCLI` with a native worker built around FFmpeg and VideoLAN libraries.
