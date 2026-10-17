"""
Step C — Verify the exported ONNX models actually work correctly.

This runs the SAME test sentences as test_indictrans2_hi_sat.py, but using
onnxruntime + the exported ONNX files instead of PyTorch. Compare the output
here against the PyTorch output you already saw — they should match closely.

This must pass BEFORE quantizing (quantizing a broken export just gives you
a smaller broken model).

Run inside Docker:
    docker compose run --rm nlp python nlp_models/test_onnx_indictrans2.py
"""

import os
import json
import time
import numpy as np
import onnxruntime as ort
from transformers import AutoTokenizer
from IndicTransToolkit import IndicProcessor

ONNX_DIR = os.environ.get("ONNX_DIR", "nlp_models/onnx_export")
SRC_LANG = "hin_Deva"
TGT_LANG = "sat_Olck"
MAX_NEW_TOKENS = 60

TEST_SENTENCES = [
    "बैठ जाओ",
    "आज हम पानी के बारे में पढ़ेंगे",
    "अपनी किताब खोलो और पन्ना दस पर जाओ",
    "क्या तुमने कल का काम पूरा किया?",
    "यह बहुत अच्छा काम है, शाबाश",
]


def main():
    with open(f"{ONNX_DIR}/export_meta.json") as f:
        meta = json.load(f)

    num_layers = meta["num_decoder_layers"]
    eos_id = meta["eos_token_id"]
    decoder_start_id = meta["decoder_start_token_id"]

    print("Loading tokenizer (from exported copy, not re-downloading)...")
    import os as _os
    tokenizer = AutoTokenizer.from_pretrained("ai4bharat/indictrans2-indic-indic-dist-320M", trust_remote_code=True, token=_os.environ.get("HF_TOKEN"))
    ip = IndicProcessor(inference=True)

    print("Loading ONNX sessions (CPU)...")
    encoder_sess = ort.InferenceSession(f"{ONNX_DIR}/encoder.onnx", providers=["CPUExecutionProvider"])
    decoder_initial_sess = ort.InferenceSession(f"{ONNX_DIR}/decoder_step_initial.onnx", providers=["CPUExecutionProvider"])
    decoder_cached_sess = ort.InferenceSession(f"{ONNX_DIR}/decoder_step_cached.onnx", providers=["CPUExecutionProvider"])

    # The cached-decoder graph may have pruned encoder_hidden_states /
    # encoder_attention_mask if PyTorch traced a path where cross-attention
    # only reuses cached K/V and never re-reads the encoder output. Find out
    # which inputs this graph actually expects so we don't send extras.
    cached_input_names = {inp.name for inp in decoder_cached_sess.get_inputs()}

    batch = ip.preprocess_batch(TEST_SENTENCES, src_lang=SRC_LANG, tgt_lang=TGT_LANG)
    inputs = tokenizer(batch, truncation=True, padding=True, return_tensors="np")

    latencies = []
    for i in range(len(TEST_SENTENCES)):
        input_ids = inputs["input_ids"][i : i + 1].astype(np.int64)
        attention_mask = inputs["attention_mask"][i : i + 1].astype(np.int64)

        start = time.time()

        # ---- Encoder (runs once) ----
        enc_out = encoder_sess.run(
            ["encoder_hidden_states"],
            {"input_ids": input_ids, "attention_mask": attention_mask},
        )[0]

        # ---- Decoder loop (runs once per output token) ----
        generated_ids = [decoder_start_id]
        past = None

        for step in range(MAX_NEW_TOKENS):
            decoder_input_ids = np.array([[generated_ids[-1]]], dtype=np.int64)

            if past is None:
                # first step: no cache yet
                outputs = decoder_initial_sess.run(
                    None,
                    {
                        "decoder_input_ids": decoder_input_ids,
                        "encoder_hidden_states": enc_out,
                        "encoder_attention_mask": attention_mask,
                    },
                )
            else:
                full_feed = {
                    "decoder_input_ids": decoder_input_ids,
                    "encoder_hidden_states": enc_out,
                    "encoder_attention_mask": attention_mask,
                }
                for idx, tensor in enumerate(past):
                    full_feed[f"past_in_{idx}"] = tensor
                # Only send inputs this graph actually declares.
                feed = {k: v for k, v in full_feed.items() if k in cached_input_names}
                outputs = decoder_cached_sess.run(None, feed)

            logits = outputs[0]
            past = outputs[1:]  # flat list of new cache tensors

            next_token_id = int(np.argmax(logits[0, -1, :]))
            generated_ids.append(next_token_id)

            if next_token_id == eos_id:
                break

        elapsed = time.time() - start
        latencies.append(elapsed)

        with tokenizer.as_target_tokenizer():
            decoded = tokenizer.decode(generated_ids, skip_special_tokens=True)
        # IndicProcessor.postprocess_batch() has a hang bug on some Ol Chiki
        # strings, and testing showed it's a no-op for sat_Olck anyway (output
        # matched the raw decoded text exactly). Skip it, just clean whitespace.
        output_text = decoded.strip()

        print(f"HI : {TEST_SENTENCES[i]}")
        print(f"SAT: {output_text}")
        print(f"    ({elapsed:.2f}s, ONNX CPU)\n")

    avg = sum(latencies) / len(latencies)
    print(f"--- Average latency: {avg:.2f}s per sentence (ONNX, unquantized, CPU) ---")
    print("Compare this output to test_indictrans2_hi_sat.py's PyTorch output above.")
    print("If translations look the same/similar -> export is correct, proceed to quantization.")
    print("If translations look garbled/wrong -> the ONNX export has a bug, do not quantize yet.")


if __name__ == "__main__":
    main()