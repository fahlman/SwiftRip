# GitHub Actions Release Publishing

SwiftRip is distributed directly from GitHub as a signed and notarized macOS ZIP. The release pipeline is entirely GitHub-based:

1. The SwiftRip-Tools automation publishes updated HandBrakeCLI and libdvdcss packages.
2. SwiftRip consumes the exact tool manifests and pushes a new `vVERSION` tag.
3. The tag workflow builds the universal app on a macOS GitHub runner.
4. The workflow signs the app and bundled tools with Developer ID, submits the ZIP to Apple's notary service, staples the ticket, publishes the GitHub release, and updates the Sparkle appcast on `gh-pages`.

## Required GitHub secrets

SwiftRip-Tools requires `SWIFTRIP_AUTOMATION_TOKEN`, with write access to SwiftRip-Tools, SwiftRip-HandBrake, SwiftRip-libdvdcss, and repository dispatches to SwiftRip.

SwiftRip requires:

- `SWIFTRIP_AUTOMATION_TOKEN` — pushes the automated manifest/version commit and release tag.
- `SWIFTRIP_RELEASE_TOKEN` — creates the GitHub release and updates `gh-pages`.
- `DEVELOPER_ID_APPLICATION_P12_BASE64` — base64-encoded Developer ID Application certificate export.
- `DEVELOPER_ID_APPLICATION_P12_PASSWORD` — password for that certificate export.
- `SWIFTRIP_KEYCHAIN_PASSWORD` — temporary CI keychain password.
- `SWIFTRIP_NOTARY_APPLE_ID` — Apple ID used for notarization.
- `SWIFTRIP_NOTARY_PASSWORD` — app-specific password for notarization.
- `SWIFTRIP_SPARKLE_ED_KEY` — Sparkle signing key.

The repository's existing release scripts perform the build, signing, notarization, ZIP packaging, GitHub release upload, and appcast publication. The workflow does not require a Mac App Store listing or another release service.

## Release trigger

The release workflow runs only for tags matching `v*`. Ordinary pushes and pull requests do not publish releases.
