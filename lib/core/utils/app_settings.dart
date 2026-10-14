import 'package:app_settings/app_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens the OS settings page for this app (to re-enable a denied
/// permission). Provider-wrapped so tests can override it.
final openAppSettingsProvider = Provider<Future<void> Function()>(
  (_) => () => AppSettings.openAppSettings(),
);
