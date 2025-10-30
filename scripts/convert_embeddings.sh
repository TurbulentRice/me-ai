#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔧 Personal AI - Embedding Model Conversion"
echo "=========================================="
echo ""

# Configuration
MODEL_NAME="${1:-all-MiniLM-L6-v2}"
MODEL_DIR="Models/Embeddings"
OUTPUT_DIR="App/PersonalLLM/Assets/Models"
OUTPUT_FORMAT="${2:-coreml}"

# Check if Python venv exists
if [ ! -d "venv" ]; then
    echo "${YELLOW}⚠️  Python virtual environment not found${NC}"
    echo "Run: ./scripts/setup_environment.sh"
    exit 1
fi

# Activate virtual environment
echo "📦 Activating Python environment..."
source venv/bin/activate

# Check if required tools are installed
echo "🔍 Checking dependencies..."

if ! python -c "import transformers" 2>/dev/null; then
    echo "${YELLOW}⚠️  transformers not installed${NC}"
    echo "Installing transformers..."
    pip install transformers torch
fi

if ! python -c "import coremltools" 2>/dev/null; then
    echo "${YELLOW}⚠️  coremltools not installed${NC}"
    echo "Installing coremltools..."
    pip install coremltools
fi

echo "${GREEN}✓${NC} Dependencies ready"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"
mkdir -p "$MODEL_DIR"

# Create Python conversion script
CONVERT_SCRIPT=$(cat <<'PYTHON_EOF'
import sys
import torch
from transformers import AutoTokenizer, AutoModel
import coremltools as ct
import os

def convert_embedding_model(model_name, output_path):
    print(f"📥 Loading model: {model_name}")

    try:
        tokenizer = AutoTokenizer.from_pretrained(model_name)
        model = AutoModel.from_pretrained(model_name)
        model.eval()

        print("✓ Model loaded")

        # Create example input
        example_text = "This is a sample sentence."
        inputs = tokenizer(example_text, return_tensors="pt", padding=True, truncation=True)

        print("🔄 Converting to CoreML...")

        # Trace the model
        traced_model = torch.jit.trace(model, (inputs['input_ids'], inputs['attention_mask']))

        # Convert to CoreML
        mlmodel = ct.convert(
            traced_model,
            inputs=[
                ct.TensorType(name="input_ids", shape=(1, ct.RangeDim(1, 512))),
                ct.TensorType(name="attention_mask", shape=(1, ct.RangeDim(1, 512)))
            ],
            outputs=[ct.TensorType(name="embeddings")],
            minimum_deployment_target=ct.target.iOS17
        )

        # Save the model
        mlmodel.save(output_path)
        print(f"✓ Model saved to: {output_path}")

        # Print model info
        print("\n📊 Model Information:")
        print(f"   Input dimension: {tokenizer.model_max_length}")
        print(f"   Embedding dimension: {model.config.hidden_size}")
        print(f"   Model size: {os.path.getsize(output_path) / (1024*1024):.2f} MB")

        return True

    except Exception as e:
        print(f"❌ Error: {e}")
        return False

if __name__ == "__main__":
    model_name = sys.argv[1] if len(sys.argv) > 1 else "sentence-transformers/all-MiniLM-L6-v2"
    output_path = sys.argv[2] if len(sys.argv) > 2 else "embedding_model.mlmodel"

    success = convert_embedding_model(model_name, output_path)
    sys.exit(0 if success else 1)
PYTHON_EOF
)

# Save conversion script
TEMP_SCRIPT=$(mktemp)
echo "$CONVERT_SCRIPT" > "$TEMP_SCRIPT"

# Run conversion
OUTPUT_FILE="${OUTPUT_DIR}/embeddings.mlpackage"

echo "🔄 Converting embedding model..."
echo "   Model: ${MODEL_NAME}"
echo "   Format: ${OUTPUT_FORMAT}"
echo "   Output: ${OUTPUT_FILE}"
echo ""

# Note: For the prototype, we'll document the process but not run it
# Real conversion requires downloading models and significant computation

echo "${YELLOW}⚠️  NOTE: Embedding model conversion requires:${NC}"
echo "   1. Downloading pre-trained model (~80MB)"
echo "   2. Converting PyTorch → CoreML"
echo "   3. Validating on iOS target"
echo ""
echo "   For the prototype, we'll use MockEmbedder for testing."
echo "   Real conversion can be done when models are downloaded:"
echo ""
echo "   python3 ${TEMP_SCRIPT} sentence-transformers/${MODEL_NAME} ${OUTPUT_FILE}"
echo ""

# Cleanup
rm -f "$TEMP_SCRIPT"

echo "${GREEN}✓${NC} Embedding conversion script ready"
echo ""
echo "📝 For now, use MockEmbedder for testing:"
echo "   let embedder = MockEmbedder(dimension: 384, maxLength: 512)"
echo "   let embeddings = try await embedder.embed(texts: [\"Hello world\"])"
