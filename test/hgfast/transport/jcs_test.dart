import 'package:fl_clash/hgfast/transport/jcs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canonicalize sorts keys by UTF-16 code unit and drops whitespace', () {
    final canon = canonicalize(<String, Object?>{
      'b': 1,
      'a': 'x',
      'c': <int>[1, 2, 3],
      'd': null,
      'e': true,
      'f': false,
    });
    expect(canon, '{"a":"x","b":1,"c":[1,2,3],"d":null,"e":true,"f":false}');
  });

  test('canonicalize does not HTML-escape and keeps large ints as strings', () {
    final canon = canonicalize(<String, Object?>{
      'amount': '9007199254740993',
      'name': '<a>&"quote"</a>',
    });
    expect(
      canon,
      '{"amount":"9007199254740993","name":"<a>&\\"quote\\"</a>"}',
    );
  });

  test('canonicalize sorts astral-plane keys by UTF-16 code unit', () {
    final canon = canonicalize(<String, Object?>{'z😀a': 1, 'z1': 2});
    expect(canon, '{"z1":2,"z😀a":1}');
  });

  test('canonicalize recurses through nested maps and lists', () {
    final canon = canonicalize(<String, Object?>{
      'nested': <String, Object?>{
        'y': 1,
        'x': <Object?>[
          <String, Object?>{'b': 2, 'a': 1},
        ],
      },
    });
    expect(canon, '{"nested":{"x":[{"a":1,"b":2}],"y":1}}');
  });

  test('canonicalize rejects fractional doubles and out-of-range integers', () {
    expect(() => canonicalize(1.5), throwsFormatException);
    expect(() => canonicalize(9007199254740992), throwsFormatException);
    expect(canonicalize(9007199254740991), '9007199254740991');
  });

  test('canonicalize rejects non-finite doubles', () {
    expect(() => canonicalize(double.nan), throwsFormatException);
    expect(() => canonicalize(double.infinity), throwsFormatException);
    expect(() => canonicalize(double.negativeInfinity), throwsFormatException);
  });

  test('canonicalize accepts an integral double the same as JSON.stringify(3.0) === "3"', () {
    // jcs.js has one numeric type (JS `number`): Number.isInteger(3.0) is
    // true, so it canonicalizes as "3". A Dart `double` that happens to be
    // integral (parsed from JSON, or just written as `3.0`) must match.
    expect(canonicalize(3.0), '3');
    expect(canonicalize(-3.0), '-3');
    expect(canonicalize(0.0), '0');
    expect(canonicalize(-0.0), '0');
    expect(canonicalize(9007199254740991.0), '9007199254740991');
    expect(() => canonicalize(9007199254740992.0), throwsFormatException);
  });

  test('canonicalize rejects control characters and lone surrogates', () {
    final withControlChar = String.fromCharCode(1);
    final loneHighSurrogate = String.fromCharCode(0xd800);
    expect(() => canonicalize(withControlChar), throwsFormatException);
    expect(() => canonicalize(loneHighSurrogate), throwsFormatException);
    expect(canonicalize('ok\ttab\nline'), isA<String>());
  });

  test('canonicalize matches JSON.stringify escaping on the specific characters that differ across encoders', () {
    // Golden values are literally JSON.stringify's own output (node -e),
    // not assumed: forward slash and DEL (0x7F) pass through unescaped;
    // 0x1F is below jcs's own control-character floor and is rejected
    // before any escaping question even arises.
    expect(canonicalize('a/b'), '"a/b"');
    expect(canonicalize(String.fromCharCode(0x7f)), '"${String.fromCharCode(0x7f)}"');
    expect(() => canonicalize(String.fromCharCode(0x1f)), throwsFormatException);
  });

  test('canonicalize leaves an astral-plane string value unescaped, matching JSON.stringify', () {
    expect(canonicalize('z😀a'), '"z😀a"');
  });
}
