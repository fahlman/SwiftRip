# SwiftRip Release Checklist

Use this checklist for every public SwiftRip release, including hotfixes. Stop the release if any item is uncertain enough that future-you would not trust the artifact.

## 1. Confirm the Release Scope

- Confirm the user-facing version to ship.
- Confirm `CURRENT_PROJECT_VERSION` will be higher than every previously published Sparkle build.
- Confirm the release is meant to be public, not a local packaging test.
- Confirm the release still targets the intended minimum macOS version, currently macOS 15.7.
- Confirm any user-facing changes are reflected in `README.md`, `ROADMAP.md`, or release notes as needed.
- Confirm third-party tool versions are the intended pinned versions in `THIRD_PARTY_NOTICES.md`, `SOURCE_OFFER.md`, and `SwiftRip-Tools/Manifest/`.

## 2. Check Repository State

- Work from `main` for a public release.
- Pull the latest remote state.
- Confirm `git status --short --branch` is clean before starting release packaging.
- Confirm GitHub CI is passing on the release commit.
- Confirm Xcode Cloud is passing on the release commit.
- Run repository validation:

```sh
Scripts/ci-validate-repo.zsh
```

## 3. Run Local Tests

- Restore bundled tool artifacts for Apple Silicon:

```sh
SwiftRip-Tools/Scripts/fetch-swiftrip-tools.zsh
```

- Run the unit test suite:

```sh
SWIFTRIP_SUPPRESS_FIRST_RUN_OUTPUT_PROMPT=1 xcodebuild test -project SwiftRip.xcodeproj -scheme SwiftRip -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO -only-testing:SwiftRipTests
```

- If the release touches Intel support, restore Intel bundled tools too:

```sh
SwiftRip-Tools/Scripts/fetch-swiftrip-tools.zsh --arch x86_64
```

## 4. Run the Real App Smoke Test

Run this against a signed release build whenever changes touch ripping, bundled tools, sandbox access, signing, Sparkle, or app lifecycle behavior.

- Launch SwiftRip from a clean install with no saved output folder bookmark.
- Choose an output folder when prompted and confirm Settings shows the same folder.
- Relaunch SwiftRip and confirm the output folder bookmark is reused without a new prompt.
- Select a mounted DVD and confirm macOS asks for removable volume access when expected.
- Rip an encrypted DVD and confirm the output appears in the selected folder.
- Rip a non-encrypted DVD and confirm the output appears in the selected folder.
- During an active rip, reveal the log and confirm HandBrake output is being written live.
- Cancel an active rip and confirm the incomplete output file is deleted.
- Force a rip failure and confirm the failed output and log are preserved for inspection.
- Confirm Reveal Output and Reveal Log work after success and failure.
- Confirm auto-eject runs after a successful rip when enabled, and does not run after failure.
- Confirm the app does not require Homebrew, MacPorts, `/usr/local`, or `/opt/local` runtime libraries.

## 5. Version the Release

- Update `MARKETING_VERSION` for the public version.
- Increment `CURRENT_PROJECT_VERSION` for Sparkle. Never reuse a Sparkle build number.
- Commit and push the version bump.
- Wait for GitHub CI and Xcode Cloud to pass on the exact release commit.

## 6. Build and Publish Release Artifacts

Prerequisites:

- `Developer ID Application` certificate installed in the login keychain.
- Notary credentials stored in the keychain as `SwiftRip Notary`.
- GitHub CLI authenticated with release upload permission.
- Sparkle `generate_appcast` available from Xcode's resolved package artifacts.
- Apple Silicon and Intel SwiftRip-Tools packages available from the pinned manifests.

Build, sign, notarize, staple, upload both architecture-specific DMGs, generate Sparkle appcasts, and publish appcasts to GitHub Pages:

```sh
Scripts/release-sparkle.zsh --notary-profile "SwiftRip Notary"
```

The expected public artifacts are:

- `SwiftRip-VERSION-arm64.dmg`
- `SwiftRip-VERSION-x86_64.dmg`
- `https://github.com/fahlman/SwiftRip/releases/tag/vVERSION`
- `https://fahlman.github.io/SwiftRip/appcast-arm64.xml`
- `https://fahlman.github.io/SwiftRip/appcast-x86_64.xml`

## 7. Verify Published Artifacts

- Confirm the GitHub release points at the intended commit.
- Confirm both DMGs are attached to the release.
- Confirm both generated release manifests exist in `dist/VERSION/`.
- Confirm both appcasts reference the new version and the correct architecture-specific DMG.
- Download each published DMG from GitHub, mount it, and launch the app.
- Confirm Gatekeeper accepts each downloaded DMG on a clean machine or clean user account.
- Confirm Sparkle updates from the previous public release to the new release.
- Test Sparkle on Apple Silicon for the `arm64` feed.
- Test Sparkle on Intel hardware, or an appropriate Intel test environment, for the `x86_64` feed.

## 8. Check Source and License Availability

- Confirm `THIRD_PARTY_NOTICES.md` lists the exact HandBrake and libdvdcss versions shipped.
- Confirm `SOURCE_OFFER.md` points to the matching SwiftRip, SwiftRip-Tools, SwiftRip-HandBrake, and SwiftRip-libdvdcss sources.
- Confirm SwiftRip-Tools release assets and checksums match the manifests consumed by this repository.
- Do not delete release-critical source tags, tool packages, or source-offer documentation for shipped binaries.

## 9. After Release

- Confirm GitHub CI remains green after the release commit and appcast publishing.
- Confirm Xcode Cloud remains green after the release commit.
- Watch GitHub issues for install, update, sandbox, and DVD read failures.
- If a serious release problem appears, prefer publishing a fixed release with a higher `CURRENT_PROJECT_VERSION`.

## Broken Release Response

If a published update should no longer be offered:

- Preserve the released source, tags, and license trail.
- Remove or replace the bad entry from the published Sparkle appcast.
- Mark the GitHub release as a prerelease or add a warning to the release notes if users should avoid it.
- Publish a fixed build with a higher `CURRENT_PROJECT_VERSION` as soon as practical.
- Do not silently replace a public binary unless the replacement has the same source, same version, and same intended behavior.
