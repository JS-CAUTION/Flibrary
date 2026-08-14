import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 教务账号凭证的本地安全存储(支持多账号)。
///
/// - 存储介质: Android Keystore 加密(flutter_secure_storage),不落明文
/// - 只存账号+密码,不存验证码
/// - 多账密列表(自己的 + 同学的),同一账号重复登录覆盖旧密码
/// - 记住「当前选中账号」与「登录时保存」开关状态(下次进入保持)
/// - 所有操作容错:原生通道不可用时静默降级(如测试环境)
class CredentialStorageService {
  CredentialStorageService._();

  static const _storage = FlutterSecureStorage();
  static const _listKey = 'edu_credentials';
  static const _selectedKey = 'edu_credential_selected';
  static const _saveEnabledKey = 'edu_save_enabled';

  // ── 纯逻辑(可单测) ──

  /// 合并新凭证到列表:同账号覆盖,新账号追加,且新账号排最前。
  static List<Map<String, String>> mergeCredentials(
      List<Map<String, String>> list, Map<String, String> newCred) {
    final result = <Map<String, String>>[];
    result.add(newCred);
    for (final item in list) {
      if (item['account'] != newCred['account']) result.add(item);
    }
    return result;
  }

  static String encodeList(List<Map<String, String>> list) => jsonEncode(list);

  static List<Map<String, String>> decodeList(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((m) => {
                'account': (m['account'] as String?) ?? '',
                'password': (m['password'] as String?) ?? '',
                'updatedAt': (m['updatedAt'] as String?) ?? '',
              })
          .where((m) => m['account']!.isNotEmpty && m['password']!.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── 存储操作 ──

  /// 保存凭证(登录跳离登录页且开关开启时调用):同账号覆盖并置顶,并设为当前选中。
  static Future<void> save(String account, String password) async {
    if (account.trim().isEmpty) return;
    final newCred = {
      'account': account.trim(),
      'password': password,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    final merged = mergeCredentials(await loadAllMaps(), newCred);
    try {
      await _storage.write(key: _listKey, value: encodeList(merged));
      await _storage.write(key: _selectedKey, value: account.trim());
    } catch (_) {}
  }

  /// 已存账密列表(新的在前)。
  static Future<List<({String account, String password})>> loadAll() async {
    final maps = await loadAllMaps();
    return [
      for (final m in maps) (account: m['account']!, password: m['password']!),
    ];
  }

  static Future<List<Map<String, String>>> loadAllMaps() async {
    String? raw;
    try {
      raw = await _storage.read(key: _listKey);
    } catch (_) {
      return [];
    }
    if (raw == null || raw.isEmpty) return [];
    return decodeList(raw);
  }

  /// 当前选中的账密(选中账号已不存在时返回 null)。
  static Future<({String account, String password})?> loadSelected() async {
    String? selected;
    try {
      selected = await _storage.read(key: _selectedKey);
    } catch (_) {
      return null;
    }
    if (selected == null || selected.isEmpty) return null;
    final all = await loadAll();
    for (final cred in all) {
      if (cred.account == selected) return cred;
    }
    return null;
  }

  /// 仅读当前选中账号(按钮后缀展示用)。
  static Future<String?> loadSelectedAccount() async {
    final cred = await loadSelected();
    return cred?.account;
  }

  /// 设置当前选中账号(不存在的账号会被忽略)。
  static Future<void> setSelected(String account) async {
    final exists = (await loadAll()).any((c) => c.account == account);
    if (!exists) return;
    try {
      await _storage.write(key: _selectedKey, value: account);
    } catch (_) {}
  }

  /// 删除某个已存账密;若删除的是当前选中,同时清空选中。
  static Future<void> delete(String account) async {
    final maps = await loadAllMaps();
    final kept = maps.where((m) => m['account'] != account).toList();
    try {
      await _storage.write(key: _listKey, value: encodeList(kept));
      final selected = await _storage.read(key: _selectedKey);
      if (selected == account) {
        await _storage.delete(key: _selectedKey);
      }
    } catch (_) {}
  }

  /// 清空全部账密与选中。
  static Future<void> clearAll() async {
    try {
      await _storage.delete(key: _listKey);
      await _storage.delete(key: _selectedKey);
    } catch (_) {}
  }

  // ── 「登录时保存」开关状态 ──

  static Future<bool> loadSaveEnabled() async {
    try {
      final raw = await _storage.read(key: _saveEnabledKey);
      return raw == '1';
    } catch (_) {
      return false;
    }
  }

  static Future<void> setSaveEnabled(bool enabled) async {
    try {
      await _storage.write(key: _saveEnabledKey, value: enabled ? '1' : '0');
    } catch (_) {}
  }
}
