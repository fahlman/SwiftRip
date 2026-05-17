# SwiftRipTools Artifact Layout

SwiftRipTools produces finished command-line artifacts for SwiftRip.app.

## Final artifact output

SwiftRipTools/Artifacts/macos-universal/
  HandBrakeCLI
  libdvdcss.2.dylib

## Intended app bundle layout

SwiftRip.app/
  Contents/
    MacOS/
      SwiftRip
      HandBrakeCLI
    Frameworks/
      libdvdcss.2.dylib
    Resources/
      SwiftRip.json

## Rules

- SwiftRip.app must not rely on Homebrew, MacPorts, /usr/local/lib, /opt/local/lib, or user-installed HandBrake.
- SwiftRip.app should consume artifacts produced by SwiftRipTools.
- Tool artifacts should be reproducible.
- Large generated artifacts should not be committed directly to Git.
- The app and bundled tools must be signed together.
