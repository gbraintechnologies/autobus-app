import 'package:shared_preferences/shared_preferences.dart';

class AgentModeStore {
  static const _key = 'autobus_agent_mode';

  static Future<bool> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  static Future<void> save(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}
