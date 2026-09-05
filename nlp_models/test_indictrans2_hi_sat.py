"""
Step A — Feasibility test for IndicTrans2 Hindi -> Santali (Ol Chiki) translation.

Purpose: validate translation QUALITY and CPU LATENCY on plain PyTorch before
spending time on ONNX export + quantization + Flutter/Dart integration.
Run this in your Docker container (has Python 3.11 already per your setup).

Install deps first (inside the Docker container):
    pip install --break-system-packages torch --index-url https://download.pytorch.org/whl/cpu
    pip install --break-system-packages transformers sentencepiece
    pip install --break-system-packages git+https://github.com/VarunGumma/IndicTransToolkit.git

Model used: ai4bharat/indictrans2-indic-indic-dist-320M
  - "dist-320M" = distilled, smaller than the 1B version, better fit for
    budget hardware. This is still large for a phone (~320M params ≈ 1.2GB
    fp32 / ~320MB int8) — this script is ONLY to check quality + CPU speed,
    not to run on the tablet itself.

Language codes (FLORES-200 style, required by IndicTrans2):
    Hindi   -> "hin_Deva"
    Santali -> "sat_Olck"   (Ol Chiki script)
"""

import time
import torch
from transformers import AutoModelForSeq2SeqLM, AutoTokenizer
from IndicTransToolkit import IndicProcessor

MODEL_NAME = "ai4bharat/indictrans2-indic-indic-dist-320M"
SRC_LANG = "hin_Deva"
TGT_LANG = "sat_Olck"

# Classroom sentences to validate against — mix of short commands (should be
# in your CSV dictionary already) and longer sentences (dictionary can't
# cover these, this is where NMT is actually needed).
TEST_SENTENCES = [
    "बैठ जाओ",
    "आज हम पानी के बारे में पढ़ेंगे",
    "अपनी किताब खोलो और पन्ना दस पर जाओ",
    "क्या तुमने कल का काम पूरा किया?",
    "यह बहुत अच्छा काम है, शाबाश",
]


def main():
    print(f"Loading tokenizer + model: {MODEL_NAME}")
    print("(first run will download ~1.2GB, may take a while)\n")

    tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME, trust_remote_code=True)
    model = AutoModelForSeq2SeqLM.from_pretrained(MODEL_NAME, trust_remote_code=True)
    model.eval()

    ip = IndicProcessor(inference=True)

    # Preprocess: IndicTrans2 needs its own normalization/masking step,
    # not just raw tokenizer.encode()
    batch = ip.preprocess_batch(TEST_SENTENCES, src_lang=SRC_LANG, tgt_lang=TGT_LANG)

    inputs = tokenizer(
        batch,
        truncation=True,
        padding="longest",
        return_tensors="pt",
        return_attention_mask=True,
    )

    print("Running inference (CPU, greedy decoding — beam search is too slow for phones)...\n")
    latencies = []
    with torch.no_grad():
        for i in range(len(TEST_SENTENCES)):
            single_input = {k: v[i : i + 1] for k, v in inputs.items()}
            start = time.time()
            generated = model.generate(
                **single_input,
                use_cache=True,
                min_length=0,
                max_length=256,
                num_beams=1,       # greedy — beam=5 measured ~5.9s/sentence elsewhere, too slow for real-time
                num_return_sequences=1,
            )
            elapsed = time.time() - start
            latencies.append(elapsed)

            with tokenizer.as_target_tokenizer():
                decoded = tokenizer.batch_decode(
                    generated, skip_special_tokens=True, clean_up_tokenization_spaces=True
                )
            output_text = ip.postprocess_batch(decoded, lang=TGT_LANG)[0]

            print(f"HI : {TEST_SENTENCES[i]}")
            print(f"SAT: {output_text}")
            print(f"    ({elapsed:.2f}s, CPU, greedy)\n")

    avg = sum(latencies) / len(latencies)
    print(f"--- Average latency: {avg:.2f}s per sentence (CPU, dev machine) ---")
    print("Note: a real Android tablet CPU will likely be 2-4x slower than this.")
    print("If this average is already >2s, INT8 ONNX quantization is mandatory")
    print("before this is usable for real-time translation on-device.")


if __name__ == "__main__":
    main()
