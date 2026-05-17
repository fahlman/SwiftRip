# Source Offer

SwiftRip is free software distributed under the GNU General Public License version 2. See `LICENSE` for the full license text.

This file explains how SwiftRip intends to provide corresponding source code for SwiftRip itself and for GPL-covered third-party components that SwiftRip builds, bundles, or invokes.

## SwiftRip source code

The SwiftRip application source code is available from the SwiftRip project repository:

```text
https://github.com/fahlman/SwiftRip
```

The repository is intended to include the Swift application source, Xcode project files, configuration files, build scripts, legal notices, and documentation needed to inspect, modify, and rebuild SwiftRip.

## Third-party source code

SwiftRip may build, bundle, or invoke third-party GPL components, including HandBrakeCLI and libdvdcss.

Major third-party components are listed in `THIRD_PARTY_NOTICES.md`.

## libdvdcss source and build process

SwiftRipTools currently builds libdvdcss from VideoLAN source.

The build script is:

```text
SwiftRipTools/Scripts/build-libdvdcss.zsh
```

The top-level tools build script is:

```text
SwiftRipTools/Scripts/build-swiftrip-tools.zsh
```

The intended generated artifact is:

```text
SwiftRipTools/Artifacts/macos-universal/libdvdcss.2.dylib
```

Generated source archives, extracted source trees, build folders, and binary artifacts are intentionally not committed to Git. They are produced locally by the build scripts.

## HandBrakeCLI source and build process

SwiftRip intends to use HandBrakeCLI as the encoding backend.

The HandBrakeCLI build/rebuild process is still under development for this project. Before distributing a SwiftRip binary that includes HandBrakeCLI, the project should document the exact HandBrake source version, patch set if any, build script, configuration, and resulting bundled artifact.

Until that process is finalized, SwiftRip binary distribution should be treated as incomplete from a GPL source-compliance standpoint.

## Binary distribution requirement

If SwiftRip is distributed in binary form with bundled GPL-covered tools or libraries, recipients must be able to obtain the corresponding source code for the exact shipped binaries.

The preferred approach for this project is to make the corresponding source and build scripts available through the public SwiftRip repository. If binary releases are published separately, each release should identify the exact source revision and third-party component versions used to build it.

## Written offer fallback

If a SwiftRip binary is distributed without complete corresponding source accompanying it, the distributor should provide a written GPL source offer valid for the period required by the GPL.

That offer should provide the complete corresponding machine-readable source code for SwiftRip and bundled GPL-covered components, including build scripts and any project-specific modifications.

## No warranty

SwiftRip and its bundled GPL-covered components are provided without warranty. See `LICENSE` for the full GPLv2 warranty disclaimer.
