# Bundled Tool Maintenance

SwiftRip consumes reproducible artifacts from the separate `fahlman/SwiftRip-Tools` repository. The app repository should not depend on tools installed through Homebrew, MacPorts, `/usr/local`, `/opt/local`, or another developer's machine state.

For public app releases, use the root [`RELEASE_CHECKLIST.md`](../RELEASE_CHECKLIST.md). This file covers only the bundled HandBrakeCLI and libdvdcss maintenance policy.

## Runtime Contract

The intended app bundle model is documented in [`THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md). At runtime, SwiftRip should use:

- `Contents/MacOS/HandBrakeCLI`
- `Contents/Frameworks/libdvdcss.2.dylib`
- `Contents/Resources/SwiftRip.json`

The expected HandBrake behavior is that bundled `HandBrakeCLI` loads `libdvdcss.2.dylib` from:

```text
@executable_path/../Frameworks/libdvdcss.2.dylib
```

Do not ship a CLI that falls back to `/usr/local/lib/libdvdcss.2.dylib`, `/opt/local/lib/libdvdcss.2.dylib`, or another user-installed path.

## Artifact Manifests

SwiftRip-Tools packages are pinned by architecture:

- `SwiftRip-Tools/Manifest/swiftrip-tools.json` for Apple Silicon.
- `SwiftRip-Tools/Manifest/swiftrip-tools-x86_64.json` for Intel.

Those manifests are the app repository's contract with SwiftRip-Tools. The current shipped third-party component versions belong in [`THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md) and [`SOURCE_OFFER.md`](../SOURCE_OFFER.md), not in this maintenance note.

## Updating HandBrakeCLI or libdvdcss

The SwiftRip-Tools upstream workflow updates the bundled tools automatically:

1. Detect the new HandBrake or libdvdcss upstream release.
2. Create the matching immutable SwiftRip source tags, applying the single HandBrake app-bundle patch automatically.
3. Build and verify Apple Silicon and Intel artifacts.
4. Publish the packages to the SwiftRip-Tools GitHub release.
5. Dispatch the exact tool revision to SwiftRip.
6. Update the manifest copies, provenance, and app version in SwiftRip.
7. Push a new SwiftRip version tag for the GitHub release workflow.
8. Run the app test suite and signed real-DVD smoke test as part of release verification.
9. Update bundled license notices if upstream license text or included components changed.

SwiftRip releases intentionally consume the exact tool revision delivered by the automatic update event; the app version tag is the release boundary.
