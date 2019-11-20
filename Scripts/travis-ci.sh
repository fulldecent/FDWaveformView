#!/bin/sh

set -o pipefail
xcodebuild -version
xcodebuild -showsdks

if [ $RUN_TESTS == "YES" ]; then
    xcodebuild -scheme "$IOS_FRAMEWORK_SCHEME" -destination "$DESTINATION" -configuration Debug ONLY_ACTIVE_ARCH=NO ENABLE_TESTABILITY=YES test | xcpretty;
else
    xcodebuild -scheme "$IOS_FRAMEWORK_SCHEME" -destination "$DESTINATION" -configuration Debug ONLY_ACTIVE_ARCH=NO build | xcpretty;
fi

# Build Framework in Release and Run Tests if specified
if [ $RUN_TESTS == "YES" ]; then
    xcodebuild -scheme "$IOS_FRAMEWORK_SCHEME" -destination "$DESTINATION" -configuration Release ONLY_ACTIVE_ARCH=NO ENABLE_TESTABILITY=YES test | xcpretty;
else
    xcodebuild -scheme "$IOS_FRAMEWORK_SCHEME" -destination "$DESTINATION" -configuration Release ONLY_ACTIVE_ARCH=NO ENABLE_TESTABILITY=YES build | xcpretty;
fi

if [ $BUILD_EXAMPLE == "YES" ]; then
    xcodebuild -workspace "$EXAMPLE_WORKSPACE" -scheme "$EXAMPLE_SCHEME"  -destination "$DESTINATION"  -configuration Debug ONLY_ACTIVE_ARCH=NO build | xcpretty;
fi

# Run `pod lib lint` if specified
if [ $POD_LINT == "YES" ]; then
    pod lib lint
fi

if [ $POD_QUALITY_CHECK == "YES" ]; then
    ruby Tests/CheckCocoaPodsQualityIndexes.rb
fi