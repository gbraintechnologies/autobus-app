import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Local app-lock PIN. Session tokens stay valid; this only gates the UI
/// after [lockAfter] away from the app.
class PinLockService {
  PinLockService({FlutterSecureStorage? secureStorage})
    : _storage =
          secureStorage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  static const lockAfter = Duration(minutes: 10);
  static const pinLength = 4;

  static const _enabledPrefix = 'pin_lock.enabled.';
  static const _hashPrefix = 'pin_lock.hash.';
  static const _saltPrefix = 'pin_lock.salt.';
  static const _activePrefix = 'pin_lock.last_active.';

  final FlutterSecureStorage _storage;
  static const _timeout = Duration(seconds: 2);

  /// Stable per-user key for PIN storage (id, then email, then phone).
  static String? userKeyFrom(dynamic user) {
    if (user is! Map) return null;
    final id = (user['id'] ?? user['user_id'] ?? user['userId'] ?? '')
        .toString()
        .trim();
    if (id.isNotEmpty) return id;
    final email =
        (user['email'] ?? user['user_email'] ?? user['userEmail'] ?? '')
            .toString()
            .trim();
    if (email.isNotEmpty) return email.toLowerCase();
    final phone =
        (user['phone'] ??
                user['user_phone'] ??
                user['phone_number'] ??
                user['userPhone'] ??
                '')
            .toString()
            .trim();
    if (phone.isNotEmpty) return phone;
    return null;
  }

  static bool isValidPin(String pin) =>
      pin.length == pinLength && RegExp(r'^\d{4}$').hasMatch(pin);

  Future<String?> _read(String key) async {
    try {
      return await _storage.read(key: key).timeout(_timeout);
    } catch (_) {
      return null;
    }
  }

  Future<void> _write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  Future<void> _delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (_) {}
  }

  String _hash(String pin, String salt) {
    return sha256.convert(utf8.encode('$salt:$pin')).toString();
  }

  String _newSalt() {
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    return base64UrlEncode(bytes);
  }

  Future<bool> isEnabled(String userKey) async {
    final v = await _read('$_enabledPrefix$userKey');
    return v == '1';
  }

  Future<void> enable(String userKey, String pin) async {
    if (!isValidPin(pin)) {
      throw ArgumentError('PIN must be 4 digits');
    }
    final salt = _newSalt();
    await _write('$_saltPrefix$userKey', salt);
    await _write('$_hashPrefix$userKey', _hash(pin, salt));
    await _write('$_enabledPrefix$userKey', '1');
    await markActive(userKey);
  }

  Future<void> changePin(String userKey, String currentPin, String nextPin) async {
    final ok = await verify(userKey, currentPin);
    if (!ok) throw StateError('incorrect_pin');
    await enable(userKey, nextPin);
  }

  Future<void> disable(String userKey, String pin) async {
    final ok = await verify(userKey, pin);
    if (!ok) throw StateError('incorrect_pin');
    await _delete('$_enabledPrefix$userKey');
    await _delete('$_hashPrefix$userKey');
    await _delete('$_saltPrefix$userKey');
    await _delete('$_activePrefix$userKey');
  }

  Future<bool> verify(String userKey, String pin) async {
    if (!isValidPin(pin)) return false;
    final salt = await _read('$_saltPrefix$userKey');
    final stored = await _read('$_hashPrefix$userKey');
    if (salt == null || stored == null) return false;
    return stored == _hash(pin, salt);
  }

  Future<void> markActive(String userKey) async {
    await _write(
      '$_activePrefix$userKey',
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  Future<DateTime?> lastActive(String userKey) async {
    final raw = await _read('$_activePrefix$userKey');
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<bool> shouldLock(String userKey) async {
    if (!await isEnabled(userKey)) return false;
    final last = await lastActive(userKey);
    if (last == null) return true;
    return DateTime.now().toUtc().difference(last) >= lockAfter;
  }
}
