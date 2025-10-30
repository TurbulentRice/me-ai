#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔧 Personal AI - Model Compilation for iOS"
echo "=========================================="
echo ""

# Configuration
MODEL_NAME="${1:-Phi-3-mini-128k-instruct-q4}"
MODEL_DIR="Models/Phi3Mini"
OUTPUT_DIR="App/PersonalLLM/Assets/Models"
QUANTIZATION="${2:-q4f16_1}"

# Check if Python venv exists
if [ ! -d "venv" ]; then
    echo "${YELLOW}⚠️  Python virtual environment not found${NC}"
    echo "Run: ./scripts/setup_environment.sh"
    exit 1
fi

# Activate virtual environment
echo "📦 Activating Python environment..."
source venv/bin/activate

# Check if MLC-LLM is installed
if ! command -v mlc_llm &> /dev/null; then
    echo "${RED}❌ MLC-LLM not found${NC}"
    echo "Run: ./scripts/setup_environment.sh"
    exit 1
fi

echo "${GREEN}✓${NC} MLC-LLM found"
echo ""

# Check if source model exists
MODEL_PATH="${MODEL_DIR}/${MODEL_NAME}.gguf"
if [ ! -f "$MODEL_PATH" ]; then
    echo "${YELLOW}⚠️  Model file not found: ${MODEL_PATH}${NC}"
    echo ""
    echo "Download models first:"
    echo "  ./scripts/download_models.sh"
    echo ""
    echo "Or manually download:"
    echo "  https://huggingface.co/microsoft/Phi-3-mini-128k-instruct-gguf"
    exit 1
fi

echo "${GREEN}✓${NC} Source model found: ${MODEL_PATH}"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Compile model for iOS
echo "🔨 Compiling model for iOS (this may take several minutes)..."
echo "   Model: ${MODEL_NAME}"
echo "   Quantization: ${QUANTIZATION}"
echo "   Target: iPhone (Apple Silicon)"
echo ""

# Note: This is a placeholder - actual MLC-LLM command may differ
# Real implementation will use MLC-LLM's convert and compile commands
echo "${YELLOW}⚠️  NOTE: MLC-LLM iOS compilation is complex and requires:${NC}"
echo "   1. Converting GGUF → MLC format"
echo "   2. Compiling for Metal (Apple GPU)"
echo "   3. Packaging for iOS deployment"
echo ""
echo "   For the prototype, we'll use MockLLM for testing."
echo "   Real model compilation will be added when MLC-LLM iOS SDK is integrated."
echo ""

# Future implementation:
# mlc_llm compile \
#   --model "$MODEL_PATH" \
#   --target iphone \
#   --quantization $QUANTIZATION \
#   --output "${OUTPUT_DIR}/phi3_mini.mlc" \
#   --use-cache=0

echo "${GREEN}✓${NC} Model compilation script ready"
echo ""
echo "📝 Next steps:"
echo "   1. Integrate MLC-LLM iOS SDK"
echo "   2. Run this script to compile models"
echo "   3. Test on device/simulator"
echo ""
echo "For now, use MockLLM for testing:"
echo "   let llm = MockLLM()"
echo "   try await llm.load(modelPath: mockURL, config: .phi3Mini)"
