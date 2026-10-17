"""
Step D — INT8 quantize the exported ONNX models.

Dynamic quantization: converts the weights (mainly in MatMul/Linear layers,
which dominate a transformer's size and compute) from float32 to int8.
This typically shrinks the model ~4x and speeds up CPU inference, with a
small, usually acceptable, quality trade-off. No calibration dataset needed
(that's "static" quantization, which is more work and not needed here).

Run inside Docker:
    docker compose run --rm nlp python nlp_models/quantize_indictrans2.py

Input:  nlp_models/onnx_export/          (fp32 models from export step)
Output: nlp_models/onnx_export_int8/     (quantized models, same filenames)
"""

import os
import shutil
from pathlib import Path
from onnxruntime.quantization import quantize_dynamic, QuantType

IN_DIR = Path("nlp_models/onnx_export")
OUT_DIR = Path("nlp_models/onnx_export_int8")
OUT_DIR.mkdir(parents=True, exist_ok=True)

MODELS_TO_QUANTIZE = [
    "encoder.onnx",
    "decoder_step_initial.onnx",
    "decoder_step_cached.onnx",
]


def human_mb(path: Path) -> float:
    return path.stat().st_size / (1024 * 1024)


def main():
    total_before = 0.0
    total_after = 0.0

    for filename in MODELS_TO_QUANTIZE:
        in_path = IN_DIR / filename
        out_path = OUT_DIR / filename

        if not in_path.exists():
            print(f"SKIP (not found): {in_path}")
            continue

        before_mb = human_mb(in_path)
        print(f"Quantizing {filename} ({before_mb:.1f} MB)...")

        quantize_dynamic(
            model_input=str(in_path),
            model_output=str(out_path),
            weight_type=QuantType.QInt8,
        )

        after_mb = human_mb(out_path)
        total_before += before_mb
        total_after += after_mb
        print(f"  -> {after_mb:.1f} MB ({before_mb / after_mb:.1f}x smaller)\n")

    # Copy tokenizer + metadata alongside so the quantized folder is
    # self-contained (test_onnx_indictrans2.py can point ONNX_DIR at either
    # nlp_models/onnx_export or nlp_models/onnx_export_int8).
    src_tokenizer = IN_DIR / "tokenizer"
    dst_tokenizer = OUT_DIR / "tokenizer"
    if src_tokenizer.exists() and not dst_tokenizer.exists():
        shutil.copytree(src_tokenizer, dst_tokenizer)
        print(f"Copied tokenizer/ -> {dst_tokenizer}")

    src_meta = IN_DIR / "export_meta.json"
    dst_meta = OUT_DIR / "export_meta.json"
    if src_meta.exists():
        shutil.copy2(src_meta, dst_meta)
        print(f"Copied export_meta.json -> {dst_meta}")

    if total_before > 0:
        print(f"\n--- Total: {total_before:.1f} MB -> {total_after:.1f} MB ({total_before/total_after:.1f}x smaller) ---")
    print("\nDone. Next: run test_onnx_indictrans2.py against the int8 folder to verify quality/speed.")


if __name__ == "__main__":
    main()