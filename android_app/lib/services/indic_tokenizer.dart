import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class IndicTokenizer {
  final Map<String, int> srcDict;
  final Map<int, String> tgtRev;
  final Map<String, double> scores; // piece -> score (SRC spm)
  static const bos = 0, pad = 1, eos = 2, unk = 3;

  IndicTokenizer._(this.srcDict, this.tgtRev, this.scores);

  static Future<IndicTokenizer> load(String dir) async {
    final src = jsonDecode(await File('$dir/dict.SRC.json').readAsString())
        as Map<String, dynamic>;
    final tgt = jsonDecode(await File('$dir/dict.TGT.json').readAsString())
        as Map<String, dynamic>;
    final srcDict = src.map((k, v) => MapEntry(k, v as int));
    final tgtRev = <int, String>{};
    tgt.forEach((k, v) => tgtRev[v as int] = k);
    final scores = _readSpmScores(await File('$dir/model.SRC').readAsBytes());
    return IndicTokenizer._(srcDict, tgtRev, scores);
  }

  // Minimal protobuf reader: ModelProto.pieces = field 1 (repeated msg),
  // SentencePiece: piece=1 (string), score=2 (float), type=3 (int)
  static Map<String, double> _readSpmScores(Uint8List b) {
    final out = <String, double>{};
    final bd = ByteData.sublistView(b);
    int p = 0;
    int varint() {
      int r = 0, s = 0;
      while (true) {
        final x = b[p++];
        r |= (x & 0x7f) << s;
        if (x & 0x80 == 0) break;
        s += 7;
      }
      return r;
    }

    void skip(int wt) {
      if (wt == 0) {
        varint();
      } else if (wt == 1) {
        p += 8;
      } else if (wt == 2) {
        p += varint();
      } else if (wt == 5) {
        p += 4;
      }
    }

    while (p < b.length) {
      final tag = varint();
      final f = tag >> 3, wt = tag & 7;
      if (f == 1 && wt == 2) {
        final len = varint();
        final end = p + len;
        String? piece;
        double score = 0;
        while (p < end) {
          final t = varint();
          final ff = t >> 3, w = t & 7;
          if (ff == 1 && w == 2) {
            final l = varint();
            piece = utf8.decode(b.sublist(p, p + l));
            p += l;
          } else if (ff == 2 && w == 5) {
            score = bd.getFloat32(p, Endian.little);
            p += 4;
          } else {
            skip(w);
          }
        }
        if (piece != null) out[piece] = score;
      } else {
        skip(wt);
      }
    }
    return out;
  }

  // NFKC substitute for Devanagari nukta composites
  static const _nukta = {
    0x0958: '\u0915\u093C', 0x0959: '\u0916\u093C', 0x095A: '\u0917\u093C',
    0x095B: '\u091C\u093C', 0x095C: '\u0921\u093C', 0x095D: '\u0922\u093C',
    0x095E: '\u092B\u093C', 0x095F: '\u092F\u093C',
  };

  String _normalize(String s) {
    final sb = StringBuffer();
    for (final r in s.runes) {
      sb.write(_nukta[r] ?? String.fromCharCode(r));
    }
    var out = sb.toString();
    // IndicProcessor inserts a space before punctuation so it tokenizes as
    // its own word-initial piece (e.g. "है," -> "है ,") — match that here.
    out = out.replaceAllMapped(
        RegExp(r'\s*([,.?!;:।])'), (m) => ' ${m[1]}');
    return out.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  List<String> _bpe(String word) {
    var syms = word.runes.map((r) => String.fromCharCode(r)).toList();
    while (syms.length > 1) {
      double best = -1e30;
      int bi = -1;
      for (int i = 0; i < syms.length - 1; i++) {
        final sc = scores[syms[i] + syms[i + 1]];
        if (sc != null && sc > best) {
          best = sc;
          bi = i;
        }
      }
      if (bi < 0) break;
      syms[bi] = syms[bi] + syms[bi + 1];
      syms.removeAt(bi + 1);
    }
    return syms;
  }

  // SentencePiece never merges across a letter/punctuation boundary, so
  // split into same-class runs before BPE (matches default split_by_unicode_script).
  static String _classOf(int r) {
    if (r >= 0x0900 && r <= 0x097F) return 'deva';
    if (r >= 0x30 && r <= 0x39) return 'digit';
    return 'other';
  }

  List<String> _splitRuns(String s) {
    final chars = s.runes.toList();
    final out = <String>[];
    int i = 0;
    while (i < chars.length) {
      final start = i;
      if (chars[i] == 0x2581) i++; // leading space marker glues to next run
      if (i >= chars.length) {
        out.add(String.fromCharCodes(chars.sublist(start, i)));
        break;
      }
      final cls = _classOf(chars[i]);
      i++;
      while (i < chars.length &&
          chars[i] != 0x2581 &&
          _classOf(chars[i]) == cls) {
        i++;
      }
      out.add(String.fromCharCodes(chars.sublist(start, i)));
    }
    return out;
  }

  List<int> encode(String hindi,
      {String srcLang = 'hin_Deva', String tgtLang = 'sat_Olck'}) {
    final text = _normalize(hindi);
    final ids = <int>[srcDict[srcLang]!, srcDict[tgtLang]!];
    if (text.isNotEmpty) {
      final sp = '\u2581${text.replaceAll(' ', '\u2581')}';
      for (final run in _splitRuns(sp)) {
        for (final piece in _bpe(run)) {
          ids.add(srcDict[piece] ?? unk);
        }
      }
    }
    ids.add(eos);
    return ids;
  }

  String decode(List<int> ids) {
    final sb = StringBuffer();
    for (final id in ids) {
      if (id == eos || id == pad || id == bos) continue;
      sb.write(tgtRev[id] ?? '');
    }
    var out = sb.toString().replaceAll('\u2581', ' ').trim();
    // Collapse the space IndicProcessor adds before punctuation on the way in.
    out = out.replaceAllMapped(
        RegExp(r'\s+([,.?!;:।])'), (m) => m[1]!);
    return out;
  }
}
