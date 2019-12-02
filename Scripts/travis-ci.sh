#!/bin/sh

EXAMPLE_SCHEME="iOS Example"
EXAMPLE_WORKSPACE="iOS Example/iOS Example.xcworkspace"
IOS_FRAMEWORK_SCHEME="FDWaveformView"

set -o pipefail
xcodebuild -version
xcodebuild -showsdks

if [ $RUN_TESTS == "YES" ]; then
    xcodebuild -scheme "$IOS_FRAMEWORK_SCHEME" -sdk "$iOS_SDK" -destination "name=$SIMULATOR_NAME" -configuration Debug ONLY_ACTIVE_ARCH=NO ENABLE_TESTABILITY=YES test | xcpretty;
else
    xcodebuild -scheme "$IOS_FRAMEWORK_SCHEME" -sdk "$iOS_SDK" -destination "name=$SIMULATOR_NAME" -configuration Debug ONLY_ACTIVE_ARCH=NO build | xcpretty;
fi

# Build Framework in Release and Run Tests if specified
if [ $RUN_TESTS == "YES" ]; then
    xcodebuild -scheme "$IOS_FRAMEWORK_SCHEME" -sdk "$iOS_SDK" -destination "name=$SIMULATOR_NAME" -configuration Release ONLY_ACTIVE_ARCH=NO ENABLE_TESTABILITY=YES test | xcpretty;
else
    xcodebuild -scheme "$IOS_FRAMEWORK_SCHEME" -sdk "$iOS_SDK" -destination "name=$SIMULATOR_NAME" -configuration Release ONLY_ACTIVE_ARCH=NO ENABLE_TESTABILITY=YES build | xcpretty;
fi

if [ $BUILD_EXAMPLE == "YES" ]; then
    xcodebuild -workspace "$EXAMPLE_WORKSPACE" -sdk "$iOS_SDK" -scheme "$EXAMPLE_SCHEME"  -destination "name=$SIMULATOR_NAME"  -configuration Debug ONLY_ACTIVE_ARCH=NO build | xcpretty;
fi

# Run `pod lib lint` if specified
if [ $POD_LINT == "YES" ]; then
    pod lib lint
fi

if [ $POD_QUALITY_CHECK == "YES" ]; then
    ruby Tests/CheckCocoaPodsQualityIndexes.rb
fi