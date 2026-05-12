import 'dart:convert';
import 'dart:typed_data';

/// Windows-1251 (CP1251) codec for Dart.
///
/// Used by [ThermalPrinterService] to encode Cyrillic + Tajik text into
/// ESC/POS byte streams. The [Generator] from esc_pos_utils_plus accepts
/// a [Codec] in its constructor; passing [cp1251] lets the byte builder
/// encode Cyrillic characters correctly instead of falling back to latin1.
///
/// The table below maps byte positions 0x80–0xFF to their Unicode code
/// points as per the official Windows-1251 specification.
const Cp1251Codec cp1251 = Cp1251Codec._();

/// The Windows-1251 upper-half table: index 0 → byte 0x80, index 127 → 0xFF.
const List<int> _kCp1251Table = [
  // 0x80–0x8F
  0x0402, 0x0403, 0x201A, 0x0453, 0x201E, 0x2026, 0x2020, 0x2021,
  0x20AC, 0x2030, 0x0409, 0x2039, 0x040A, 0x040C, 0x040B, 0x040F,
  // 0x90–0x9F
  0x0452, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
  0xFFFD, 0x2122, 0x0459, 0x203A, 0x045A, 0x045C, 0x045B, 0x045F,
  // 0xA0–0xAF
  0x00A0, 0x040E, 0x045E, 0x0408, 0x00A4, 0x0490, 0x00A6, 0x00A7,
  0x0401, 0x00A9, 0x0404, 0x00AB, 0x00AC, 0x00AD, 0x00AE, 0x0407,
  // 0xB0–0xBF
  0x00B0, 0x00B1, 0x0406, 0x0456, 0x0491, 0x00B5, 0x00B6, 0x00B7,
  0x0451, 0x2116, 0x0454, 0x00BB, 0x0458, 0x0405, 0x0455, 0x0457,
  // 0xC0–0xCF  (А–П)
  0x0410, 0x0411, 0x0412, 0x0413, 0x0414, 0x0415, 0x0416, 0x0417,
  0x0418, 0x0419, 0x041A, 0x041B, 0x041C, 0x041D, 0x041E, 0x041F,
  // 0xD0–0xDF  (Р–Я)
  0x0420, 0x0421, 0x0422, 0x0423, 0x0424, 0x0425, 0x0426, 0x0427,
  0x0428, 0x0429, 0x042A, 0x042B, 0x042C, 0x042D, 0x042E, 0x042F,
  // 0xE0–0xEF  (а–п)
  0x0430, 0x0431, 0x0432, 0x0433, 0x0434, 0x0435, 0x0436, 0x0437,
  0x0438, 0x0439, 0x043A, 0x043B, 0x043C, 0x043D, 0x043E, 0x043F,
  // 0xF0–0xFF  (р–я)
  0x0440, 0x0441, 0x0442, 0x0443, 0x0444, 0x0445, 0x0446, 0x0447,
  0x0448, 0x0449, 0x044A, 0x044B, 0x044C, 0x044D, 0x044E, 0x044F,
];

/// Reverse map: Unicode code-point → CP1251 byte (0x00–0xFF).
/// Built lazily once.
final Map<int, int> _kUnicodeToCp1251 = () {
  final m = <int, int>{};
  // ASCII range is identity.
  for (var i = 0; i < 0x80; i++) {
    m[i] = i;
  }
  // Upper half.
  for (var i = 0; i < _kCp1251Table.length; i++) {
    final cp = _kCp1251Table[i];
    if (cp != 0xFFFD) m[cp] = 0x80 + i;
  }
  return m;
}();

class Cp1251Codec extends Encoding {
  const Cp1251Codec._();

  @override
  String get name => 'windows-1251';

  @override
  Converter<List<int>, String> get decoder => const _Cp1251Decoder();

  @override
  Converter<String, Uint8List> get encoder => const _Cp1251Encoder();
}

class _Cp1251Encoder extends Converter<String, Uint8List> {
  const _Cp1251Encoder();

  @override
  Uint8List convert(String input) {
    final out = <int>[];
    for (final rune in input.runes) {
      if (rune < 0x80) {
        out.add(rune);
      } else {
        final byte = _kUnicodeToCp1251[rune];
        out.add(byte ?? 0x3F);
      }
    }
    return Uint8List.fromList(out);
  }
}

class _Cp1251Decoder extends Converter<List<int>, String> {
  const _Cp1251Decoder();

  @override
  String convert(List<int> input) {
    final sb = StringBuffer();
    for (final byte in input) {
      if (byte < 0x80) {
        sb.writeCharCode(byte);
      } else {
        sb.writeCharCode(_kCp1251Table[byte - 0x80]);
      }
    }
    return sb.toString();
  }
}
