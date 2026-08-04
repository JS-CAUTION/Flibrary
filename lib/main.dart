import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app.dart';
import 'theme/app_theme.dart';
import 'providers/course_provider.dart';
import 'providers/semester_provider.dart';
import 'providers/background_provider.dart';
import 'services/notification_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  NotificationService.init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CourseProvider()),
        ChangeNotifierProvider(create: (_) => SemesterProvider()),
        ChangeNotifierProvider(create: (_) => BackgroundProvider()),
      ],
      child: const CourseScheduleApp(),
    ),
  );
}

/// Global font helpers - resolve Outfit/Inter from google_fonts
/// with fallback to system fonts if offline.
class AppFonts {
  static TextStyle outfit({
    double size = 16,
    FontWeight weight = FontWeight.normal,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.outfit(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  static TextStyle inter({
    double size = 16,
    FontWeight weight = FontWeight.normal,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }
}
