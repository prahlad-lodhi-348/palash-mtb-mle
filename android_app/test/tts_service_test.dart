import 'package:flutter_test/flutter_test.dart';
import 'package:palash_mtb_mle/services/tts_service.dart';

void main() {
  test('converts Ol Chiki vowels and consonants to Hindi TTS text', () {
    expect(olChikiToDevanagari('ᱦᱮᱞᱚ'), 'हेलॉ');
    expect(olChikiToDevanagari('ᱟᱢ ᱠᱮᱫ'), 'आम केद');
    expect(olChikiToDevanagari('ᱤᱨᱟᱹᱞ'), 'इराल');
  });

  test('keeps an explicit transliteration when provided by translation', () {
    expect(
      translationSpeechText('ᱦᱮᱞᱚ', transliteration: 'हेलो'),
      'हेलो',
    );
    expect(translationSpeechText('ᱦᱮᱞᱚ'), 'हेलॉ');
  });

  test('drops phaarkaa mark and maps Ol Chiki danda', () {
    expect(olChikiToDevanagari('ᱚᱜᱼᱟ'), 'ऑगा');
    expect(olChikiToDevanagari('ᱢᱮ ᱾'), 'मे ।');
  });
}
