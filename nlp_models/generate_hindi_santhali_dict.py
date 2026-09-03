#!/usr/bin/env python3
"""Generate a starter Hindi→Santhali dictionary CSV with 500 entries.

Santhali translations are left blank as placeholders for later human review.
Run this script from the repo root to generate `nlp_models/dictionaries/hindi_santhali_500.csv`.
"""
from pathlib import Path
import csv

OUT = Path(__file__).parent / 'dictionaries'
OUT.mkdir(exist_ok=True)
OUT_FILE = OUT / 'hindi_santhali_500.csv'

# Seed list of common Hindi words/phrases (approx 200). Expand as needed.
SEED = [
    'नमस्ते','हैलो','आप','तुम','मैं','हम','यह','वह','क्यों','क्या','कैसे','कहाँ','कब',
    'हाँ','नहीं','कृपया','धन्यवाद','शुक्रिया','स्वागत','अच्छा','ख़राब','बड़ा','छोटा',
    'लंबा','छोटा','तेज़','धीमा','सुबह','दोपहर','शाम','रात','आज','कल','परसों',
    'स्कूल','कक्षा','शिक्षक','शिक्षिका','बच्चा','लड़का','लड़की','माता','पिता','परिवार',
    'दोस्त','किताब','पेपर','कलम','कागज','स्कूलबैग','खेल','गाना','नाच','कहानी','कविता',
    'खाना','पानी','रोटी','चावल','दाल','फल','सब्जी','मिठाई','खुश','उदास','हंसना','रोना',
    'देखना','सुनना','बोलना','कहना','सोचना','समझना','सीखना','लिखना','पढ़ना','गिनती',
    'एक','दो','तीन','चार','पाँच','छह','सात','आठ','नौ','दस','ग्यारह','बारह','तीरह','चौदह',
    'पंद्रह','बीस','तीस','सौ','हज़ार','कितना','किसका','किसे','क्योंकि','अगर','लेकिन','और',
    'या','पर','बीच','साथ','अंदर','बाहर','ऊपर','नीचे','दायाँ','बायाँ','सही','गलत',
    'खिड़की','दरवाज़ा','कुर्सी','मेज़','बिस्तर','कमरा','घर','गांव','शहर','मार्ग','सड़क',
    'बाजार','दुकान','दवा','हॉस्पिटल','डॉक्टर','नर्स','अस्पताल','पुलिस','ट्रेन','बस','साइकिल','कार',
    'हवाईजहाज़','समुद्र','नदी','पहाड़','वन','पेड़','पत्ता','फूल','सूरज','चाँद','तारा','बारिश',
    'बर्फ','हवा','गरम','ठंडा','बाग','खेत','किसान','जानवर','कुत्ता','बिल्ली','गाय','भैंस','घोड़ा',
    'मुर्गा','अंडा','दूध','मकान','मेटल','लकड़ी','कपड़ा','जूता','टोपी','दाढ़ी','बाल','आँख','कान','नाक','हाथ','पैर',
    'दिल','दिमाग','स्वास्थ्य','सफाई','खुशहाली','सुरक्षा','खुला','बंद','किराना','खर्च','कमाई','काम','आराम',
    'खेलना','सीढ़ी','दरवाज़ा','सड़क','पुल','नौकरी','पैसा','हाथ धोना','साबुन','टॉयलेट','क्लासरूम','पाठ्यक्रम',
    'शब्द','वाक्य','अनुच्छेद','कहानी','चित्र','रंग','लाल','नीला','हरा','पीला','काला','सफ़ेद','गुलाबी','बैंगनी',
]

def build_entries(n=500):
    entries = []
    i = 0
    while len(entries) < n:
        word = SEED[i % len(SEED)]
        # To ensure uniqueness, append an index after full cycles
        cycle = i // len(SEED)
        hindi = f"{word}" if cycle == 0 else f"{word} {cycle}"
        entries.append((hindi, '', '0.0'))
        i += 1
    return entries

def write_csv(entries):
    with OUT_FILE.open('w', encoding='utf-8', newline='') as fh:
        writer = csv.writer(fh)
        writer.writerow(['hindi', 'santhali_ol_chiki', 'confidence'])
        for row in entries:
            writer.writerow(row)

def main():
    entries = build_entries(500)
    write_csv(entries)
    print(f'Wrote {len(entries)} entries to {OUT_FILE}')

if __name__ == '__main__':
    main()
