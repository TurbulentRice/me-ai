#!/bin/bash
set -e

MODEL_DIR="Models"
mkdir -p "$MODEL_DIR/Phi3Mini"
mkdir -p "$MODEL_DIR/Embeddings"

echo "Downloading Phi-3 Mini 128k Instruct (Q4)..."
cd "$MODEL_DIR/Phi3Mini"

# Download from HuggingFace
curl -L -O "https://huggingface.co/microsoft/Phi-3-mini-128k-instruct-gguf/resolve/main/Phi-3-mini-128k-instruct-q4.gguf"

echo "Downloading embedding model..."
cd ../Embeddings
curl -L -O "https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2/resolve/main/pytorch_model.bin"

echo "Model download complete!"
echo "Note: Models are gitignored. Run this script on each development machine."
