# Contributing

All contributors are welcome. Please use issues and pull requests to contribute to the project. And update [CHANGELOG.md](CHANGELOG.md) when committing.

## Release process

1. Confirm the build is [passing in GitHub Actions](https://github.com/fulldecent/FDWaveformView/actions)
2. Push a release commit
   1. Create a new Main section at the top of [CHANGELOG.md](CHANGELOG.md)
   2. Rename the old Main section like:

      ```markdown
      ## [5.1.1](https://github.com/fulldecent/FDWaveformView/releases/tag/5.1.1)

      Released on 2025-12-06.
      ```

3. Create a GitHub release
   1. Tag the release (like `5.1.1`)
   2. Paste notes from [CHANGELOG.md](CHANGELOG.md)

## Maintenance

Do this every quarter or so.

1. Review the Xcode pin in [.github/workflows/ci.yml](.github/workflows/ci.yml). The job uses the `macos-15` runner and `/Applications/Xcode_16.4.app`, then tests on an iPhone 16 simulator running iOS 18.5. Those are the versions listed for that image in the [macOS 15 runner readme](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-arm64-Readme.md). `macos-latest` is the macOS 26 image and does not install Xcode 16.4, so a workflow that selects `macos-latest` and then looks up a simulator will fail before it compiles this package.
2. Review [actions/checkout](https://github.com/actions/checkout) and move the `uses:` pin forward when a new major version is safe. The workflow currently uses `actions/checkout@v4`.
