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
/// 点底部「确认导入当前课表」→ 注入 JS 提取 DOM → 复用 ImportScreen 预览。
///
/// 学校网站没有手机端,本屏伪装桌面 Chrome UA + 开启宽视口与捏合缩放,
/// 让桌面版页面在手机上可用。
///
/// 账密存储:底部「记住账号密码」开关(默认关)。开启后实时捕获输入框值,
/// 登录跳离登录页时写入 Keystore;再次进入登录页自动填充(验证码手输)。
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

  /// 有已存凭证时自动亮起「记住账密」开关。
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

  /// 页面加载完成:离开登录页时落盘暂存凭证;在登录页时注入捕获与填充。
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
      await _injectCaptureAndFill();
    } catch (_) {}
  }

  /// 注入输入捕获(幂等),已存凭证则同时自动填充。
  Future<void> _injectCaptureAndFill() async {
    try {
      await _controller.runJavaScript(EduLoginScripts.captureScript);
      final saved = await CredentialStorageService.load();
      if (saved != null) {
        await _controller.runJavaScript(
          EduLoginScripts.fillScript(saved.account, saved.password),
        );
      }
    } catch (_) {}
  }

  Future<void> _onToggleRemember(bool on) async {
    setState(() => _rememberCredential = on);
    if (on) {
      await _injectCaptureAndFill();
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

            // ── 记住账密开关 ──
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.contentPadding,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '记住账号密码（验证码仍需手动输入）',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  Switch(
                    value: _rememberCredential,
                    activeTrackColor: AppColors.blue,
                    onChanged: _onToggleRemember,
                  ),
                ],
              ),
            ),

            // ── 底部悬浮按钮区 ──
            Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.contentPadding,
                AppSpacing.sm,
                AppSpacing.contentPadding,
                AppSpacing.md,
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _extracting ? null : _extractAndPreview,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _extracting ? '正在提取课表…' : '确认导入当前课表',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
