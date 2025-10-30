#!/bin/bash
set -e

# Generate project if it doesn't exist
if [ ! -d "PersonalLLM.xcodeproj" ]; then
    echo "Xcode project not found. Generating..."
    ./scripts/generate_xcode.sh
fi

echo "Building PersonalLLM for iOS Simulator..."

xcodebuild build \
    -project PersonalLLM.xcodeproj \
    -scheme PersonalLLM \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -configuration Debug

echo "✓ Build complete!"
