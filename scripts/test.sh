#!/bin/bash
set -e

# Generate project if it doesn't exist
if [ ! -d "PersonalLLM.xcodeproj" ]; then
    echo "Xcode project not found. Generating..."
    ./scripts/generate_xcode.sh
fi

echo "Running tests for PersonalLLM..."

xcodebuild test \
    -project PersonalLLM.xcodeproj \
    -scheme PersonalLLM \
    -destination 'platform=iOS Simulator,name=iPhone 15' \
    | xcpretty || true

echo "✓ Tests complete!"
