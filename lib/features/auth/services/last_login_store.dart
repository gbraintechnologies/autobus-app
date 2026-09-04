import 'package:shared_preferences/shared_preferences.dart';

class LastLoginIdentity {
  const LastLoginIdentity({
    required this.identifier,
    this.displayName = '',
  });

  final String identifier;
  final String displayName;

  String get greetingName {
    final name = displayName.trim();
    if (name.isNotEmpty) return name.split(RegExp(r'\s+')).first;
    final id = identifier.trim();
    if (id.contains('@')) return id.split('@').first;
    return id;
  }
}

/// Remembers who last signed in so a returning session can unlock with PIN.
/// Cleared only on explicit sign-out.
class LastLoginStore {
  static const _key = 'last_login_identifier';
  static const _nameKey = 'last_login_display_name';
  static String? _cached;
  static String? _cachedName;

  static Future<void> save(String identifier, {String? displayName}) async {
    final value = identifier.trim();
    if (value.isEmpty) return;
    _cached = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, value);
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) {
      _cachedName = name;
      await prefs.setString(_nameKey, name);
    }
  }

  static Future<void> saveFromUser(dynamic user) async {
    final name = displayNameFromUser(user);
    final fromProfile = identifierFromUser(user);
    final existing = peek();
    final id = (existing != null && _looksLikeLoginId(existing))
        ? existing
        : (fromProfile ?? existing);
    if (id != null) await save(id, displayName: name);
  }

  static bool _looksLikeLoginId(String value) {
    return value.trim().isNotEmpty && !value.trim().contains(' ');
  }

  static String? peek() {
    final value = _cached?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  static LastLoginIdentity? peekIdentity() {
    final id = peek();
    if (id == null) return null;
    return LastLoginIdentity(
      identifier: id,
      displayName: _cachedName?.trim() ?? '',
    );
  }

  static Future<String?> read() async {
    final identity = await readIdentity();
    return identity?.identifier;
  }

  static Future<LastLoginIdentity?> readIdentity() async {
    final cached = peekIdentity();
    if (cached != null) {
      if (cached.displayName.isNotEmpty) return cached;
    }
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key)?.trim();
    if (value == null || value.isEmpty) {
      _cached = null;
      _cachedName = null;
      return null;
    }
    _cached = value;
    _cachedName = prefs.getString(_nameKey)?.trim();
    return LastLoginIdentity(
      identifier: value,
      displayName: _cachedName ?? '',
    );
  }

  static Future<void> clear() async {
    _cached = null;
    _cachedName = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_nameKey);
  }

  static String? identifierFromUser(dynamic user) {
    if (user is! Map) return null;
    for (final key in const ['email', 'username']) {
      final value = (user[key] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  static String? displayNameFromUser(dynamic user) {
    if (user is! Map) return null;
    for (final key in const ['fullname', 'username', 'email']) {
      final value = (user[key] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return null;
  }
}
