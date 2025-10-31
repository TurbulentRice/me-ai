#!/usr/bin/env python3
"""
Convert sentence-transformers all-MiniLM-L6-v2 model to CoreML format.

This script converts the PyTorch embedding model to CoreML for on-device inference.
"""

import sys
import os
from pathlib import Path

def main():
    print("=" * 60)
    print("Embedding Model Conversion to CoreML")
    print("=" * 60)
    print()

    # Check dependencies
    print("Checking dependencies...")
    try:
        import torch
        print(f"✓ PyTorch {torch.__version__}")
    except ImportError:
        print("✗ PyTorch not found. Install with: pip install torch")
        sys.exit(1)

    try:
        import transformers
        print(f"✓ Transformers {transformers.__version__}")
    except ImportError:
        print("✗ Transformers not found. Install with: pip install transformers")
        sys.exit(1)

    try:
        import coremltools as ct
        print(f"✓ CoreMLTools {ct.__version__}")
    except ImportError:
        print("✗ CoreMLTools not found. Install with: pip install coremltools")
        sys.exit(1)

    print()

    # Paths
    model_dir = Path("Models/Embeddings")
    output_path = model_dir / "embeddings.mlpackage"

    if not model_dir.exists():
        print(f"✗ Model directory not found: {model_dir}")
        sys.exit(1)

    print(f"Loading model from: {model_dir}")
    print()

    # Load model
    try:
        from transformers import AutoModel, AutoTokenizer

        # Load from local files
        model = AutoModel.from_pretrained(str(model_dir))
        tokenizer = AutoTokenizer.from_pretrained(str(model_dir))

        print(f"✓ Model loaded: {model.config.model_type}")
        print(f"  Hidden size: {model.config.hidden_size}")
        print(f"  Max position embeddings: {model.config.max_position_embeddings}")
        print()

    except Exception as e:
        print(f"✗ Failed to load model: {e}")
        sys.exit(1)

    # Prepare model for export
    model.eval()

    # Create example inputs for tracing
    max_length = 128  # Reasonable default for embeddings
    example_text = "This is an example sentence for tracing the model."

    print(f"Tracing model with max_length={max_length}...")

    try:
        # Tokenize example
        inputs = tokenizer(
            example_text,
            return_tensors="pt",
            padding="max_length",
            max_length=max_length,
            truncation=True
        )

        # Create a wrapper that returns only the last_hidden_state tensor
        class EmbeddingModelWrapper(torch.nn.Module):
            def __init__(self, model):
                super().__init__()
                self.model = model

            def forward(self, input_ids, attention_mask):
                outputs = self.model(input_ids=input_ids, attention_mask=attention_mask)
                # Return only the last hidden state (embeddings)
                return outputs.last_hidden_state

        wrapped_model = EmbeddingModelWrapper(model)
        wrapped_model.eval()

        # Trace the wrapped model
        with torch.no_grad():
            traced_model = torch.jit.trace(
                wrapped_model,
                (inputs['input_ids'], inputs['attention_mask']),
                strict=False
            )

        print("✓ Model traced successfully")
        print()

    except Exception as e:
        print(f"✗ Failed to trace model: {e}")
        sys.exit(1)

    # Convert to CoreML
    print("Converting to CoreML format...")
    print("This may take a few minutes...")
    print()

    try:
        mlmodel = ct.convert(
            traced_model,
            inputs=[
                ct.TensorType(
                    name="input_ids",
                    shape=(1, max_length),
                    dtype=int
                ),
                ct.TensorType(
                    name="attention_mask",
                    shape=(1, max_length),
                    dtype=int
                )
            ],
            outputs=[ct.TensorType(name="embeddings")],
            minimum_deployment_target=ct.target.iOS17,
        )

        # Add metadata
        mlmodel.author = "sentence-transformers"
        mlmodel.short_description = "all-MiniLM-L6-v2 sentence embedding model"
        mlmodel.version = "1.0.0"

        # Save the model
        mlmodel.save(str(output_path))

        print(f"✓ Model converted successfully!")
        print(f"  Output: {output_path}")
        print(f"  Size: {output_path.stat().st_size / (1024*1024):.1f} MB")
        print()

    except Exception as e:
        print(f"✗ Conversion failed: {e}")
        print()
        print("Note: CoreML conversion can be tricky. Common issues:")
        print("  1. Unsupported operations in the model")
        print("  2. Dynamic shapes not handled properly")
        print("  3. CoreMLTools version compatibility")
        print()
        sys.exit(1)

    print("=" * 60)
    print("Conversion Complete!")
    print("=" * 60)
    print()
    print("Next steps:")
    print("  1. The model will be automatically included in the app bundle")
    print("  2. Use CoreMLEmbedder to load and run inference")
    print("  3. Remember: This model requires proper tokenization")
    print()
    print("Note: The converted model performs mean pooling on the last hidden")
    print("state. You'll need to implement this in Swift if not included.")
    print()

if __name__ == "__main__":
    main()
