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

To update bundled tools:

1. Review the upstream update issue created by the SwiftRip-Tools scheduled check.
2. Sync the matching SwiftRip source pin repository: `SwiftRip-HandBrake` or `SwiftRip-libdvdcss`.
3. Create a new protected SwiftRip source tag for the chosen upstream version.
4. Update the version and commit pins in the SwiftRip-Tools repository build scripts.
5. Rebuild and package the Apple Silicon artifacts in the SwiftRip-Tools repository.
6. Rebuild and package the Intel artifacts in the SwiftRip-Tools repository if updating Intel support.
7. Confirm the HandBrake patch still applies cleanly if HandBrake changed.
8. Publish the packages to the SwiftRip-Tools GitHub release.
9. Update the manifest copies in this repository if package names, URLs, versions, or checksums changed.
10. Run `SwiftRip-Tools/Scripts/fetch-swiftrip-tools.zsh` for Apple Silicon.
11. Run `SwiftRip-Tools/Scripts/fetch-swiftrip-tools.zsh --arch x86_64` for Intel.
12. Run the app test suite.
13. Run the signed real-DVD smoke test from [`RELEASE_CHECKLIST.md`](../RELEASE_CHECKLIST.md).
14. Update bundled license notices if upstream license text or included components changed.

Do not publish a SwiftRip app update merely because SwiftRip-Tools produced a new package. SwiftRip app releases should intentionally select the tool package versions they consume.
