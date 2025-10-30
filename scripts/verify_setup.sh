#!/bin/bash

echo "🔍 Verifying Personal AI Development Environment"
echo "================================================"
echo ""

# Track failures
FAILURES=0

# Check macOS version
echo "1️⃣  Checking macOS version..."
MACOS_VERSION=$(sw_vers -productVersion | cut -d. -f1)
if [[ $MACOS_VERSION -ge 14 ]]; then
    echo "   ✅ macOS $(sw_vers -productVersion)"
else
    echo "   ❌ macOS 14.4+ required (found $(sw_vers -productVersion))"
    FAILURES=$((FAILURES + 1))
fi
echo ""

# Check Xcode
echo "2️⃣  Checking Xcode..."
if command -v xcodebuild &> /dev/null; then
    XCODE_VERSION=$(xcodebuild -version | head -n1)
    echo "   ✅ $XCODE_VERSION"
else
    echo "   ❌ Xcode not found (required for iOS development)"
    FAILURES=$((FAILURES + 1))
fi
echo ""

# Check Xcode Command Line Tools
echo "3️⃣  Checking Xcode Command Line Tools..."
if xcode-select -p &> /dev/null; then
    echo "   ✅ $(xcode-select -p)"
else
    echo "   ❌ Xcode Command Line Tools not installed"
    echo "      Run: xcode-select --install"
    FAILURES=$((FAILURES + 1))
fi
echo ""

# Check Homebrew
echo "4️⃣  Checking Homebrew..."
if command -v brew &> /dev/null; then
    BREW_VERSION=$(brew --version | head -n1)
    echo "   ✅ $BREW_VERSION"
else
    echo "   ❌ Homebrew not found"
    echo "      Install: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    FAILURES=$((FAILURES + 1))
fi
echo ""

# Check XcodeGen
echo "5️⃣  Checking XcodeGen..."
if command -v xcodegen &> /dev/null; then
    XCODEGEN_VERSION=$(xcodegen --version)
    echo "   ✅ XcodeGen $XCODEGEN_VERSION"
else
    echo "   ❌ XcodeGen not found"
    echo "      Install: brew install xcodegen"
    FAILURES=$((FAILURES + 1))
fi
echo ""

# Check Python
echo "6️⃣  Checking Python..."
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version)
    echo "   ✅ $PYTHON_VERSION"
else
    echo "   ❌ Python 3 not found"
    FAILURES=$((FAILURES + 1))
fi
echo ""

# Check Swift
echo "7️⃣  Checking Swift..."
if command -v swift &> /dev/null; then
    SWIFT_VERSION=$(swift --version | head -n1)
    echo "   ✅ $SWIFT_VERSION"
else
    echo "   ❌ Swift not found"
    FAILURES=$((FAILURES + 1))
fi
echo ""

# Check if Xcode project exists
echo "8️⃣  Checking Xcode project..."
if [ -d "PersonalLLM.xcodeproj" ]; then
    echo "   ✅ PersonalLLM.xcodeproj exists"
else
    echo "   ⚠️  PersonalLLM.xcodeproj not generated"
    echo "      Run: ./scripts/generate_xcode.sh"
fi
echo ""

# Check Swift package
echo "9️⃣  Checking Swift Package..."
if [ -f "Package.swift" ]; then
    echo "   ✅ Package.swift exists"
    if [ -f "Package.resolved" ]; then
        echo "   ✅ Dependencies resolved"
    else
        echo "   ⚠️  Dependencies not resolved yet"
        echo "      Run: swift package resolve"
    fi
else
    echo "   ❌ Package.swift not found"
    FAILURES=$((FAILURES + 1))
fi
echo ""

# Check Python virtual environment
echo "🔟 Checking Python environment..."
if [ -d "venv" ]; then
    echo "   ✅ Python venv exists"
    if [ -f "venv/bin/mlc_llm" ]; then
        echo "   ✅ MLC-LLM installed"
    else
        echo "   ⚠️  MLC-LLM not installed"
        echo "      Run: ./scripts/setup_environment.sh"
    fi
else
    echo "   ⚠️  Python venv not created"
    echo "      Run: ./scripts/setup_environment.sh"
fi
echo ""

# Summary
echo "================================================"
if [ $FAILURES -eq 0 ]; then
    echo "✅ All critical checks passed!"
    echo ""
    echo "🚀 Next steps:"
    echo "   1. Generate Xcode project:  ./scripts/generate_xcode.sh"
    echo "   2. Open and run:            ./scripts/run.sh"
    echo "   3. Or build from CLI:       ./scripts/build.sh"
else
    echo "❌ Found $FAILURES issue(s) - fix them before proceeding"
    exit 1
fi
