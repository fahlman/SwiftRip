# SwiftRipTools

SwiftRipTools is the separate build/package workspace for the command-line tools used by SwiftRip.app.

Its job is to produce known-good, signed, app-bundled artifacts such as:

- HandBrakeCLI
- libdvdcss.2.dylib
- any required runtime support files

SwiftRip.app should consume finished artifacts from this workspace rather than relying on Homebrew, MacPorts, /usr/local/lib, or manually installed tools.
