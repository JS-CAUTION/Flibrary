import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 教务账号凭证的本地安全存储。
///
/// - 存储介质: Android Keystore 加密(flutter_secure_storage),不落明文
/// - 只存账号+密码,不存验证码
/// - 单套凭证(强智统一身份认证,直通入口 xk.csust.edu.cn)
/// - 应用卸载即清除(Keystore 数据随应用卸载销毁)
/// - 所有操作容错:原生通道不可用时静默降级(如测试环境)
class CredentialStorageService {
  CredentialStorageService._();

  static const _storage = FlutterSecureStorage();
  static const _key = 'edu_credential';

  /// 保存凭证(用户主动开启「记住账密」后才调用)。
  static Future<void> save(String account, String password) async {
    if (account.trim().isEmpty) return;
    final payload = jsonEncode({
      'account': account.trim(),
      'password': password,
      'updatedAt': DateTime.now().toIso8601String(),
    });
    try {
      await _storage.write(key: _key, value: payload);
    } catch (_) {}
  }

  /// 读取已存凭证;无、损坏或通道异常时返回 null。
  static Future<({String account, String password})?> load() async {
    String? raw;
    try {
      raw = await _storage.read(key: _key);
    } catch (_) {
      return null;
    }
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final account = (map['account'] as String?) ?? '';
      final password = (map['password'] as String?) ?? '';
      if (account.isEmpty || password.isEmpty) return null;
      return (account: account, password: password);
    } catch (_) {
      return null;
    }
  }

  /// 仅读账号(设置页展示用,不暴露密码)。
  static Future<String?> loadAccountOnly() async {
    final cred = await load();
    return cred?.account;
  }

  /// 清除已存凭证。
  static Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {}
  }
}
