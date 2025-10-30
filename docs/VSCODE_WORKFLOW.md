# VSCode/Cursor Development Workflow

**Updated**: 2025-10-30
**Status**: Active

This document describes the VSCode/Cursor-optimized workflow for Personal LLM development using Swift Package Manager.

---

## Overview

This project uses a **Swift Package Manager (SPM)** structure optimized for VSCode/Cursor development, while still maintaining full iOS app capabilities.

### Key Benefits

- ✅ **AI-Assisted Development**: Full Cursor/Claude Code integration
- ✅ **Version Control Friendly**: No binary .xcodeproj files in git
- ✅ **CLI-Driven**: Build, test, and run from command line
- ✅ **Cross-Platform**: Core logic can be shared with macOS/Linux
- ✅ **Standard iOS**: Still produces real iOS apps with full capabilities

---

## Project Structure

```
personal-ai/
├── Package.swift              # Swift Package Manager manifest
├── project.yml                # XcodeGen configuration (generates .xcodeproj)
├── App/
│   └── PersonalLLM/          # iOS app target
│       ├── PersonalLLMApp.swift
│       ├── ContentView.swift
│       └── Info.plist
├── Sources/
│   └── PersonalLLMCore/      # Shared business logic library
│       ├── Storage/          # Database & vector storage
│       ├── Engine/           # RAG engine & chunking
│       ├── ModelRuntime/     # LLM & embedding models
│       ├── Privacy/          # Encryption & security
│       └── UI/               # SwiftUI views & view models
├── Tests/
│   └── PersonalLLMCoreTests/ # Unit & integration tests
├── Models/                    # ML models (gitignored)
│   ├── Phi3Mini/
│   └── Embeddings/
└── scripts/                   # Build & setup scripts
    ├── generate_xcode.sh     # Generate Xcode project
    ├── build.sh              # Build iOS app
    ├── test.sh               # Run tests
    ├── setup_environment.sh  # Install dependencies
    └── download_models.sh    # Download ML models
```

---

## Prerequisites

### Required

- **macOS 14.4+** (for iOS SDK and simulators)
- **Xcode 15+** (command line tools only, minimal GUI usage)
- **Homebrew** - Package manager
- **Python 3.10+** - For MLC-LLM tools
- **VSCode** or **Cursor** - Primary IDE

### Recommended VSCode Extensions

The `.vscode/extensions.json` file includes:
- `sswg.swift-lang` - Swift language support
- `vknabel.vscode-swift-development-environment` - Swift development tools
- `github.copilot` or Cursor's built-in AI
- `yzhang.markdown-all-in-one` - Documentation
- `ms-python.python` - For model scripts

---

## Initial Setup

### 1. Install System Dependencies

```bash
# Install Xcode command line tools
xcode-select --install

# Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install XcodeGen (generates Xcode project from project.yml)
brew install xcodegen
```

### 2. Clone and Setup Project

```bash
# Clone the repository
cd ~/Dev
git clone <repo-url> personal-ai
cd personal-ai

# Install Python dependencies and MLC-LLM
./scripts/setup_environment.sh

# Generate Xcode project (needed for iOS builds)
./scripts/generate_xcode.sh
```

### 3. Download Models (Optional - do this later when needed)

```bash
./scripts/download_models.sh
```

---

## Daily Development Workflow

### Working in VSCode/Cursor

1. **Open the project in VSCode/Cursor**
   ```bash
   code .  # or 'cursor .' for Cursor
   ```

2. **Edit Swift files directly** in `Sources/`, `App/`, or `Tests/`
   - Full syntax highlighting and autocomplete via SourceKit-LSP
   - AI assistance from Claude Code or Cursor
   - No need to open Xcode for coding

3. **Build from VSCode**
   - Press `Cmd+Shift+B` to open build tasks
   - Select "Build iOS App" (default)
   - Or run from terminal: `./scripts/build.sh`

4. **Run tests**
   - Press `Cmd+Shift+P` → "Tasks: Run Test Task"
   - Or run from terminal: `./scripts/test.sh`

5. **Commit changes**
   - Only source files are committed (`.xcodeproj` is gitignored)
   - The `project.yml` file defines the project structure
   - Anyone can regenerate `.xcodeproj` with `./scripts/generate_xcode.sh`

### When to Use Xcode

You only need Xcode GUI for:

1. **Running on simulator/device** (for now)
   ```bash
   open PersonalLLM.xcodeproj
   # Press Cmd+R to run
   ```

2. **Debugging with breakpoints** (VSCode Swift debugging is limited)

3. **Code signing setup** (one-time, for physical devices)

4. **Interface Builder** (if using .xib files - we're using SwiftUI, so rarely needed)

5. **App Store submission** (archive and upload)

### Command-Line Reference

```bash
# Generate/regenerate Xcode project (after changing project.yml)
./scripts/generate_xcode.sh

# Build the app
./scripts/build.sh

# Run tests
./scripts/test.sh

# Clean build artifacts
rm -rf .build DerivedData *.xcodeproj *.xcworkspace

# Build and run on simulator (requires Xcode project)
xcodebuild build -project PersonalLLM.xcodeproj -scheme PersonalLLM \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

---

## Phase Implementation Adjustments

The original `PROTOTYPE_IMPLEMENTATION_PLAN.md` assumes traditional Xcode workflow. Here are the key adjustments for VSCode/SPM:

### Phase 0: Project Setup ✓ Complete

- ✅ Swift Package structure created
- ✅ XcodeGen configuration in place
- ✅ VSCode tasks and settings configured
- ✅ Build scripts created

### Phase 1+: Development Phases

For all subsequent phases:

1. **File Structure**: Create files in `Sources/PersonalLLMCore/<Module>/`
   - Example: `Sources/PersonalLLMCore/Storage/VectorDatabase.swift`
   - Not: `ios/PersonalLLM/Sources/Storage/VectorDatabase.swift`

2. **Import Statements**: Use module imports
   ```swift
   import PersonalLLMCore  // For app importing the library
   // Within the library, just use relative imports
   ```

3. **Testing**: Place tests in `Tests/PersonalLLMCoreTests/`
   ```swift
   @testable import PersonalLLMCore
   ```

4. **Build Process**:
   ```bash
   # Instead of opening Xcode:
   ./scripts/build.sh

   # Instead of Xcode test runner:
   ./scripts/test.sh
   ```

5. **Committing**: No need to commit Xcode project files
   - Commit source changes in `Sources/`, `App/`, `Tests/`
   - Commit `project.yml` if you add new files
   - Others regenerate with `./scripts/generate_xcode.sh`

---

## Adding New Files

### Adding a Swift File

1. **Create the file** in VSCode/Cursor:
   ```bash
   touch Sources/PersonalLLMCore/Storage/NewFile.swift
   ```

2. **Edit in your IDE** - write the code

3. **Update `project.yml`** (if needed for app target):
   - Most files in `Sources/PersonalLLMCore/` are auto-included
   - Only update if adding new app resources or targets

4. **Regenerate Xcode project**:
   ```bash
   ./scripts/generate_xcode.sh
   ```

5. **Build and test**:
   ```bash
   ./scripts/build.sh
   ```

### Adding Dependencies

Edit `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/user/repo.git", from: "1.0.0"),
],
targets: [
    .target(
        name: "PersonalLLMCore",
        dependencies: [
            .product(name: "ProductName", package: "repo"),
        ]
    ),
]
```

Then:
```bash
swift package resolve  # Download dependencies
./scripts/generate_xcode.sh  # Regenerate Xcode project
```

---

## Troubleshooting

### "Command not found: xcodegen"

```bash
brew install xcodegen
```

### "Command not found: sourcekit-lsp"

SourceKit-LSP should come with Xcode. Verify:
```bash
xcrun --find sourcekit-lsp
```

Add to VSCode settings if needed:
```json
{
  "sourcekit-lsp.serverPath": "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/sourcekit-lsp"
}
```

### "Build failed: No such module 'PersonalLLMCore'"

Regenerate the Xcode project:
```bash
./scripts/generate_xcode.sh
```

### Swift autocomplete not working

1. Ensure Swift extension is installed
2. Reload VSCode window (`Cmd+Shift+P` → "Reload Window")
3. Check SourceKit-LSP is running: VSCode bottom bar should show "SourceKit-LSP"

### Changes not reflected in build

```bash
# Clean and rebuild
rm -rf .build DerivedData
./scripts/build.sh
```

---

## Benefits of This Approach

### For AI-Assisted Development

- **Claude Code Integration**: Full file access and understanding
- **Clean Diffs**: Only source code changes, no binary project files
- **Better Context**: AI can understand `project.yml` vs binary `.xcodeproj`

### For Version Control

- **Merge Conflicts**: Rare - only in source files and `project.yml`
- **Readable History**: See exactly what changed in code
- **Clean Commits**: No auto-generated Xcode metadata

### For Collaboration

- **No Project File Conflicts**: Each dev regenerates their own `.xcodeproj`
- **Consistent Builds**: Everyone uses same `project.yml` source of truth
- **Easy Onboarding**: Clone, run setup script, start coding

---

## Next Steps

With Phase 0 complete and VSCode workflow established, proceed with:

- **Phase 1**: Storage Layer (SQLite + vector database)
- **Phase 2**: Model Runtime (MLC-LLM integration)
- **Phase 3**: RAG Engine
- **Phase 4**: UI Layer
- **Phase 5**: Privacy & Security
- **Phase 6**: Testing & Polish

All development can be done primarily in VSCode/Cursor, with minimal Xcode usage.

---

**See also:**
- [PROTOTYPE_IMPLEMENTATION_PLAN.md](./PROTOTYPE_IMPLEMENTATION_PLAN.md) - Full implementation plan
- [PROTOTYPE.md](./PROTOTYPE.md) - Architecture overview
- [Package.swift](../Package.swift) - Swift Package Manager configuration
- [project.yml](../project.yml) - XcodeGen project definition
