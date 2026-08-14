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
/// 账密交互(多账号):
/// - 右上角「保存」开关:控制登录时是否保存账密(状态持久化,默认关)
/// - 左下「账密：0135」按钮:点击展开已存账密列表,选择/删除;后缀跟随所选
/// - 中间「填充」:把所选账密填入登录表单(不自动填充,验证码手输)
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
  bool _canGoBack = false; // WebView 是否有可后退的历史

  // ── 账密状态 ──
  bool _saveEnabled = false; // 「登录时保存」开关(持久化,默认关)
  String? _selectedAccount; // 当前选中账号(持久化)
  List<({String account, String password})> _credentials = [];
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
    _loadSavedState();
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

  /// 恢复持久化状态:开关、账密列表、选中账号。
  Future<void> _loadSavedState() async {
    final enabled = await CredentialStorageService.loadSaveEnabled();
    final credentials = await CredentialStorageService.loadAll();
    final selected = await CredentialStorageService.loadSelectedAccount();
    if (!mounted) return;
    setState(() {
      _saveEnabled = enabled;
      _credentials = credentials;
      _selectedAccount = selected;
    });
  }

  // ── 账密捕获/保存 ──

  void _onCredentialMessage(JavaScriptMessage message) {
    if (!_saveEnabled) return;
    final cred = EduLoginScripts.parseCaptureMessage(message.message);
    if (cred != null) _pendingCapture = cred;
  }

  /// 页面加载完成:离开登录页时落盘暂存凭证;在登录页时注入捕获监听。
  Future<void> _handlePageFinished(String url) async {
    final canGoBack = await _controller.canGoBack();
    if (mounted && canGoBack != _canGoBack) {
      setState(() => _canGoBack = canGoBack);
    }
    final leftLoginPage = !url.contains('Logon.do');
    if (leftLoginPage && _pendingCapture != null && _saveEnabled) {
      final cred = _pendingCapture!;
      _pendingCapture = null;
      await CredentialStorageService.save(cred.account, cred.password);
      await _loadSavedState(); // 刷新列表 + 选中(保存后自动选中)
      return;
    }
    if (!_saveEnabled) return;

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

  /// 「保存」开关:开=捕获并在登录后保存;关=停止捕获(不动已存账密)。
  Future<void> _onToggleSave(bool on) async {
    setState(() => _saveEnabled = on);
    await CredentialStorageService.setSaveEnabled(on);
    if (on) {
      await _injectCapture();
      _showHint('已开启——登录后将自动保存账密');
    } else {
      _pendingCapture = null;
      _showHint('已关闭——登录时不再保存账密');
    }
  }

  // ── 账密选择/填充 ──

  /// 选中账号的按钮后缀(后四位)。
  String get _selectedSuffix {
    final account = _selectedAccount ?? '';
    if (account.length < 4) return account.isEmpty ? '----' : account;
    return account.substring(account.length - 4);
  }

  /// 「账密：0135」按钮:无账密提示;有账密展开列表选择/删除。
  Future<void> _onPickCredential() async {
    if (_credentials.isEmpty) {
      _showHint('未储存账密');
      return;
    }
    // 局部列表副本:删除时在 sheet 内即时刷新(页面 setState 不会重建 sheet)。
    final sheetCredentials = List.of(_credentials);
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('选择账密',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              for (final cred in List.of(sheetCredentials))
                ListTile(
                  leading: Icon(
                    cred.account == _selectedAccount
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: cred.account == _selectedAccount
                        ? AppColors.blue
                        : AppColors.textSecondary,
                  ),
                  title: Text(cred.account),
                  onTap: () async {
                    await CredentialStorageService.setSelected(cred.account);
                    if (mounted) {
                      setState(() => _selectedAccount = cred.account);
                    }
                    Navigator.pop(ctx);
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 20, color: AppColors.textSecondary),
                    onPressed: () async {
                      await CredentialStorageService.delete(cred.account);
                      if (mounted) {
                        final selected = await CredentialStorageService
                            .loadSelectedAccount();
                        setState(() {
                          _credentials.removeWhere(
                              (c) => c.account == cred.account);
                          _selectedAccount = selected;
                        });
                      }
                      sheetCredentials.removeWhere(
                          (c) => c.account == cred.account);
                      // sheet 内即时刷新;删空则自动收起
                      if (sheetCredentials.isEmpty) {
                        Navigator.pop(ctx);
                      } else {
                        setSheetState(() {});
                      }
                    },
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  /// 「填充」按钮:把当前选中账密填入登录表单。
  Future<void> _fillCredential() async {
    if (_selectedAccount == null) {
      _showHint('未选择账密');
      return;
    }
    final selected = await CredentialStorageService.loadSelected();
    if (selected == null) {
      setState(() => _selectedAccount = null);
      _showHint('未选择账密');
      return;
    }
    try {
      final result = await _controller.runJavaScriptReturningResult(
        EduLoginScripts.fillScript(selected.account, selected.password),
      );
      final raw = result is String ? result : '';
      if (raw.trim().replaceAll('"', '') == 'no_form') {
        _showHint('当前页面没有登录表单');
      } else {
        _showHint('已填充账号 ${selected.account}，请输入验证码登录');
      }
    } catch (_) {
      _showHint('填充失败，请重试');
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
          content: Text(
            message,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 750),
          backgroundColor: Colors.white,
          elevation: 3,
          // 上移避开底部三按钮;左右留足边距(更窄更精致)
          margin: const EdgeInsets.fromLTRB(32, 0, 32, 84),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.divider),
          ),
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
            // ── 顶部栏: 返回 | 标题 | 「保存」开关 ──
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
                  const SizedBox(width: 12),
                  // 浏览器网页后退(无历史时置灰;点击回上一主页面)
                  GestureDetector(
                    onTap: _canGoBack ? () => _controller.goBack() : null,
                    child: Icon(
                      Icons.arrow_circle_left_outlined,
                      size: AppSpacing.iconSize,
                      color: _canGoBack
                          ? AppColors.textPrimary
                          : AppColors.divider,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  const Text('教务在线导入', style: AppTypography.pageTitle),
                  const Spacer(),
                  const Text(
                    '保存',
                    style:
                        TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: _saveEnabled,
                      activeTrackColor: AppColors.blue,
                      onChanged: _onToggleSave,
                    ),
                  ),
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

            // ── 底部操作区: 账密 | 填充 | 导入课表 ──
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
                    child: _BottomBarButton(
                      onTap: _onPickCredential,
                      icon: Icon(
                        Icons.key,
                        size: 18,
                        color: _selectedAccount != null
                            ? AppColors.blue
                            : AppColors.textSecondary,
                      ),
                      label: Text(
                        '账密：$_selectedSuffix',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _selectedAccount != null
                              ? AppColors.blue
                              : AppColors.textSecondary,
                        ),
                      ),
                      background: _selectedAccount != null
                          ? const Color(0xFFE8F0FF)
                          : const Color(0xFFF5F5F8),
                      border: Border.all(
                        color: _selectedAccount != null
                            ? AppColors.blue.withValues(alpha: 0.5)
                            : Colors.transparent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _BottomBarButton(
                      onTap: _fillCredential,
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
                    ),
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
