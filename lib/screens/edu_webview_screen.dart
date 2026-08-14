import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';
import '../services/edu_extractor.dart';
import 'import_screen.dart';

/// 教务在线导入 — 内置 WebView 浏览器。
///
/// 用户在校内浏览器自行登录 VPN → 教务 → 「学期理论课表」页,
/// 点底部「确认导入当前课表」→ 注入 JS 提取 DOM → 复用 ImportScreen 预览。
class EduWebViewScreen extends StatefulWidget {
  const EduWebViewScreen({super.key});

  @override
  State<EduWebViewScreen> createState() => _EduWebViewScreenState();
}

class _EduWebViewScreenState extends State<EduWebViewScreen> {
  /// WebVPN 入口,登录后用户自行导航到教务课表页。
  static const String _startUrl = 'https://vpn.csust.edu.cn';

  late final WebViewController _controller;
  bool _extracting = false;
  int _loadProgress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (progress) {
          if (mounted) setState(() => _loadProgress = progress);
        },
      ))
      ..loadRequest(Uri.parse(_startUrl));
  }

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
                  Text('教务在线导入', style: AppTypography.pageTitle),
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
