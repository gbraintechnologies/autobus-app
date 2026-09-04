import 'package:shared_preferences/shared_preferences.dart';

/// Remembers the username or email last used to sign in so logout can
/// return straight to the PIN field.
class LastLoginStore {
  static const _key = 'last_login_identifier';
  static String? _cached;

  static Future<void> save(String identifier) async {
    final value = identifier.trim();
    if (value.isEmpty) return;
    _cached = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, value);
  }

  static Future<void> saveFromUser(dynamic user) async {
    if (_cached != null && _cached!.isNotEmpty) return;
    final value = identifierFromUser(user);
    if (value != null) await save(value);
  }

  static String? peek() {
    final value = _cached?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  static Future<String?> read() async {
    final cached = peek();
    if (cached != null) return cached;
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key)?.trim();
    _cached = (value == null || value.isEmpty) ? null : value;
    return _cached;
  }

  static String? identifierFromUser(dynamic user) {
    if (user is! Map) return null;
    for (final key in const ['username', 'fullname', 'email']) {
      final value = (user[key] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return null;
  }
}
