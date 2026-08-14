import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';
import '../services/edu_extractor.dart';
import '../services/edu_login_scripts.dart';
import '../services/credential_storage_service.dart';
import 'import_screen.dart';

/// 教务在线导入 — 内置 WebView 浏览器。
///
/// 用户在校内浏览器自行登录教务 → 「学期理论课表」页,
/// 点底部「导入课表」→ 注入 JS 提取 DOM → 复用 ImportScreen 预览。
///
/// 学校网站没有手机端,本屏伪装桌面 Chrome UA + 开启宽视口与捏合缩放。
///
/// 账密:底部「记住」开关开启后实时捕获输入框值,登录跳离登录页时写入
/// Keystore;「填充」按钮手动把已存账密填入登录表单(验证码手输)。
/// 不自动填充——支持登录其他同学的账号。
class EduWebViewScreen extends StatefulWidget {
  const EduWebViewScreen({super.key});

  @override
  State<EduWebViewScreen> createState() => _EduWebViewScreenState();
}

class _EduWebViewScreenState extends State<EduWebViewScreen> {
  /// 教学一体化平台直通入口,打开即账密登录页(校内直连)。
  static const String _startUrl = 'http://xk.csust.edu.cn';

  /// 伪装桌面 Chrome,让服务器返回桌面版页面。
  static const String _desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

  late final WebViewController _controller;
  bool _extracting = false;
  int _loadProgress = 0;

  // ── 账密存储状态 ──
  bool _rememberCredential = false;
  ({String account, String password})? _pendingCapture;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_desktopUserAgent)
      ..addJavaScriptChannel(
        EduLoginScripts.captureChannelName,
        onMessageReceived: _onCredentialMessage,
      )
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (progress) {
          if (mounted) setState(() => _loadProgress = progress);
        },
        onPageFinished: (url) => _handlePageFinished(url),
      ))
      ..loadRequest(Uri.parse(_startUrl));
    _configureDesktopBrowsing();
    _loadSavedCredential();
  }

  /// 桌面网站适配:宽视口 + 捏合缩放。
  /// 注: loadWithOverviewMode 在 webview_flutter_android 内部默认开启;
  /// built-in zoom 按钮默认不显示(仅保留双指手势缩放)。
  Future<void> _configureDesktopBrowsing() async {
    final android = _controller.platform as AndroidWebViewController;
    await android.setUseWideViewPort(true);
    await android.enableZoom(true);
    await android.setTextZoom(80);
  }

  /// 有已存凭证时亮起「记住」按钮状态(不自动填充)。
  Future<void> _loadSavedCredential() async {
    final account = await CredentialStorageService.loadAccountOnly();
    if (account != null && mounted) {
      setState(() => _rememberCredential = true);
    }
  }

  // ── 账密捕获/保存/填充 ──

  void _onCredentialMessage(JavaScriptMessage message) {
    if (!_rememberCredential) return;
    final cred = EduLoginScripts.parseCaptureMessage(message.message);
    if (cred != null) _pendingCapture = cred;
  }

  /// 页面加载完成:离开登录页时落盘暂存凭证;在登录页时注入捕获监听。
  Future<void> _handlePageFinished(String url) async {
    final leftLoginPage = !url.contains('Logon.do');
    if (leftLoginPage && _pendingCapture != null && _rememberCredential) {
      final cred = _pendingCapture!;
      _pendingCapture = null;
      await CredentialStorageService.save(cred.account, cred.password);
      return;
    }
    if (!_rememberCredential) return;

    try {
      final probe = await _controller
          .runJavaScriptReturningResult(EduLoginScripts.isLoginPageScript);
      final raw = probe is String ? probe : '';
      if (raw.trim().replaceAll('"', '') != 'yes') return;
      await _injectCapture();
    } catch (_) {}
  }

  /// 注入输入捕获监听(幂等)。
  Future<void> _injectCapture() async {
    try {
      await _controller.runJavaScript(EduLoginScripts.captureScript);
    } catch (_) {}
  }

  /// 「填充」按钮:把已存账密填入当前登录表单(不自动填充)。
  Future<void> _fillCredential() async {
    final saved = await CredentialStorageService.load();
    if (saved == null) {
      _showHint('尚未保存账号密码——打开「记住」并登录一次即可保存');
      return;
    }
    try {
      final result = await _controller.runJavaScriptReturningResult(
        EduLoginScripts.fillScript(saved.account, saved.password),
      );
      final raw = result is String ? result : '';
      if (raw.trim().replaceAll('"', '') == 'no_form') {
        _showHint('当前页面没有登录表单');
      } else {
        _showHint('已填充账号 ${saved.account}，请输入验证码登录');
      }
    } catch (_) {
      _showHint('填充失败，请重试');
    }
  }

  /// 「记住」开关:开=捕获并在登录后保存;关=清除已存凭证。
  Future<void> _onToggleRemember(bool on) async {
    setState(() => _rememberCredential = on);
    if (on) {
      await _injectCapture();
      _showHint('已开启记住——登录后将保存账号密码');
    } else {
      _pendingCapture = null;
      await CredentialStorageService.clear();
      _showHint('已清除保存的账号密码');
    }
  }

  // ── 课表提取 ──

  Future<void> _extractAndPreview() async {
    if (_extracting) return;
    setState(() => _extracting = true);

    try {
      final result = await _controller.runJavaScriptReturningResult(
        EduExtractor.injectionScript,
      );
      final raw = result is String ? result : '';

      final courses = EduExtractor.parseCourses(raw);
      if (courses.isEmpty) {
        _showHint('未找到课表，请先登录并打开「学期理论课表」页面');
        return;
      }

      final semester = EduExtractor.parseSemester(raw);

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ImportScreen(
            initialCourses: courses,
            initialSemesterInfo: semester,
          ),
        ),
      );
    } catch (e) {
      _showHint('提取失败，请重试');
    } finally {
      if (mounted) setState(() => _extracting = false);
    }
  }

  void _showHint(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.textPrimary,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── 顶部栏 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.contentPadding,
                AppSpacing.lg,
                AppSpacing.contentPadding,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back,
                        size: AppSpacing.iconSize),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  const Text('教务在线导入', style: AppTypography.pageTitle),
                ],
              ),
            ),

            // ── 加载进度 ──
            if (_loadProgress < 100)
              const LinearProgressIndicator(
                minHeight: 2,
                color: AppColors.blue,
                backgroundColor: AppColors.divider,
              ),

            // ── WebView ──
            Expanded(
              child: WebViewWidget(controller: _controller),
            ),

            // ── 底部操作区: 记住 | 填充 | 导入课表 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.contentPadding,
                AppSpacing.sm,
                AppSpacing.contentPadding,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _RememberButton(
                      active: _rememberCredential,
                      onTap: () => _onToggleRemember(!_rememberCredential),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _FillButton(onTap: _fillCredential),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ImportButton(
                      extracting: _extracting,
                      onTap: _extractAndPreview,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 「记住」按钮 — 状态切换,开启时高亮。
class _RememberButton extends StatelessWidget {
  const _RememberButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _BottomBarButton(
      onTap: onTap,
      icon: Icon(
        active ? Icons.bookmark : Icons.bookmark_border,
        size: 20,
        color: active ? AppColors.blue : AppColors.textSecondary,
      ),
      label: Text(
        '记住',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: active ? AppColors.blue : AppColors.textSecondary,
        ),
      ),
      background: active ? const Color(0xFFE8F0FF) : const Color(0xFFF5F5F8),
      border: Border.all(
        color: active ? AppColors.blue.withValues(alpha: 0.5) : Colors.transparent,
      ),
    );
  }
}

/// 「填充」按钮 — 手动把已存账密填入登录表单。
class _FillButton extends StatelessWidget {
  const _FillButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _BottomBarButton(
      onTap: onTap,
      icon: const Icon(Icons.person_pin_circle_outlined,
          size: 20, color: AppColors.textSecondary),
      label: const Text(
        '填充',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
      background: const Color(0xFFF5F5F8),
      border: Border.all(color: Colors.transparent),
    );
  }
}

/// 「导入课表」按钮 — 渐变科技感主按钮。
class _ImportButton extends StatelessWidget {
  const _ImportButton({required this.extracting, required this.onTap});

  final bool extracting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: extracting ? null : onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: extracting
                ? [const Color(0xFF9DB8E8), const Color(0xFFB8C8EC)]
                : const [Color(0xFF2E7BFF), Color(0xFF00C6FF)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: extracting
              ? null
              : [
                  BoxShadow(
                    color: AppColors.blue.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              extracting ? Icons.hourglass_top : Icons.auto_awesome,
              size: 18,
              color: Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              extracting ? '提取中' : '导入课表',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 底部通用按钮外壳(统一高度/圆角)。
class _BottomBarButton extends StatelessWidget {
  const _BottomBarButton({
    required this.onTap,
    required this.icon,
    required this.label,
    required this.background,
    required this.border,
  });

  final VoidCallback onTap;
  final Widget icon;
  final Widget label;
  final Color background;
  final Border border;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: border,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 5),
            label,
          ],
        ),
      ),
    );
  }
}
