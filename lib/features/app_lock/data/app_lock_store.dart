import 'package:shared_preferences/shared_preferences.dart';

import '../domain/app_lock_models.dart';

class AppLockStore {
  AppLockStore(this._prefs);
  final SharedPreferences _prefs;

  static const _enabled = 'applock.enabled';
  static const _timeout = 'applock.timeout';
  static const _hide = 'applock.hidePreview';

  AppLockSettings load() => AppLockSettings(
    enabled: _prefs.getBool(_enabled) ?? false,
    timeout: AppLockTimeout.fromName(_prefs.getString(_timeout)),
    hidePreview: _prefs.getBool(_hide) ?? true,
  );

  Future<void> save(AppLockSettings s) async {
    await _prefs.setBool(_enabled, s.enabled);
    await _prefs.setString(_timeout, s.timeout.name);
    await _prefs.setBool(_hide, s.hidePreview);
  }
}
