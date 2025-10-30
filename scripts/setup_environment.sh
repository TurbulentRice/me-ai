#!/bin/bash
set -e

echo "Setting up Personal AI development environment..."

# Check macOS version
if [[ $(sw_vers -productVersion | cut -d. -f1) -lt 14 ]]; then
  echo "Error: macOS 14.4+ required"
  exit 1
fi

# Install Homebrew dependencies
brew install cmake llvm libomp

# Setup Python environment
python3 -m venv venv
source venv/bin/activate
pip install --pre mlc-ai-nightly mlc-llm-nightly -f https://mlc.ai/wheels

echo "Environment setup complete!"
