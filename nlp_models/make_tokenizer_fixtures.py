import os, json, shutil
import numpy as np
import onnxruntime as ort
from huggingface_hub import snapshot_download
from transformers import AutoTokenizer
from IndicTransToolkit import IndicProcessor

MODEL = "ai4bharat/indictrans2-indic-indic-dist-320M"
ONNX_DIR = "nlp_models/onnx_export_int8"
OUT = "nlp_models/tokenizer_assets"
SRC_LANG, TGT_LANG = "hin_Deva", "sat_Olck"
TOKEN = os.environ.get("HF_TOKEN")
os.makedirs(OUT, exist_ok=True)

SENTENCES = [
 "बैठ जाओ", "खड़े हो जाओ", "आ जाओ इधर", "सब अपनी पुस्तक निकाले", "कैसे है आप लोग",
 "आज हम पानी के बारे में पढ़ेंगे", "अपनी किताब खोलो और पन्ना दस पर जाओ",
 "क्या तुमने कल का काम पूरा किया?", "यह बहुत अच्छा काम है, शाबाश",
 "सब लोग शांत हो जाओ", "अपनी कॉपी में लिखो", "बोर्ड की तरफ देखो", "ध्यान से सुनो",
 "एक से दस तक गिनती बोलो", "कल स्कूल की छुट्टी है", "अपना नाम बताओ", "आप कहाँ रहते हो?",
 "पानी पीने जाओ", "कृपया अपनी जगह पर बैठ जाइए", "आज का पाठ बहुत आसान है",
 "मैं तुम्हें एक कहानी सुनाता हूँ", "जो बच्चा जानता है वह हाथ उठाए", "सवाल का जवाब दो",
 "पेड़ हमें ऑक्सीजन देते हैं", "सूरज पूर्व दिशा से निकलता है", "दो और तीन मिलकर पाँच होते हैं",
 "कक्षा में शोर मत करो", "अच्छे बच्चे रोज़ स्कूल आते हैं", "कल तुम्हारी परीक्षा है", "घर जाकर अभ्यास करना",
 "आज हम प्राम्भ करेंगे नया आध्या", "क्या आप समझ गए?", "धन्यवाद, कल मिलते हैं", "पहला पन्ना खोलिए",
 "यह चित्र देखो और बताओ इसमें क्या है", "लाल, नीला और हरा रंग पहचानो", "मेरे साथ दोहराओ",
 "बहुत बढ़िया, तालियाँ बजाओ", "हम पंद्रह मिनट पढ़ाई करेंगे", "शिक्षक ने बच्चों को होमवर्क दिया",
]

# 1) copy the tokenizer files the Dart side needs
snap = snapshot_download(MODEL, token=TOKEN, allow_patterns=["*.json", "model.*"])
for name in ["model.SRC", "model.TGT", "dict.SRC.json", "dict.TGT.json"]:
    p = os.path.join(snap, name)
    if os.path.exists(p):
        shutil.copy2(p, os.path.join(OUT, name))
        print("copied", name, os.path.getsize(p), "bytes")
    else:
        print("MISSING", name)

src_dict = json.load(open(os.path.join(OUT, "dict.SRC.json"), encoding="utf-8"))
tgt_dict = json.load(open(os.path.join(OUT, "dict.TGT.json"), encoding="utf-8"))
rev_tgt = {v: k for k, v in tgt_dict.items()}
print("SRC vocab:", len(src_dict), "| TGT vocab:", len(tgt_dict))
print("special ids (SRC):", {t: src_dict.get(t) for t in ["<s>", "<pad>", "</s>", "<unk>", SRC_LANG, TGT_LANG]})

# 2) SentencePiece model info (unigram vs bpe, normalizer)
try:
    from sentencepiece import sentencepiece_model_pb2 as pb
    for name in ["model.SRC", "model.TGT"]:
        m = pb.ModelProto()
        m.ParseFromString(open(os.path.join(OUT, name), "rb").read())
        print(name, "type(1=unigram,2=bpe):", m.trainer_spec.model_type,
              "| pieces:", len(m.pieces),
              "| normalizer:", m.normalizer_spec.name or "(none)",
              "| dummy_prefix:", m.normalizer_spec.add_dummy_prefix,
              "| byte_fallback:", m.trainer_spec.byte_fallback)
except Exception as e:
    print("SPM info unavailable:", e)

# 3) fixtures: preprocessed text, input ids, int8-ONNX output ids + text
tok = AutoTokenizer.from_pretrained(MODEL, trust_remote_code=True, token=TOKEN)
ip = IndicProcessor(inference=True)
meta = json.load(open(f"{ONNX_DIR}/export_meta.json"))
eos, start = meta["eos_token_id"], meta["decoder_start_token_id"]
prov = ["CPUExecutionProvider"]
enc_s = ort.InferenceSession(f"{ONNX_DIR}/encoder.onnx", providers=prov)
dec_i = ort.InferenceSession(f"{ONNX_DIR}/decoder_step_initial.onnx", providers=prov)
dec_c = ort.InferenceSession(f"{ONNX_DIR}/decoder_step_cached.onnx", providers=prov)
cached_names = {i.name for i in dec_c.get_inputs()}

def generate(ids, max_new=60):
    ids = np.array([ids], dtype=np.int64)
    mask = np.ones_like(ids)
    enc = enc_s.run(["encoder_hidden_states"], {"input_ids": ids, "attention_mask": mask})[0]
    out, last, past = [], start, None
    for _ in range(max_new):
        feed = {"decoder_input_ids": np.array([[last]], dtype=np.int64),
                "encoder_hidden_states": enc, "encoder_attention_mask": mask}
        if past is None:
            res = dec_i.run(None, feed)
        else:
            for i, t in enumerate(past):
                feed[f"past_in_{i}"] = t
            res = dec_c.run(None, {k: v for k, v in feed.items() if k in cached_names})
        last = int(np.argmax(res[0][0, -1, :]))
        past = res[1:]
        out.append(last)
        if last == eos:
            break
    return out

fixtures = []
for s in SENTENCES:
    pre = ip.preprocess_batch([s], src_lang=SRC_LANG, tgt_lang=TGT_LANG)
    ids = tok(pre, truncation=True, padding=True, return_tensors="np")["input_ids"][0].tolist()
    out_ids = generate(ids)
    with tok.as_target_tokenizer():
        text = tok.decode(out_ids, skip_special_tokens=True).strip()
    fixtures.append({
        "hindi": s, "preprocessed": pre[0], "input_ids": ids,
        "output_ids": out_ids, "output_pieces": [rev_tgt.get(i) for i in out_ids],
        "output_text": text,
    })
    print(f"{s}  ->  {text}")

json.dump(fixtures, open(os.path.join(OUT, "fixtures.json"), "w", encoding="utf-8"),
          ensure_ascii=False, indent=1)
print("\nWrote", len(fixtures), "fixtures to", OUT)
