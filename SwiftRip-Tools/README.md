# SwiftRip-Tools Consumer Files

SwiftRip's tool build, package, publish scripts, patches, and release assets live in:

```text
https://github.com/fahlman/SwiftRip-Tools
```

This directory intentionally keeps only the small consumer-side contract needed by SwiftRip.app:

- pinned package manifests under `Manifest/`
- the artifact fetch script under `Scripts/`
- the artifact verifier used by local release scripts and CI

Xcode Cloud and clean local archive builds restore `HandBrakeCLI` and `libdvdcss.2.dylib` from the checksummed packages referenced in the manifests.
