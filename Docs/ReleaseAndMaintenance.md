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

SwiftRip ships as a Developer ID signed and notarized DMG for distribution outside the Mac App Store.

Prerequisites:

- An Apple Developer Program membership.
- A valid `Developer ID Application` certificate installed in the login keychain.
- Bundled SwiftRipTools artifacts available under `SwiftRipTools/Artifacts/macos-arm64`.
- A notarytool credential stored in the keychain, preferably:

```sh
xcrun notarytool store-credentials "SwiftRip Notary" --apple-id "APPLE_ID_EMAIL" --team-id "TEAM_ID" --password "APP_SPECIFIC_PASSWORD"
```

Build, sign, package, notarize, staple, and verify the DMG:

```sh
Scripts/release-dmg.zsh --notary-profile "SwiftRip Notary"
```

For a local packaging check that does not contact Apple's notarization service, but still requires Developer ID signing:

```sh
Scripts/release-dmg.zsh --skip-notarization
```

The release script performs these checks:

- Builds a `Release` app with Developer ID signing and hardened runtime.
- Verifies the app signature with `codesign --verify --deep --strict`.
- Verifies `HandBrakeCLI` and `libdvdcss.2.dylib` nested signatures.
- Confirms the release app does not contain `com.apple.security.get-task-allow`.
- Confirms the release app keeps sandbox, user-selected file access, and app-scope bookmark entitlements.
- Confirms broad Movies access and the old `com.apple.digihub` temporary exception are absent.
- Creates and signs a DMG containing `SwiftRip.app` and an `/Applications` shortcut.
- Submits the DMG with `notarytool`, staples it, and assesses it with Gatekeeper.

## Bundled Tool Update Policy

SwiftRip should consume reproducible local artifacts from `SwiftRipTools`, not tools installed through Homebrew, MacPorts, `/usr/local`, or another developer's machine state.

To update HandBrakeCLI or libdvdcss:

1. Update the version inputs in the SwiftRipTools build scripts.
2. Run `SwiftRipTools/Scripts/bootstrap-tools.zsh --force`.
3. Confirm the HandBrake patch still applies cleanly.
4. Run `SwiftRipTools/Scripts/verify-swiftrip-tools.zsh`.
5. Run the app test suite.
6. Run the smoke test above with a real DVD.
7. Update bundled license notices if upstream license text or included components changed.

The expected HandBrake behavior is that bundled `HandBrakeCLI` loads `libdvdcss.2.dylib` from:

```text
@executable_path/../Frameworks/libdvdcss.2.dylib
```

Do not ship a CLI that falls back to `/usr/local/lib/libdvdcss.2.dylib` or relies on `/opt/local`.
