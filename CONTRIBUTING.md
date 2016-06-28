# Contributing

All contributors are welcome. Please use issues and pull requests to contribute to the project. And update [CHANGELOG.md](CHANGELOG.md) when committing.

# Release Process

1. Confirm the build is passing in travis
   1. This automatically checks the pod file is building
2. Create a release commit, see [prior releases](https://github.com/fulldecent/FDWaveformView/releases) for an example
   1. Update the change log to label the latest improvements under the new version name
   2. Update the podspec version number
3. Tag the release in GitHub
   1. Create the release commit
   2. Create the release with notes from the change log
3. Push the podspec to cocoapods
   1. `pod trunk push`
4. Create Carthage binaries
   1. `carthage build --no-skip-current`
   2. `carthage archive FDWaveformView`
   3. Add to the GitHub release
