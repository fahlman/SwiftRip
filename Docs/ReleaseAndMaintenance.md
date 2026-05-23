# Release and Maintenance

## Smoke Test

Run this checklist after changes that touch ripping, bundled tools, sandbox access, signing, Sparkle, or app lifecycle behavior.

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
- Sparkle for app updates.
- A documented release artifact, separate from local Debug builds.

Sparkle is linked into the app and SwiftRip exposes `Check for Updates...` in the app menu. The updater is intentionally disabled until both release build settings below are populated:

```text
SWIFTRIP_UPDATE_FEED_URL
SWIFTRIP_SPARKLE_PUBLIC_ED_KEY
```

Keep `SUEnableAutomaticChecks` and `SUAutomaticallyUpdate` disabled until the first public signed and notarized release is ready. The first public Sparkle feed should only contain Developer ID signed, notarized, Sparkle-signed artifacts. Before enabling public Sparkle updates, define the appcast location, signing keys, and rollback process. Keep Debug builds and release artifacts clearly separated so local tool experiments do not ship by accident.

The Sparkle private signing key must not be committed. Store it in a local keychain or release secret store, then use Sparkle's signing tools to sign the release archive and generate the appcast enclosure signature.

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
