import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';
import '../providers/course_provider.dart';
import '../providers/semester_provider.dart';
import '../widgets/course_card.dart';
import '../widgets/origami_crane.dart';

/// 今日课程 — Home Screen
/// Shows today's courses for the current week.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  /// 「今天没有课程」流动效果:六课程色渐变沿文字平移,彩色丝带流过文字。
  late final AnimationController _breathController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat();

  @override
  void dispose() {
    _breathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Consumer2<CourseProvider, SemesterProvider>(
          builder: (context, courseProvider, semesterProvider, _) {
            final week = semesterProvider.currentWeek;
            final today = DateTime.now();
            final dayOfWeek = today.weekday % 7; // 0=Sun
            final courses = courseProvider.coursesForDayAndWeek(dayOfWeek, week);

            return Column(
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
                        const SizedBox(height: AppSpacing.md),

                        // ── Info panel (semi-transparent overlay) ──
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
                          decoration: BoxDecoration(
                            color: const Color(0x80FFFFFF),
                            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Header ──
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  GestureDetector(
                                    onTap: () => Navigator.pushNamed(context, '/schedule'),
                                    child: const Icon(Icons.calendar_month_outlined, size: AppSpacing.iconSize),
                                  ),
                                  Text('今日课程', style: AppTypography.pageTitle),
                                  GestureDetector(
                                    onTap: () => Navigator.pushNamed(context, '/settings'),
                                    child: const Icon(Icons.settings_outlined, size: AppSpacing.iconSize),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm),

                              // ── Greeting ──
                              Text(_greetingText(dayOfWeek), style: AppTypography.greeting),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                semesterProvider.isSet
                                    ? '${today.month}月${today.day}日 · 第$week周'
                                    : '${today.month}月${today.day}日 · 未选择第一天',
                                style: AppTypography.caption,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: AppSpacing.lg),

                        // ── Course List ──
                        Expanded(
                          child: courses.isEmpty
                              ? _buildEmptyState()
                              : ListView.separated(
                                  itemCount: courses.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.base),
                                  itemBuilder: (context, index) {
                                    final course = courses[index];
                                    return CourseCard(course: course);
                                  },
                                ),
                        ),

                        const SizedBox(height: AppSpacing.lg),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    // 彩蛋:晚上 7 点后太阳变月亮
    final isNight = DateTime.now().hour >= 19;
    final emoji = isNight ? '🌙' : '☀️';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildEmptyIllustration(),
          const SizedBox(height: AppSpacing.lg),
          AnimatedBuilder(
            animation: _breathController,
            builder: (context, _) {
              final t = _breathController.value; // 0..1 单向循环
              return ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) => LinearGradient(
                  begin: Alignment(-1 + t * 2, 0),
                  end: Alignment(1 + t * 2, 0),
                  // 末尾补回首色:带内最后一段"橙→蓝"渐变,
                  // 与平铺的下一周期开头(蓝)连续,消除边界硬切
                  colors: [
                    ...AppColors.courseColors,
                    AppColors.courseColors.first,
                  ],
                  // 平铺重复:渐变带移出文字后自动补下一周期,循环无缝
                  tileMode: TileMode.repeated,
                ).createShader(bounds),
                child: Text(
                  '今天没有课程',
                  style: AppTypography.bodySecondary
                      .copyWith(color: Colors.white),
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('愉快的一天从没课开始 $emoji',
              style: AppTypography.caption.copyWith(color: Colors.black)),
        ],
      ),
    );
  }

  /// 简约空状态插图:折纸鹤(与 App 图标一致),多彩色块,无底色。
  Widget _buildEmptyIllustration() {
    return const OrigamiCrane(size: 96);
  }

  String _greetingText(int dayOfWeek) {
    const days = ['周日好', '周一好', '周二好', '周三好', '周四好', '周五好', '周六好'];
    final now = DateTime.now();
    final hour = now.hour;
    String period = '早上好';
    if (hour >= 12 && hour < 18) period = '下午好';
    if (hour >= 18) period = '晚上好';
    return '${days[dayOfWeek]}，$period';
  }
}
