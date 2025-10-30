#!/bin/bash
set -e

echo "Generating Xcode project from project.yml..."

# Check if XcodeGen is installed
if ! command -v xcodegen &> /dev/null; then
    echo "XcodeGen not found. Installing via Homebrew..."
    brew install xcodegen
fi

# Generate the Xcode project
xcodegen generate

echo "✓ Xcode project generated: PersonalLLM.xcodeproj"
echo ""
echo "You can now:"
echo "  • Open in Xcode: open PersonalLLM.xcodeproj"
echo "  • Build from CLI: ./scripts/build.sh"
echo "  • Run tests: ./scripts/test.sh"
