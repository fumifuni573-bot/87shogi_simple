import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/scraped_kifu_view_settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('loads default limit when no preference is saved', () async {
    const store = ScrapedKifuViewSettingsStore();

    final limit = await store.loadLimitPerUser();

    expect(limit, ScrapedKifuViewSettingsStore.defaultLimitPerUser);
  });

  test('saves and reloads a supported limit', () async {
    const store = ScrapedKifuViewSettingsStore();

    await store.saveLimitPerUser(20);

    final limit = await store.loadLimitPerUser();

    expect(limit, 20);
  });

  test('falls back to default for unsupported persisted limit', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'scraped_kifu_limit_per_user_v1': 999,
    });

    const store = ScrapedKifuViewSettingsStore();

    final limit = await store.loadLimitPerUser();

    expect(limit, ScrapedKifuViewSettingsStore.defaultLimitPerUser);
   });
 }
