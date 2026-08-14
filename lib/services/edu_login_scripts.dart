import 'dart:convert';

/// 教务登录页的检测 / 自动填充 / 输入捕获脚本。
///
/// 登录页 DOM(2026-08-14 调研):
/// - `form#loginForm`,账号 `input#userAccount`,密码 `input#userPassword`
/// - 验证码 `input#RANDOMCODE`(图片验证码,必须手输,不参与自动填充)
/// - 登录按钮调 `login()`;⚠️ 该函数提交前会清空账密输入框,
///   因此凭证捕获必须实时(input 事件)经 JavaScriptChannel 推给 Dart
class EduLoginScripts {
  EduLoginScripts._();

  /// JavaScriptChannel 名称,捕获脚本经它把账密推给 Dart 侧。
  static const String captureChannelName = 'EduCredCapture';

  /// 检测当前页面是否为教务登录页(存在账密表单)。
  static const String isLoginPageScript = r'''
(function() {
  var a = document.getElementById('userAccount');
  var p = document.getElementById('userPassword');
  return (a && p) ? 'yes' : 'no';
})();
''';

  /// 生成自动填充脚本。账号/密码经 JSON 转义嵌入,防引号注入破坏脚本。
  static String fillScript(String account, String password) {
    final accountJson = jsonEncode(account);
    final passwordJson = jsonEncode(password);
    return '''
(function() {
  var a = document.getElementById('userAccount');
  var p = document.getElementById('userPassword');
  if (!a || !p) return 'no_form';
  a.value = $accountJson;
  p.value = $passwordJson;
  return 'filled';
})();
''';
  }

  /// 输入捕获脚本(幂等,只安装一次):
  /// - 监听 userAccount/userPassword 的 input 事件
  /// - 登录按钮点击 / 回车 / 表单 submit 时兜底再推一次
  ///   (覆盖浏览器自动填充等不产生 input 事件的场景)
  /// - 经 `EduCredCapture.postMessage` 推送 {account, password}
  static const String captureScript = r'''
(function() {
  if (window.__eduCaptureInstalled) return 'already';
  window.__eduCaptureInstalled = true;
  function push() {
    var a = document.getElementById('userAccount');
    var p = document.getElementById('userPassword');
    if (!a || !p) return;
    try {
      EduCredCapture.postMessage(JSON.stringify({account: a.value, password: p.value}));
    } catch (e) {}
  }
  document.addEventListener('input', function(e) {
    var t = e.target;
    if (t && (t.id === 'userAccount' || t.id === 'userPassword')) push();
  });
  var btn = document.querySelector('button.login_btn');
  if (btn) btn.addEventListener('click', push);
  document.addEventListener('keydown', function(e) {
    if (e.key === 'Enter' || e.keyCode === 13) push();
  });
  var f = document.getElementById('loginForm');
  if (f) f.addEventListener('submit', push);
  return 'installed';
})();
''';

  /// 解析捕获通道消息,返回 (account, password);无效消息返回 null。
  static ({String account, String password})? parseCaptureMessage(String message) {
    try {
      final map = jsonDecode(message) as Map<String, dynamic>;
      final account = (map['account'] as String?) ?? '';
      final password = (map['password'] as String?) ?? '';
      if (account.isEmpty || password.isEmpty) return null;
      return (account: account, password: password);
    } catch (_) {
      return null;
    }
  }
}
