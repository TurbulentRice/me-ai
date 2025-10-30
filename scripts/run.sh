#!/bin/bash
set -e

# Generate Xcode project if it doesn't exist
if [ ! -d "PersonalLLM.xcodeproj" ]; then
    echo "📦 Generating Xcode project..."
    ./scripts/generate_xcode.sh
fi

echo "🚀 Opening PersonalLLM in Xcode..."
echo ""
echo "Next steps:"
echo "  1. Select a simulator (e.g., iPhone 15)"
echo "  2. Press Cmd+R to build and run"
echo ""

open PersonalLLM.xcodeproj
