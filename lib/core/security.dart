import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Password hashing with PBKDF2-HMAC-SHA256 and a random per-user salt.
/// Stored format: `pbkdf2$<iterations>$<salt base64>$<hash base64>`.
/// Plain-text passwords are never written to the database.
class PasswordHasher {
  PasswordHasher._();

  static const _iterations = 10000;
  static const _keyLength = 32;

  static String hash(String password, {String? saltB64, int? iterations}) {
    final salt = saltB64 != null ? base64.decode(saltB64) : _randomBytes(16);
    final iters = iterations ?? _iterations;
    final key = _pbkdf2(utf8.encode(password), salt, iters, _keyLength);
    return 'pbkdf2\$$iters\$${base64.encode(salt)}\$${base64.encode(key)}';
  }

  static bool verify(String password, String stored) {
    final parts = stored.split('\$');
    if (parts.length != 4 || parts[0] != 'pbkdf2') return false;
    final expected = hash(password,
        saltB64: parts[2], iterations: int.tryParse(parts[1]) ?? _iterations);
    return _constantTimeEquals(expected, stored);
  }

  static Uint8List _pbkdf2(
      List<int> password, List<int> salt, int iterations, int length) {
    final hmac = Hmac(sha256, password);
    final out = BytesBuilder();
    var block = 1;
    while (out.length < length) {
      var u = hmac.convert([...salt, ...(ByteData(4)..setUint32(0, block)).buffer.asUint8List()]).bytes;
      final t = List<int>.from(u);
      for (var i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }
      out.add(t);
      block++;
    }
    return Uint8List.fromList(out.toBytes().sublist(0, length));
  }

  static Uint8List _randomBytes(int n) {
    final r = Random.secure();
    return Uint8List.fromList(List.generate(n, (_) => r.nextInt(256)));
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
