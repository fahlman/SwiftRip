# Security Policy

SwiftRip is a sandboxed macOS app that bundles command-line ripping tools and publishes signed, notarized, architecture-specific DMGs with Sparkle update feeds. Security reports are welcome and should be handled privately until there is a fix or a clear mitigation.

The release checklist is the source of truth for release artifact verification. This policy focuses on vulnerability reporting, security expectations, and secret handling.

## Supported Versions

| Version | Security support |
| --- | --- |
| Latest public release | Supported |
| Current `main` branch | Supported before the next release |
| Older public releases | Best effort only |

If a security fix is needed, the preferred response is a new signed and notarized release with a higher Sparkle build number.

## Reporting a Vulnerability

Please do not open a public issue with exploit details.

Use GitHub's private vulnerability reporting for this repository if it is available. If it is not available, contact the maintainer privately through the maintainer information shown on GitHub and share only the details needed to start triage.

Helpful report details:

- SwiftRip version and build number.
- macOS version.
- Apple Silicon or Intel.
- Whether the app came from a GitHub release, Sparkle update, local build, or Xcode.
- Exact steps to reproduce.
- Expected and actual behavior.
- Security impact.
- Relevant logs with personal paths, disc names, and account details redacted.

Do not attach copyrighted video, decrypted disc contents, credentials, private keys, Apple account details, or Sparkle signing keys.

## Security-Relevant Areas

Reports are especially useful for:

- Sparkle update integrity problems.
- Code signing, notarization, stapling, or Gatekeeper bypasses.
- Sandbox or security-scoped bookmark mistakes.
- Unexpected broad file access.
- Arbitrary file read, write, overwrite, or deletion.
- Command-line argument injection into bundled tools.
- Unsafe parsing of HandBrake output, DVD metadata, paths, or logs.
- Bundled tool artifact checksum or source-provenance mismatches.
- Secrets accidentally written to logs, scripts, release artifacts, or Git history.

## Project Security Model

SwiftRip should:

- Run as a macOS sandboxed app.
- Use user-selected file access and app-scoped security bookmarks.
- Avoid broad folder entitlements such as unrestricted Movies access.
- Bundle the exact `HandBrakeCLI` and `libdvdcss.2.dylib` artifacts selected by the repository manifests.
- Avoid Homebrew, MacPorts, `/usr/local`, and `/opt/local` runtime dependencies.
- Sign bundled executable code and the app bundle with Developer ID for release.
- Notarize, staple, and Gatekeeper-assess release DMGs.
- Publish Sparkle appcasts for Apple Silicon and Intel separately.
- Keep source, build scripts, notices, and source-offer documentation aligned with shipped binaries.

DVD input, disc metadata, mounted volume names, file paths, HandBrake output, and downloaded update metadata should all be treated as untrusted input.

## Secrets and Credentials

Secrets should not be committed to the repository. This includes:

- Apple ID passwords and app-specific passwords.
- `notarytool` credentials.
- Developer ID certificate private keys.
- GitHub tokens.
- Sparkle private keys.

Release credentials should be stored in the Keychain and referenced by profile. Scripts should not accept Apple account passwords on the command line.

## Out of Scope

The following are not handled as security vulnerabilities by themselves:

- Requests for legal advice.
- Requests to copy media without the legal right to do so.
- General HandBrake encoding preferences.
- DVD drive hardware compatibility issues without a security impact.
- Reports for modified local builds that do not reproduce with the official release or current source.

## Disclosure

The preferred disclosure flow is:

1. Private report.
2. Maintainer acknowledgement.
3. Reproduction and impact review.
4. Fix on a private or minimally disclosed branch when practical.
5. Signed and notarized release.
6. Public issue, release note, or advisory with appropriate detail.
