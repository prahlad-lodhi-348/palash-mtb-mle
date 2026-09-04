#!/usr/bin/env python3
"""Auto-transliterate Devanagari (Hindi) to a Latin-phonetic form.

This is a heuristic transliterator (IAST-like) for review purposes only.
It reads `nlp_models/dictionaries/hindi_santhali_500.csv` and writes
`nlp_models/dictionaries/hindi_santhali_500_translit.csv` with the
`santhali_ol_chiki` column filled with the Latin transliteration.

The output is NOT Ol Chiki script; it's a review-friendly phonetic
transliteration to speed up human conversion to Ol Chiki.
"""
from pathlib import Path
import csv

IN_FILE = Path(__file__).parent / 'dictionaries' / 'hindi_santhali_500.csv'
OUT_FILE = Path(__file__).parent / 'dictionaries' / 'hindi_santhali_500_translit.csv'

# Basic mappings for consonants and independent vowels.
CONSONANTS = {
    'क': 'k', 'ख': 'kh', 'ग': 'g', 'घ': 'gh', 'ङ': 'ṅ',
    'च': 'c', 'छ': 'ch', 'ज': 'j', 'झ': 'jh', 'ञ': 'ñ',
    'ट': 'ṭ', 'ठ': 'ṭh', 'ड': 'ḍ', 'ढ': 'ḍh', 'ण': 'ṇ',
    'त': 't', 'थ': 'th', 'द': 'd', 'ध': 'dh', 'न': 'n',
    'प': 'p', 'फ': 'ph', 'ब': 'b', 'भ': 'bh', 'म': 'm',
    'य': 'y', 'र': 'r', 'ल': 'l', 'व': 'v',
    'श': 'ś', 'ष': 'ṣ', 'स': 's', 'ह': 'h',
}

# Independent vowels
VOWELS = {
    'अ': 'a', 'आ': 'ā', 'इ': 'i', 'ई': 'ī', 'उ': 'u', 'ऊ': 'ū',
    'ए': 'e', 'ऐ': 'ai', 'ओ': 'o', 'औ': 'au', 'अं': 'aṃ', 'अः': 'aḥ'
}

# Matras (vowel signs) that modify previous consonant.
MATRAS = {
    'ा': 'ā', 'ि': 'i', 'ी': 'ī', 'ु': 'u', 'ू': 'ū',
    'े': 'e', 'ै': 'ai', 'ो': 'o', 'ौ': 'au', 'ॅ': 'e', 'ॆ': 'e'
}

SPECIAL = {
    'ं': 'ṃ', 'ँ': '̃', 'ः': 'ḥ', '़': '' , 'ँ': '̃', '्': ''
}

def transliterate_token(tok: str) -> str:
    out = ''
    i = 0
    while i < len(tok):
        ch = tok[i]
        # Independent vowel
        if ch in VOWELS:
            out += VOWELS[ch]
            i += 1
            continue
        # Consonant + possible matra or virama
        if ch in CONSONANTS:
            base = CONSONANTS[ch]
            next_idx = i + 1
            matra = ''
            if next_idx < len(tok):
                nxt = tok[next_idx]
                if nxt in MATRAS:
                    matra = MATRAS[nxt]
                    i += 1
                elif nxt == '्':
                    # virama, suppress inherent vowel
                    matra = ''
                    i += 1
            # by default, add inherent 'a' if no matra
            if matra:
                out += base + matra
            else:
                out += base + 'a'
            i += 1
            continue
        # Matra alone or special marks
        if ch in MATRAS:
            out += MATRAS[ch]
            i += 1
            continue
        if ch in SPECIAL:
            out += SPECIAL[ch]
            i += 1
            continue
        # For ASCII, numbers, punctuation, whitespace
        out += ch
        i += 1
    # post-processing: collapse double a -> a, fix common sequences
    out = out.replace('aa', 'ā')
    out = out.replace('aṃa', 'aṃ')
    return out

def transliterate_phrase(phrase: str) -> str:
    parts = phrase.split()
    return ' '.join(transliterate_token(p) for p in parts)

def main():
    rows = []
    with IN_FILE.open(encoding='utf-8') as fh:
        reader = csv.reader(fh)
        header = next(reader)
        for row in reader:
            if not row:
                continue
            hindi = row[0]
            san = row[1] if len(row) > 1 else ''
            conf = row[2] if len(row) > 2 else '0.0'
            if san.strip():
                out_san = san
            else:
                out_san = transliterate_phrase(hindi)
            rows.append((hindi, out_san, conf))

    with OUT_FILE.open('w', encoding='utf-8', newline='') as fh:
        writer = csv.writer(fh)
        writer.writerow(['hindi', 'santhali_ol_chiki', 'confidence'])
        for r in rows:
            writer.writerow(r)

    print(f'Wrote {len(rows)} rows to {OUT_FILE}')

if __name__ == '__main__':
    main()
