fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build and upload to TestFlight.

Source-driven release detection: if Cathier.xcodeproj's MARKETING_VERSION

differs from the most recent release/* git tag, the developer bumped

intentionally — this run submits to App Store review instead of just

uploading to TestFlight. CI never writes pbxproj or pushes to main.

### ios bump

```sh
[bundle exec] fastlane ios bump
```

Bump MARKETING_VERSION locally (2.2 → 2.3, 2.9 → 3.0).

Run, commit Cathier.xcodeproj/project.pbxproj, push to main — the next

CI build will detect the change and submit it to App Store review.

### ios release

```sh
[bundle exec] fastlane ios release
```

Build, upload to TestFlight, and submit for App Store review

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
