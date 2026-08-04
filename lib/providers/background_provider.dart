import 'package:flutter/foundation.dart';
import '../models/background_preset.dart';
import '../services/preset_storage_service.dart';

class BackgroundProvider extends ChangeNotifier {
  List<BackgroundPreset> _presets = [];
  bool _loaded = false;
  BackgroundPreset? _active;

  List<BackgroundPreset> get presets => List.unmodifiable(_presets);
  BackgroundPreset? get activePreset => _active;
  bool get loaded => _loaded;

  Future<void> load() async {
    _presets = await PresetStorageService.getAll();
    _active = _presets.cast<BackgroundPreset?>().firstWhere(
          (p) => p!.isActive,
          orElse: () => _presets.isNotEmpty ? _presets.first : null,
        );
    _loaded = true;
    notifyListeners();
  }

  Future<void> addPreset(BackgroundPreset preset) async {
    await PresetStorageService.insert(preset);
    _presets.add(preset);
    notifyListeners();
  }

  Future<void> updatePreset(BackgroundPreset preset) async {
    await PresetStorageService.update(preset);
    final idx = _presets.indexWhere((p) => p.id == preset.id);
    if (idx != -1) _presets[idx] = preset;
    if (_active?.id == preset.id) _active = preset;
    notifyListeners();
  }

  Future<void> deletePreset(String id) async {
    await PresetStorageService.delete(id);
    _presets.removeWhere((p) => p.id == id);
    if (_active?.id == id) {
      _active = _presets.isNotEmpty ? _presets.first : null;
      if (_active != null) {
        _active!.isActive = true;
        await PresetStorageService.setActive(_active!.id);
      }
    }
    notifyListeners();
  }

  Future<void> setActive(String id) async {
    await PresetStorageService.setActive(id);
    for (final p in _presets) {
      p.isActive = p.id == id;
    }
    _active = _presets.firstWhere((p) => p.id == id);
    notifyListeners();
  }
}
