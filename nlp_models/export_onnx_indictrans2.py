"""
Step B — Export IndicTrans2 (hin_Deva -> sat_Olck) to ONNX.

This is the first half of getting on-device translation working. It exports:
  1. encoder.onnx      — runs once per input sentence
  2. decoder_step.onnx — runs once per OUTPUT token (uses KV-cache for speed)

Why two separate ONNX graphs instead of one:
  Seq2seq generation is autoregressive — the decoder runs many times (once per
  output token), reusing cached attention keys/values from previous steps so
  it doesn't recompute everything each time. Exporting this as a single static
  ONNX graph isn't practical, so encoder and decoder are exported separately,
  and the generation loop (calling decoder_step repeatedly) is implemented in
  the runtime (Python here for testing; later ported to Dart for the app).

Run this INSIDE the Docker container (has torch/transformers/IndicTransToolkit
already installed via requirements.txt):
    docker compose run --rm nlp python nlp_models/export_onnx_indictrans2.py

Output files land in: nlp_models/onnx_export/
"""

import os
import json
import torch
import torch.nn as nn
from transformers import AutoModelForSeq2SeqLM, AutoTokenizer

HF_TOKEN = os.environ.get("HF_TOKEN")
if not HF_TOKEN:
    raise SystemExit("HF_TOKEN not set — see .env file (same as test_indictrans2_hi_sat.py)")

MODEL_NAME = "ai4bharat/indictrans2-indic-indic-dist-320M"
OUT_DIR = "nlp_models/onnx_export"
os.makedirs(OUT_DIR, exist_ok=True)


class EncoderWrapper(nn.Module):
    """Wraps model.get_encoder() so ONNX export only sees plain tensors in/out."""

    def __init__(self, encoder):
        super().__init__()
        self.encoder = encoder

    def forward(self, input_ids, attention_mask):
        out = self.encoder(input_ids=input_ids, attention_mask=attention_mask)
        return out.last_hidden_state


class DecoderStepWrapper(nn.Module):
    """
    Runs ONE decoding step. Takes the last generated token id, the full
    encoder output, and the flattened past_key_values from the previous step.
    Returns logits for the next token plus the updated past_key_values.

    past_key_values structure (standard HF encoder-decoder format):
        tuple of length num_decoder_layers, each element is a tuple of 4 tensors:
        (self_attn_key, self_attn_value, cross_attn_key, cross_attn_value)
    We flatten this to a flat list for ONNX (ONNX doesn't support nested tuples).
    """

    def __init__(self, model):
        super().__init__()
        self.model = model  # full model, has .lm_head and .get_decoder()

    def forward(self, decoder_input_ids, encoder_hidden_states, encoder_attention_mask, *flat_past):
        # Reassemble the flat tensor list back into the nested tuple structure
        past_key_values = None
        if len(flat_past) > 0:
            past_key_values = tuple(
                tuple(flat_past[i : i + 4]) for i in range(0, len(flat_past), 4)
            )

        decoder_out = self.model.get_decoder()(
            input_ids=decoder_input_ids,
            encoder_hidden_states=encoder_hidden_states,
            encoder_attention_mask=encoder_attention_mask,
            past_key_values=past_key_values,
            use_cache=True,
        )
        hidden = decoder_out[0]
        new_past = decoder_out.past_key_values

        logits = self.model.lm_head(hidden)
        if hasattr(self.model, "final_logits_bias"):
            logits = logits + self.model.final_logits_bias

        # Flatten new_past back out for ONNX output
        flat_new_past = []
        for layer_past in new_past:
            flat_new_past.extend(layer_past)

        return (logits, *flat_new_past)


def main():
    print(f"Loading {MODEL_NAME} ...")
    tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME, trust_remote_code=True, token=HF_TOKEN)
    model = AutoModelForSeq2SeqLM.from_pretrained(MODEL_NAME, trust_remote_code=True, token=HF_TOKEN)
    model.eval()

    # ---- 1) Export encoder ----
    print("Exporting encoder...")
    dummy_input_ids = torch.randint(0, 1000, (1, 8), dtype=torch.long)
    dummy_attention_mask = torch.ones((1, 8), dtype=torch.long)

    encoder_wrapper = EncoderWrapper(model.get_encoder())
    torch.onnx.export(
        encoder_wrapper,
        (dummy_input_ids, dummy_attention_mask),
        os.path.join(OUT_DIR, "encoder.onnx"),
        input_names=["input_ids", "attention_mask"],
        output_names=["encoder_hidden_states"],
        dynamic_axes={
            "input_ids": {0: "batch", 1: "src_seq"},
            "attention_mask": {0: "batch", 1: "src_seq"},
            "encoder_hidden_states": {0: "batch", 1: "src_seq"},
        },
        opset_version=17,
    )
    print(f"  Saved: {OUT_DIR}/encoder.onnx")

    # ---- 2) Run one real forward pass to discover past_key_values structure ----
    print("Running a real forward pass to determine decoder cache structure...")
    with torch.no_grad():
        enc_out = model.get_encoder()(input_ids=dummy_input_ids, attention_mask=dummy_attention_mask)
        dummy_decoder_input = torch.tensor([[tokenizer.pad_token_id or 0]], dtype=torch.long)
        decoder_out = model.get_decoder()(
            input_ids=dummy_decoder_input,
            encoder_hidden_states=enc_out.last_hidden_state,
            encoder_attention_mask=dummy_attention_mask,
            use_cache=True,
        )
        first_past = decoder_out.past_key_values
        num_layers = len(first_past)
        print(f"  Decoder layers detected: {num_layers} (x4 tensors each = {num_layers*4} flat cache tensors)")

    # ---- 3) Export decoder step (first call — no past yet) ----
    print("Exporting decoder step (first-token / no-cache case)...")
    decoder_wrapper = DecoderStepWrapper(model)
    torch.onnx.export(
        decoder_wrapper,
        (dummy_decoder_input, enc_out.last_hidden_state, dummy_attention_mask),
        os.path.join(OUT_DIR, "decoder_step_initial.onnx"),
        input_names=["decoder_input_ids", "encoder_hidden_states", "encoder_attention_mask"],
        output_names=["logits"] + [f"past_{i}" for i in range(num_layers * 4)],
        dynamic_axes={
            "decoder_input_ids": {0: "batch", 1: "tgt_seq"},
            "encoder_hidden_states": {0: "batch", 1: "src_seq"},
            "encoder_attention_mask": {0: "batch", 1: "src_seq"},
            "logits": {0: "batch", 1: "tgt_seq"},
        },
        opset_version=17,
    )
    print(f"  Saved: {OUT_DIR}/decoder_step_initial.onnx")

    # ---- 4) Export decoder step WITH cache (subsequent calls) ----
    print("Exporting decoder step (with-cache case)...")
    flat_past_dummy = []
    for layer_past in first_past:
        flat_past_dummy.extend(layer_past)

    input_names = ["decoder_input_ids", "encoder_hidden_states", "encoder_attention_mask"] + \
                  [f"past_in_{i}" for i in range(len(flat_past_dummy))]
    output_names = ["logits"] + [f"past_out_{i}" for i in range(len(flat_past_dummy))]


    cached_dynamic_axes = {
        "decoder_input_ids": {0: "batch", 1: "tgt_seq"},
        "encoder_hidden_states": {0: "batch", 1: "src_seq"},
        "encoder_attention_mask": {0: "batch", 1: "src_seq"},
        "logits": {0: "batch", 1: "tgt_seq"},
    }
    for i in range(len(flat_past_dummy)):
        is_cross_attn = (i % 4) in (2, 3)
        seq_axis_name = "src_seq" if is_cross_attn else "past_tgt_seq"
        cached_dynamic_axes[f"past_in_{i}"] = {0: "batch", 2: seq_axis_name}
        cached_dynamic_axes[f"past_out_{i}"] = {0: "batch", 2: seq_axis_name}

    torch.onnx.export(
        decoder_wrapper,
        (dummy_decoder_input, enc_out.last_hidden_state, dummy_attention_mask, *flat_past_dummy),
        os.path.join(OUT_DIR, "decoder_step_cached.onnx"),
        input_names=input_names,
        output_names=output_names,
        dynamic_axes=cached_dynamic_axes,
        opset_version=17,
    )
    print(f"  Saved: {OUT_DIR}/decoder_step_cached.onnx")

    # ---- 5) Save tokenizer files + metadata needed for the Dart port later ----
    tokenizer.save_pretrained(os.path.join(OUT_DIR, "tokenizer"))
    with open(os.path.join(OUT_DIR, "export_meta.json"), "w") as f:
        json.dump(
            {
                "model_name": MODEL_NAME,
                "num_decoder_layers": num_layers,
                "flat_cache_tensors": num_layers * 4,
                "eos_token_id": tokenizer.eos_token_id,
                "pad_token_id": tokenizer.pad_token_id,
                "decoder_start_token_id": model.config.decoder_start_token_id,
            },
            f,
            indent=2,
        )
    print(f"  Saved: {OUT_DIR}/tokenizer/ and export_meta.json")
    print("\nDone. Next: quantize these ONNX files to INT8.")


if __name__ == "__main__":
    main()