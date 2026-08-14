import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/main_screen.dart';
import 'screens/home_screen.dart';
import 'screens/schedule_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/import_screen.dart';
import 'screens/edu_webview_screen.dart';
import 'screens/edit_course_screen.dart';
import 'screens/custom_screen.dart';
import 'theme/app_theme.dart';

class CourseScheduleApp extends StatelessWidget {
  const CourseScheduleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '千纸课',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return _fadeRoute(const MainScreen());
          case '/schedule':
            return _fadeRoute(const ScheduleScreen());
          case '/settings':
            return _fadeRoute(const SettingsScreen());
          case '/import':
            return _fadeRoute(const ImportScreen());
          case '/edu-webview':
            return _fadeRoute(const EduWebViewScreen());
          case '/edit-course':
            return _fadeRoute(const EditCourseScreen());
          case '/custom':
            return _fadeRoute(const CustomScreen());
          default:
            return _fadeRoute(const HomeScreen());
        }
      },
    );
  }

  PageRouteBuilder _fadeRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 200),
    );
  }
}
