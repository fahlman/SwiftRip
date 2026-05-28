# SwiftRip Roadmap

## Completed

- Bundled architecture-specific `HandBrakeCLI` and `libdvdcss.2.dylib` inside the app.
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
- Added architecture-specific Sparkle update feeds for Apple Silicon and Intel releases.
- Added Developer ID DMG release scripts with signing, notarization, stapling, Gatekeeper assessment, and Sparkle appcast generation.
- Split bundled-tool packaging into the public `SwiftRip-Tools` repository.
- Added public source-pin repositories for the shipped HandBrake and libdvdcss sources.
- Added scheduled upstream checks for HandBrake and libdvdcss updates.
- Added branch and tag protection for release-critical SwiftRip repositories.
- Verified local app builds, GitHub CI, SwiftRip-Tools CI, and Xcode Cloud archive builds.

## In Progress

- Validate the 1.0 release candidate path end to end.
- Keep the app, tool packages, source pins, and release documentation aligned as release artifacts are finalized.

## Next

- Build final signed and notarized Apple Silicon and Intel DMGs.
- Run the full real-DVD smoke test against the final signed/notarized build.
- Verify Sparkle updates from the previous public release to the final 1.0 build.
- Publish the final GitHub release assets and appcasts.
- Confirm the public source-offer trail points to the exact source, scripts, manifests, and checksums used for the release.

## Later

- Explore better title/audio/subtitle selection.
- Consider more presets or user-selectable encoding options.
- Consider a first-run setup/check screen for bundled tools and license notes.
- Explore a possible 2.0 architecture that replaces `HandBrakeCLI` with a native worker built around FFmpeg and VideoLAN libraries.
