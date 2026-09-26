# SwiftRip — Repository Instructions

Read the shared `AGENTS.md` first. `README.md` is the product overview;
`RELEASE_CHECKLIST.md` owns the public-release process.

## Application and tool ownership

- SwiftRip is a macOS DVD-to-M4V app. It detects VIDEO_TS volumes, runs bundled
  HandBrakeCLI, presents progress, and records logs.
- Preserve rip lifecycle semantics: cancellation deletes incomplete output;
  completed and failed output and diagnostic logs remain available.
- Bundled tool maintenance belongs to the SwiftRip-Tools and SwiftRip-HandBrake
  repositories. Follow `Docs/BundledTools.md` when consuming updates; do not patch
  downloaded binaries or introduce undeclared Homebrew/MacPorts runtime libraries.
- Tool manifests, package checksums, `THIRD_PARTY_NOTICES.md`, `SOURCE_OFFER.md`,
  and matching source tags must describe the binaries actually shipped.
- Read `SECURITY.md` for vulnerability reporting and `LEGAL.md` for the project's
  existing distribution constraints. Preserve bundled notices and source offers.

## Project and verification

- `SwiftRip.xcodeproj` uses scheme `SwiftRip`; unit tests are `SwiftRipTests`.
- `Scripts/ci-validate-repo.zsh` is the repository validation command. The release
  checklist documents tool restoration and this unit-test command:

  ```sh
  SWIFTRIP_SUPPRESS_FIRST_RUN_OUTPUT_PROMPT=1 xcodebuild test -project SwiftRip.xcodeproj -scheme SwiftRip -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO -only-testing:SwiftRipTests
  ```

- Interactive UI, actual DVDs, sandbox permissions, signing, and updates need
  the separate smoke checks in `RELEASE_CHECKLIST.md` when relevant. A successful
  unit test does not establish those checks.

## Distribution

- Follow `Docs/GitHubActionsRelease.md` for the dedicated tag-triggered publisher.
  Public releases are signed, notarized universal ZIPs with Sparkle appcasts.
- Increment Sparkle build numbers; never reuse a published build number. Pin
  Sparkle and tool versions and validate both architectures when affected.
- Preserve source tags, tool packages, and release evidence for shipped builds.
  Release scripts and tags publish artifacts and are not routine local checks.

## Toolchain and platforms

Settings inspected on 2026-09-25 in `SwiftRip.xcodeproj/project.pbxproj`.

- Selected local tools: Xcode 27.0 (`27A266a`), Apple Swift 6.4
  (`swiftlang-6.4.0.34.1`). These exact versions are not pinned by the project.
- Swift language mode: 6.0 (`SWIFT_VERSION`) for all Swift targets.
- SDK: `SDKROOT = macosx`, with no SDK version pin; the selected macOS SDK is 27.0.
- Deployment targets: macOS 15.7 for the app and both test targets.

The selected local tools are a dated snapshot. Existing project settings describe
current configuration; they do not override the shared latest-stable policy.
Handle upgrades as separate tasks.
