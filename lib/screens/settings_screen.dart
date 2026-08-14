import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';
import '../providers/course_provider.dart';
import '../providers/semester_provider.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/credential_storage_service.dart';
import '../widgets/diffuse_background.dart';
import '../widgets/settings_row.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _advanceMinutes = 15;
  String? _savedEduAccount;

  @override
  void initState() {
    super.initState();
    _loadAdvanceMinutes();
    _loadSavedAccount();
  }

  Future<void> _loadAdvanceMinutes() async {
    final m = await StorageService.getAdvanceMinutes();
    if (mounted) setState(() => _advanceMinutes = m);
  }

  Future<void> _loadSavedAccount() async {
    final account = await CredentialStorageService.loadAccountOnly();
    if (mounted) setState(() => _savedEduAccount = account);
  }

  /// 查看/清除已保存的教务账号(仅展示账号,不展示密码)。
  Future<void> _manageSavedAccount(BuildContext context) async {
    if (_savedEduAccount == null) return;
    final action = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('已保存的教务账号'),
        content: Text('账号：$_savedEduAccount\n密码：●●●●●●（仅存于本机加密存储）'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('关闭'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('清除账号密码'),
          ),
        ],
      ),
    );
    if (action == true) {
      await CredentialStorageService.clear();
      if (mounted) {
        setState(() => _savedEduAccount = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已清除保存的教务账号密码'),
            backgroundColor: AppColors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final semesterProvider = context.watch<SemesterProvider>();
    final courseProvider = context.watch<CourseProvider>();

    return Scaffold(
      body: Container(
        color: AppColors.background,
        child: DiffuseBackground(
          child: SafeArea(
            child: Column(
              children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.contentPadding,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSpacing.lg),

                      // ── Header (semi-transparent overlay) ──
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFFFF),
                          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                        ),
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Row(
                            children: [
                              const Icon(Icons.arrow_back, size: AppSpacing.iconSize),
                              const SizedBox(width: AppSpacing.md),
                              Text('设置', style: AppTypography.pageTitle),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      SettingsCard(
                        children: [
                          SettingsRow(
                            label: '学期第一天',
                            value: semesterProvider.firstDay != null
                                ? '${semesterProvider.firstDay!.year}/${semesterProvider.firstDay!.month}/${semesterProvider.firstDay!.day}'
                                : '未设置',
                            showChevron: true,
                            showDivider: true,
                            onTap: () => _pickSemesterFirstDay(context),
                          ),
                          SettingsRow(
                            label: '当前周',
                            value: semesterProvider.isSet
                                ? '第${semesterProvider.currentWeek}周'
                                : '请先设置学期',
                            showChevron: false,
                            showDivider: false,
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSpacing.base),

                      SettingsCard(
                        children: [
                          SettingsRow(
                            label: '课程表导课',
                            showChevron: true,
                            showDivider: false,
                            onTap: () => _startImport(context),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSpacing.base),

                      SettingsCard(
                        children: [
                          SettingsRow(
                            label: '已保存的教务账号',
                            value: _savedEduAccount ?? '未保存',
                            showChevron: _savedEduAccount != null,
                            showDivider: false,
                            onTap: () => _manageSavedAccount(context),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSpacing.base),

                      SettingsCard(
                        children: [
                          SettingsRow(
                            label: '自定义',
                            showChevron: true,
                            showDivider: false,
                            onTap: () =>
                                Navigator.pushNamed(context, '/custom'),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSpacing.base),

                      SettingsCard(
                        children: [
                          SettingsRow(
                            label: '提醒提前量',
                            value: '$_advanceMinutes分钟',
                            showChevron: true,
                            showDivider: false,
                            onTap: () => _pickAdvanceMinutes(context),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSpacing.base),

                      SettingsCard(
                        children: [
                          SettingsRow(
                            label: '已导入课程',
                            value: '${courseProvider.courses.length} 门',
                            showChevron: false,
                            showDivider: true,
                          ),
                          SettingsRow(
                            label: '清空所有数据',
                            showChevron: true,
                            showDivider: false,
                            isDestructive: true,
                            onTap: () => _clearAllData(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }

  void _startImport(BuildContext context) {
    final hasExisting = context.read<CourseProvider>().courses.isNotEmpty;
    if (hasExisting) {
      showDialog<int>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('导入新课表'),
          content: const Text('检测到已有课程数据，请选择导入方式：'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 0),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 2),
              child: const Text('直接导入'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 1),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: const Text('清空并导入'),
            ),
          ],
        ),
      ).then((action) {
        if (action == 0 || action == null || !context.mounted) return;
        if (action == 1) {
          context.read<CourseProvider>().clearAllCourses();
          context.read<SemesterProvider>().reset();
          StorageService.deleteAllData();
        }
        _pickImportSource(context);
      });
    } else {
      _pickImportSource(context);
    }
  }

  void _pickImportSource(BuildContext context) {
    showModalBottomSheet<_ImportSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('选择导入方式',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.file_upload_outlined),
              title: const Text('导入 CSV 文件'),
              subtitle: const Text('Excel/WPS 另存为 CSV 后导入'),
              onTap: () => Navigator.pop(ctx, _ImportSource.csv),
            ),
            ListTile(
              leading: const Icon(Icons.language),
              title: const Text('教务在线导入'),
              subtitle: const Text('内置浏览器登录教务，直接提取课表'),
              onTap: () => Navigator.pop(ctx, _ImportSource.online),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ).then((source) {
      if (source == null || !context.mounted) return;
      _checkSemesterThenImport(context, source);
    });
  }

  void _checkSemesterThenImport(BuildContext context, _ImportSource source) {
    final sp = context.read<SemesterProvider>();
    if (sp.isSet) {
      Navigator.pushNamed(
        context,
        source == _ImportSource.csv ? '/import' : '/edu-webview',
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('未设置学期第一天'),
        content: const Text('请先设置学期第一天，否则周次计算可能不准确。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('稍后再说'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _pickSemesterFirstDay(context);
            },
            child: const Text('去设置'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickSemesterFirstDay(BuildContext context) async {
    final provider = context.read<SemesterProvider>();
    final now = DateTime.now();
    final initialDate = provider.firstDay ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
      helpText: '选择学期第一天',
      cancelText: '取消',
      confirmText: '确定',
    );

    if (picked != null) {
      await provider.setFirstDay(picked);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '学期已设置：${picked.year}/${picked.month}/${picked.day}，第${provider.currentWeek}周'),
            backgroundColor: AppColors.green,
          ),
        );
      }
    }
  }

  Future<void> _clearAllData(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空所有数据'),
        content: const Text('确定要删除所有课程和学期设置吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('确认清空'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await context.read<CourseProvider>().clearAllCourses();
      context.read<SemesterProvider>().reset();
      await StorageService.deleteAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('所有数据已清空'),
            backgroundColor: AppColors.green,
          ),
        );
      }
    }
  }

  void _pickAdvanceMinutes(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('提醒提前量'),
        children: [5, 10, 15, 20, 30].map((m) {
          return SimpleDialogOption(
            onPressed: () async {
              Navigator.pop(ctx);
              await StorageService.setAdvanceMinutes(m);
              if (mounted) setState(() => _advanceMinutes = m);
              // Refresh the polling timer with new advanceMinutes value
              final courses = context.read<CourseProvider>().courses;
              if (courses.isNotEmpty) await NotificationService.scheduleAll(courses);
            },
            child: Row(
              children: [
                Text('${m}分钟'),
                if (m == _advanceMinutes) ...[
                  const Spacer(),
                  const Icon(Icons.check, size: 18, color: AppColors.blue),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

enum _ImportSource { csv, online }
