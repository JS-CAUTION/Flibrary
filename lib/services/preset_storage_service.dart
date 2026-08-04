import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/background_preset.dart';

class PresetStorageService {
  static const _presetsKey = 'background_presets';

  static Future<List<BackgroundPreset>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_presetsKey);
    if (json == null || json.isEmpty) {
      // First launch: seed with default + plain white presets
      final defaults = [
        BackgroundPreset.defaultPreset(),
        BackgroundPreset.plainWhite(),
      ];
      await _saveAll(prefs, defaults);
      return defaults;
    }
    final list = jsonDecode(json) as List<dynamic>;
    final presets = list
        .map((e) => BackgroundPreset.fromMap(e as Map<String, dynamic>))
        .toList();
    // Migrate: ensure plain-white preset exists for older data
    if (!presets.any((p) => p.circles.isEmpty && p.imagePath == null)) {
      presets.add(BackgroundPreset.plainWhite());
      await _saveAll(prefs, presets);
    }
    return presets;
  }

  static Future<void> _saveAll(
      SharedPreferences prefs, List<BackgroundPreset> presets) async {
    await prefs.setString(
        _presetsKey, jsonEncode(presets.map((p) => p.toMap()).toList()));
  }

  static Future<void> saveAll(List<BackgroundPreset> presets) async {
    final prefs = await SharedPreferences.getInstance();
    await _saveAll(prefs, presets);
  }

  static Future<void> insert(BackgroundPreset preset) async {
    final all = await getAll();
    all.add(preset);
    await saveAll(all);
  }

  static Future<void> update(BackgroundPreset preset) async {
    final all = await getAll();
    final idx = all.indexWhere((p) => p.id == preset.id);
    if (idx != -1) all[idx] = preset;
    await saveAll(all);
  }

  static Future<void> delete(String id) async {
    final all = await getAll();
    all.removeWhere((p) => p.id == id);
    await saveAll(all);
  }

  static Future<void> setActive(String id) async {
    final all = await getAll();
    for (final p in all) {
      p.isActive = p.id == id;
    }
    await saveAll(all);
  }
}
