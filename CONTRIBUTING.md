# Contributing

All contributors are welcome. Please use issues and pull requests to contribute to the project. Commit messages use `fix:`, `feat:` or `BREAKING CHANGE:`. Release Please writes [CHANGELOG.md](CHANGELOG.md) from those messages.

## Release process

Merging the release pull request tags the release and publishes the GitHub Release. The settings that pull request needs are in [Releases](README.md#releases). Confirm the build is [passing in GitHub Actions](https://github.com/fulldecent/FDWaveformView/actions) before merging it.

Tags stay `5.1.1`, without a `v` prefix. That matches the tags already on this repository. [release-please-config.json](release-please-config.json) sets `include-v-in-tag` to false so Release Please finds tag `5.1.1`.

## Maintenance

Do this every quarter or so.

1. Review the Swift tools version in [Package.swift](Package.swift) and the runner in [.github/workflows/ci.yml](.github/workflows/ci.yml). The job uses the GitHub-hosted `xcode-27` image because a Swift tools version of 6.4 does not load on Xcode 26. The test destination is an iPhone 17 simulator on iOS 27.0, which that image lists for Xcode 27.0. `xcrun swift test` builds this package for macOS, and the sources import UIKit, so the workflow uses `xcodebuild` instead. The image contents are in the [Xcode 27 runner readme](https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md).
2. Review external actions in [.github/workflows](.github/workflows). The workflow currently uses `actions/checkout@v7` and `googleapis/release-please-action@v5`.
