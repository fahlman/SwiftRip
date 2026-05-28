# Third-Party Notices

SwiftRip includes, builds, bundles, or invokes third-party software components. Those components are copyrighted by their respective authors and are licensed under their own license terms.

This file is intended to document the major third-party components used by SwiftRip. It may not be exhaustive yet.

## HandBrake / HandBrakeCLI

- Component: HandBrakeCLI
- Project: HandBrake
- Website: https://handbrake.fr/
- Source: https://github.com/HandBrake/HandBrake
- SwiftRip source pin: https://github.com/fahlman/SwiftRip-HandBrake/tree/swiftrip-handbrake-1.11.1
- Current SwiftRip-Tools target version: 1.11.1
- License: GNU General Public License version 2
- Use in SwiftRip: SwiftRip invokes HandBrakeCLI to scan and encode DVD/video sources.

HandBrakeCLI is not authored by the SwiftRip project. HandBrake and HandBrakeCLI remain under the copyright and license notices of the HandBrake project and its contributors.

When SwiftRip distributes a bundled HandBrakeCLI binary, SwiftRip must also provide the corresponding source code or a valid GPL source offer for the exact bundled version/build.

## libdvdcss

- Component: libdvdcss
- Project: VideoLAN libdvdcss
- Website: https://www.videolan.org/developers/libdvdcss.html
- Source: https://code.videolan.org/videolan/libdvdcss
- SwiftRip source pin: https://github.com/fahlman/SwiftRip-libdvdcss/tree/swiftrip-libdvdcss-1.5.0
- Current SwiftRip-Tools target version: 1.5.0
- License: GNU General Public License
- Use in SwiftRip: SwiftRip-Tools builds libdvdcss so DVD CSS access can be provided by a bundled app-local dynamic library instead of relying on Homebrew, MacPorts, `/usr/local/lib`, `/opt/local/lib`, or other user-installed runtime libraries.

libdvdcss is not authored by the SwiftRip project. libdvdcss remains under the copyright and license notices of the VideoLAN project and its contributors.

When SwiftRip distributes a bundled libdvdcss binary, SwiftRip must also provide the corresponding source code or a valid GPL source offer for the exact bundled version/build.

## Apple system frameworks and tools

SwiftRip is a macOS application built with Apple development tools and links against Apple-provided system frameworks made available as part of macOS and Xcode.

Apple system libraries and frameworks are not bundled by SwiftRip as third-party GPL components. They remain subject to Apple's applicable license terms.

## Build tools

SwiftRip-Tools may use developer-installed build tools such as:

- clang / Xcode command-line tools
- Meson
- Ninja
- Git
- curl
- tar
- lipo
- install_name_tool
- codesign

These tools are used to build artifacts during development. They are not intended to be runtime dependencies of SwiftRip.app.

## Runtime dependency rule

SwiftRip.app should not require users to install HandBrake, libdvdcss, Homebrew, MacPorts, or other external runtime packages.

The intended app bundle model is:

```text
SwiftRip.app/
  Contents/
    MacOS/
      SwiftRip
      HandBrakeCLI
    Frameworks/
      libdvdcss.2.dylib
    Resources/
      SwiftRip.json
```

The bundled tools and libraries should be signed together with the app before distribution.

## Source availability

See `SOURCE_OFFER.md` for source availability and rebuild information.
