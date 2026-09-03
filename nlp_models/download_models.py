#!/usr/bin/env python3
"""Download model assets for the PALASH MTB-MLE pipeline."""

from __future__ import annotations

import os
from pathlib import Path

MODEL_DIR = Path(__file__).resolve().parent / "models"
MODEL_DIR.mkdir(parents=True, exist_ok=True)


def main() -> None:
    print(f"Model directory: {MODEL_DIR}")
    print("This script is a placeholder for downloading ONNX/NLP model artifacts.")
    print("Add real model URLs and validation logic as the project matures.")


if __name__ == "__main__":
    main()
