import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../widgets/diffuse_background.dart';
import '../providers/course_provider.dart';
import '../providers/semester_provider.dart';
import 'home_screen.dart';
import 'schedule_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CourseProvider>().loadCourses();
      context.read<SemesterProvider>().load();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Shared background — solid color + diffuse circles
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(color: AppColors.background),
            child: DiffuseBackground(child: SizedBox.expand()),
          ),
        ),

        // Swipeable pages over transparent background
        PopScope(
          canPop: _currentPage == 0,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && _currentPage > 0) {
              _goToPage(0);
            }
          },
          child: PageView(
            controller: _pageController,
            onPageChanged: (page) => setState(() => _currentPage = page),
            children: [
              HomeScreen(onNavigateToSchedule: () => _goToPage(1)),
              ScheduleScreen(onNavigateBack: () => _goToPage(0)),
            ],
          ),
        ),
      ],
    );
  }
}
