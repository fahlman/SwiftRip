# Release and Maintenance

## Smoke Test

Run this checklist after changes that touch ripping, bundled tools, sandbox access, signing, or app lifecycle behavior.

- Launch SwiftRip from a clean install with no saved output folder bookmark.
- Choose `~/Movies` when prompted and confirm Settings shows the same output folder.
- Relaunch SwiftRip and confirm it does not ask for the output folder again.
- Rip an encrypted DVD and confirm the output appears in the selected folder.
- Rip a non-encrypted DVD and confirm the output appears in the selected folder.
- During an active rip, reveal the log and confirm HandBrake output is being written live.
- Cancel an active rip and confirm the incomplete output file is deleted.
- Force a rip failure and confirm the failed output and log are preserved for inspection.
- Confirm Reveal Output and Reveal Log work after success and failure.
- Confirm auto-eject works after a successful rip when enabled, and does not run after failure.

## Release Track

SwiftRip is not intended to stay local-only. Release builds should use:

- Developer ID signing once an Apple Developer account is available.
- Notarization before distributing outside local development machines.
- A documented release artifact, separate from local Debug builds.

## DMG Release Packaging

SwiftRip ships as Developer ID signed and notarized DMGs for distribution outside the Mac App Store.
Release artifacts are architecture-specific because the bundled SwiftRip-Tools artifacts are architecture-specific.

Prerequisites:

- An Apple Developer Program membership.
- A valid `Developer ID Application` certificate installed in the login keychain.
- Bundled SwiftRip-Tools artifacts available under `SwiftRip-Tools/Artifacts/macos-arm64`.
- For Intel releases, bundled SwiftRip-Tools artifacts available under `SwiftRip-Tools/Artifacts/macos-x86_64`.
- A notarytool credential stored in the keychain, preferably:

```sh
xcrun notarytool store-credentials "SwiftRip Notary" --apple-id "APPLE_ID_EMAIL" --team-id "TEAM_ID"
```

Enter the app-specific password at the secure prompt rather than passing it on the command line.
The release scripts intentionally require this Keychain profile and do not accept Apple ID passwords as command-line arguments.

Build, sign, package, notarize, staple, and verify an Apple Silicon DMG:

```sh
Scripts/release-dmg.zsh --arch arm64 --notary-profile "SwiftRip Notary"
```

Build, sign, package, notarize, staple, and verify an Intel DMG:

```sh
SwiftRip-Tools/Scripts/fetch-swiftrip-tools.zsh --arch x86_64
Scripts/release-dmg.zsh --arch x86_64 --notary-profile "SwiftRip Notary"
```

Build both architecture-specific DMGs, upload them to GitHub, generate Sparkle
appcasts, and publish those appcasts to GitHub Pages:

```sh
Scripts/release-sparkle.zsh --notary-profile "SwiftRip Notary"
```

By default, the Sparkle release script reads `MARKETING_VERSION`, creates or
updates tag `vVERSION`, uploads `SwiftRip-VERSION-arm64.dmg` and
`SwiftRip-VERSION-x86_64.dmg`, and publishes:

```text
https://fahlman.github.io/SwiftRip/appcast-arm64.xml
https://fahlman.github.io/SwiftRip/appcast-x86_64.xml
```

For a local packaging check that does not contact Apple's notarization service, but still requires Developer ID signing:

```sh
Scripts/release-dmg.zsh --arch arm64 --skip-notarization
```

The release script performs these checks:

- Builds a single-architecture `Release` app in a temporary work directory.
- Signs bundled executable code and the app bundle with Developer ID, hardened runtime, and secure timestamps.
- Verifies the app signature with `codesign --verify --deep --strict`.
- Confirms the app executable architecture matches the bundled SwiftRip-Tools artifacts.
- Verifies `HandBrakeCLI` and `libdvdcss.2.dylib` nested signatures.
- Confirms the release app does not contain `com.apple.security.get-task-allow`.
- Confirms the release app keeps sandbox, user-selected file access, and app-scope bookmark entitlements.
- Confirms broad Movies access and the old `com.apple.digihub` temporary exception are absent.
- Creates and signs a DMG containing `SwiftRip.app` and an `/Applications` shortcut.
- Submits the DMG with `notarytool`, staples it, and assesses it with Gatekeeper.

The Sparkle release script adds these checks and publishing steps:

- Builds both `arm64` and `x86_64` release DMGs through `release-dmg.zsh`.
- Uploads both DMGs to a GitHub release.
- Runs Sparkle `generate_appcast` separately for each architecture.
- Publishes `appcast-arm64.xml` and `appcast-x86_64.xml` to the `gh-pages` branch.

## Bundled Tool Update Policy

SwiftRip should consume reproducible artifacts from the separate `fahlman/SwiftRip-Tools` repository, not tools installed through Homebrew, MacPorts, `/usr/local`, or another developer's machine state.

To update HandBrakeCLI or libdvdcss:

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
13. Run the smoke test above with a real DVD.
14. Update bundled license notices if upstream license text or included components changed.

SwiftRip-Tools packages are pinned by architecture:

- `SwiftRip-Tools/Manifest/swiftrip-tools.json` for Apple Silicon.
- `SwiftRip-Tools/Manifest/swiftrip-tools-x86_64.json` for Intel.

The expected HandBrake behavior is that bundled `HandBrakeCLI` loads `libdvdcss.2.dylib` from:

```text
@executable_path/../Frameworks/libdvdcss.2.dylib
```

Do not ship a CLI that falls back to `/usr/local/lib/libdvdcss.2.dylib` or relies on `/opt/local`.
