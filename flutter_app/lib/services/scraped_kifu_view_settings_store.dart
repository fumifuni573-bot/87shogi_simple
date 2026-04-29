import 'package:shared_preferences/shared_preferences.dart';

class ScrapedKifuViewSettingsStore {
  const ScrapedKifuViewSettingsStore();

  static const int defaultLimitPerUser = 10;
  static const List<int> supportedLimits = <int>[5, 10, 20];
  static const String _storageKey = 'scraped_kifu_limit_per_user_v1';

  Future<int> loadLimitPerUser() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(_storageKey) ?? defaultLimitPerUser;
    return supportedLimits.contains(value) ? value : defaultLimitPerUser;
  }

  Future<void> saveLimitPerUser(int value) async {
    if (!supportedLimits.contains(value)) {
      throw ArgumentError.value(value, 'value', 'Unsupported scraped kifu limit');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_storageKey, value);
  }
}