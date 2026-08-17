import 'dart:convert';
import 'dart:typed_data';

const int _maxSafeInteger = 9007199254740991;

void assertSafeText(String value) {
  for (var i = 0; i < value.length; i++) {
    final unit = value.codeUnitAt(i);
    if (unit < 0x20 && unit != 0x09 && unit != 0x0a && unit != 0x0d) {
      throw FormatException(
        'JCS: illegal control character U+${unit.toRadixString(16)}',
      );
    }
    if (unit >= 0xd800 && unit <= 0xdbff) {
      final next = i + 1 < value.length ? value.codeUnitAt(i + 1) : null;
      if (next == null || next < 0xdc00 || next > 0xdfff) {
        throw const FormatException('JCS: lone high surrogate');
      }
      i++;
    } else if (unit >= 0xdc00 && unit <= 0xdfff) {
      throw const FormatException('JCS: lone low surrogate');
    }
  }
}

String canonicalize(Object? value) {
  if (value == null) {
    return 'null';
  }
  if (value is bool) {
    return value ? 'true' : 'false';
  }
  if (value is int) {
    if (value > _maxSafeInteger || value < -_maxSafeInteger) {
      throw const FormatException(
        'JCS: integers beyond 2^53-1 must be encoded as strings',
      );
    }
    return value.toString();
  }
  if (value is double) {
    // Matches jcs.js exactly: JS has one numeric type, so an integral
    // double (3.0) is `Number.isInteger(v) === true` and canonicalizes as
    // "3", not "3.0". Only a genuinely fractional or non-finite double is
    // rejected.
    if (!value.isFinite) {
      throw const FormatException('JCS: non-finite numbers cannot be signed');
    }
    if (value != value.roundToDouble()) {
      throw const FormatException(
        'JCS: floating-point numbers must be encoded as strings',
      );
    }
    if (value > _maxSafeInteger || value < -_maxSafeInteger) {
      throw const FormatException(
        'JCS: integers beyond 2^53-1 must be encoded as strings',
      );
    }
    return value.toInt().toString();
  }
  if (value is String) {
    assertSafeText(value);
    return jsonEncode(value);
  }
  if (value is List) {
    return '[${value.map(canonicalize).join(',')}]';
  }
  if (value is Map) {
    final keys = <String>[];
    for (final key in value.keys) {
      if (key is! String) {
        throw const FormatException('JCS: map keys must be strings');
      }
      keys.add(key);
    }
    keys.sort();
    final entries = keys.map(
      (key) => '${jsonEncode(key)}:${canonicalize(value[key])}',
    );
    return '{${entries.join(',')}}';
  }
  throw FormatException('JCS: unsupported type ${value.runtimeType}');
}

Uint8List jcsBytes(Object? value) {
  return Uint8List.fromList(utf8.encode(canonicalize(value)));
}
