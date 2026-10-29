import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/storage/secure_storage.dart';
import 'branding.dart';

/// Values read from storage before the first frame (see main.dart); defaults in tests.
final initialBrandingProvider = Provider<Branding>((ref) => Branding.defaults);
final initialThemeModeProvider = Provider<ThemeMode>((ref) => ThemeMode.system);

final brandingProvider = StateNotifierProvider<BrandingController, Branding>(
  (ref) => BrandingController(ref.watch(secureStoreProvider), ref.read(initialBrandingProvider)),
);

final themeModeProvider = StateNotifierProvider<ThemeModeController, ThemeMode>(
  (ref) => ThemeModeController(ref.watch(secureStoreProvider), ref.read(initialThemeModeProvider)),
);

ThemeMode themeModeFromName(String? name) => ThemeMode.values.firstWhere((m) => m.name == name, orElse: () => ThemeMode.system);

/// The company's colours; updated whenever the profile loads and reset when the phone is released.
class BrandingController extends StateNotifier<Branding> {
  BrandingController(this._store, super.initial);

  final SecureStore _store;

  Future<void> apply(Branding branding) async {
    if (branding == state) return;
    state = branding;
    await _persist(() => _store.write(SecureKeys.branding, branding.encode()));
  }

  Future<void> reset() async {
    state = Branding.defaults;
    await _persist(() => _store.delete(SecureKeys.branding));
  }
}

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController(this._store, super.initial);

  final SecureStore _store;

  Future<void> set(ThemeMode mode) async {
    if (mode == state) return;
    state = mode;
    await _persist(() => _store.write(SecureKeys.themeMode, mode.name));
  }
}

/// Appearance is a nicety: a storage failure must never break the app.
Future<void> _persist(Future<void> Function() write) async {
  try {
    await write();
  } catch (e) {
    debugPrint('Appearance not saved: $e');
  }
}
