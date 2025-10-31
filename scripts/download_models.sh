#!/bin/bash
set -e

MODEL_DIR="Models"
mkdir -p "$MODEL_DIR/Phi3Mini"
mkdir -p "$MODEL_DIR/Embeddings"

echo "======================================"
echo "Personal AI - Model Download Script"
echo "======================================"
echo ""

# Check if huggingface-cli is available
if ! command -v huggingface-cli &> /dev/null; then
    echo "⚠️  huggingface-cli not found. Installing..."
    pip install -U "huggingface_hub[cli]"
fi

echo "📦 Downloading Phi-3-mini-128k-instruct (Q4_K_M quantization)..."
echo "   Using bartowski's trusted GGUF conversion"
cd "$MODEL_DIR/Phi3Mini"

# Using bartowski's Phi-3.1-mini which is the updated version
# Q4_K_M is a good balance of size (~2.4GB) and quality
huggingface-cli download bartowski/Phi-3.1-mini-128k-instruct-GGUF \
  --include "Phi-3.1-mini-128k-instruct-Q4_K_M.gguf" \
  --local-dir . \
  --local-dir-use-symlinks False

# Rename to simpler name
if [ -f "Phi-3.1-mini-128k-instruct-Q4_K_M.gguf" ]; then
    mv Phi-3.1-mini-128k-instruct-Q4_K_M.gguf phi3-mini-128k-q4.gguf
    echo "✅ Phi-3 model downloaded successfully"
else
    echo "❌ Download failed - file not found"
    exit 1
fi

# Verify file size (should be ~2-2.5GB)
FILE_SIZE=$(stat -f%z phi3-mini-128k-q4.gguf 2>/dev/null || stat -c%s phi3-mini-128k-q4.gguf 2>/dev/null)
FILE_SIZE_GB=$((FILE_SIZE / 1000000000))

echo "   Model size: ${FILE_SIZE_GB}GB"

if [ $FILE_SIZE -lt 2000000000 ]; then
  echo "⚠️  Warning: Model file seems small ($FILE_SIZE bytes)"
  echo "   Expected ~2-2.5GB. Download may be incomplete."
else
  echo "✅ Model file size looks correct"
fi

echo ""
echo "📦 Downloading embedding model (all-MiniLM-L6-v2)..."
cd ../Embeddings

# Download sentence-transformers model files
FILES=(
  "pytorch_model.bin"
  "config.json"
  "tokenizer_config.json"
  "tokenizer.json"
  "vocab.txt"
  "special_tokens_map.json"
)

for FILE in "${FILES[@]}"; do
  if [ ! -f "$FILE" ]; then
    echo "   Downloading $FILE..."
    curl -L -o "$FILE" \
      "https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2/resolve/main/$FILE"
  else
    echo "   ✓ $FILE already exists"
  fi
done

echo "✅ Embedding model downloaded successfully"

echo ""
echo "======================================"
echo "✅ Model Download Complete!"
echo "======================================"
echo ""
echo "Downloaded models:"
echo "  • Phi-3.1-mini-128k (Q4_K_M): Models/Phi3Mini/phi3-mini-128k-q4.gguf"
echo "  • all-MiniLM-L6-v2: Models/Embeddings/"
echo ""
echo "Next steps:"
echo "  1. Verify models with: ls -lh Models/Phi3Mini/ Models/Embeddings/"
echo "  2. For MLC-LLM conversion: ./scripts/convert_phi3_to_mlc.sh"
echo "  3. Build app: ./scripts/build.sh"
echo ""
echo "Note: Models are gitignored and stay on your machine."
echo ""
