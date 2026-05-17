# SwiftRip Roadmap

## Completed Milestones

### Bundled ARM64 DVD ripping tools verified

SwiftRip now builds as an ARM64-only macOS app and bundles its required ripping tools inside the app bundle.

Verified:
- `HandBrakeCLI` is bundled in `Contents/MacOS`
- `libdvdcss.2.dylib` is bundled in `Contents/Frameworks`
- both bundled tools are ARM64
- no `/opt/local` runtime dependencies are present
- DVD ripping works from the app workflow
- disc/rip button icon states are working

## Next Up

- Improve rip progress presentation and status messages.
- Add safer handling for failed or interrupted rips.
- Decide how completed output files should be surfaced to the user.
- Continue UI polish after the core ripping workflow remains stable.
