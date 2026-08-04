# Course Schedule App — Development State

## Current Status
- **Core UI**: Fully implemented (Home, Schedule, Edit Course, Import, Settings, Custom)
- **Data layer**: SharedPreferences-based storage, CSV course import working
- **Schedule grid**: Three-state course cells (active/inactive/other-week), selection border, horizontal swipe week navigation
- **File parsing**: CSV parser works with LibreOffice/Excel converted files
- **Custom background**: Presets with circle editor (drag-to-position, color picker) and image backgrounds (viewport-style editor)
- **Background auto-load**: DiffuseBackground self-loads on first render (no manual trigger needed)
- **Notifications**: Timer polling every 30s + Foreground Service anchor (replaced periodicallyShow/AlarmManager)

## Done
- ✅ Home screen: today's courses, week number display, greeting
- ✅ Schedule grid: 7-day × 5-slot grid with time labels, PageView-based horizontal swipe (weeks 1-20), arrow buttons + swipe gesture
- ✅ Course cells: active (solid), inactive/other-week (dimmed + strikethrough), selected (bold border), pulse animation for ongoing course
- ✅ Edit course: full form (name, teacher, location, day, periods, weeks, week-mode, color)
- ✅ CSV import: LibreOffice-converted .csv files from 教务系统 (XLS→CSV only, no binary XLS parsing)
- ✅ Bottom tab bar removed
- ✅ Notification center removed from routes
- ✅ Semester first-day picker
- ✅ Course cards on home screen: no tap action (prevent accidental navigation)
- ✅ Course card name: maxLines=1, overflow ellipsis
- ✅ Import flow: data conflict dialog → semester-first-day check
- ✅ Clear all data: resets courses + semester together
- ✅ Custom background: preset management (create/activate/delete), real-preview thumbnails
- ✅ Diffuse background: auto-loads active preset on first render, supports circles + images
- ✅ Circle editor: live fullscreen preview, drag-to-position, color picker, size +/- buttons; bottom bar always shows "add circle" + count (no need to tap away to add more)
- ✅ Image editor: viewport-style phone-ratio preview frame, pinch-to-zoom (0.3x–4x), drag-to-pan, original-size initial scale, pick/replace/remove/reset
- ✅ Default presets: "默认" (3 circles) + "纯白" (empty) seeded on first launch
- ✅ Presets stored independently — not affected by course data clearing
- ✅ Preset card thumbnails: real mini-render of preset appearance
- ✅ Image model: imageOriginalW/H fields for aspect ratio calculation
- ✅ Notification init: permission request, channel creation "课程提醒", boot recovery
- ✅ Notification polling: Timer every 30s, Foreground Service anchor, fireImmediate via MethodChannel
- ✅ Debug button: "调试：5秒后发通知" in settings
- ✅ Android manifest: POST_NOTIFICATIONS, FOREGROUND_SERVICE, FOREGROUND_SERVICE_SPECIAL_USE, VIBRATE
- ✅ Foreground Service anchor with "流转" persistent notification ("上课常驻" channel)
- ✅ MainActivity MethodChannel for notification tap → bringToForeground
- ✅ Dead code removed: notification_center_screen, push_notification_screen, status_bar, app_card
- ✅ Unused dependencies removed: sqflite
- ✅ AlarmManager legacy code removed: AlarmReceiver.kt, BootReceiver.kt, scheduleAlarm/cancelAlarm handlers

## Pending
- ⬜ Verify timed notification delivery (changing phone time may not trigger due to Android doze)
- ⬜ Remove debugFireNow before release
- ⬜ Fix notification content to remove emoji/use simpler separators (Android emoji rendering varies)
- ⬜ Real-world notification test — wait for actual class time

## Project Files
```
lib/
├── main.dart                          # Entry + AppFonts + MultiProvider init + NotificationService.init
├── app.dart                           # MaterialApp + fade routes
├── theme/
│   ├── app_colors.dart                # Color constants (6 course + diffuse + lock screen)
│   ├── app_typography.dart            # Outfit/Inter font styles
│   ├── app_spacing.dart               # Spacing/size constants
│   ├── app_shadows.dart               # Shadow definitions
│   └── app_theme.dart                 # ThemeData composition
├── models/
│   ├── course.dart                    # Course model + WeekMode enum + TimeSlot
│   └── background_preset.dart         # BackgroundPreset + CircleConfig
├── providers/
│   ├── course_provider.dart           # Course CRUD + day/week filtering + notification sync
│   ├── semester_provider.dart         # Semester first day + current week calc
│   └── background_provider.dart       # Preset management
├── services/
│   ├── database_service.dart          # SharedPreferences storage + CSV parse entry point
│   ├── csv_parser.dart                # CSV parser (8-col grid, multi-course cell splitting)
│   ├── preset_storage_service.dart    # Independent preset storage
│   ├── notification_service.dart      # Notification polling (Timer every 30s, Foreground Service)
│   ├── native_alarm_service.dart      # MethodChannel bridge (fireImmediate, cancelNotification)
│   └── foreground_service_manager.dart # Android Foreground Service start/stop
├── widgets/
│   ├── diffuse_background.dart        # Background renderer (auto-loads preset on first build)
│   ├── course_card.dart               # Course card widget
│   ├── course_detail_sheet.dart       # Bottom sheet detail view
│   ├── edit_course_screen_wire.dart   # Add/edit course form wrapper
│   └── settings_row.dart              # Settings row + card widget
└── screens/
    ├── home_screen.dart               # Today's courses (home)
    ├── schedule_screen.dart           # Schedule grid (PageView, weeks 1-20)
    ├── settings_screen.dart           # Settings + debug notification button
    ├── import_screen.dart             # CSV import with preview
    ├── edit_course_screen.dart        # Edit course form
    ├── custom_screen.dart             # Preset management
    ├── circle_edit_screen.dart        # Circle editor
    └── image_edit_screen.dart         # Image editor (viewport preview)
```

## Key Design Decisions
- Storage: SharedPreferences (JSON-serialized), not SQLite
- State: Provider (ChangeNotifier pattern, 3 providers)
- Fonts: google_fonts runtime loading (Outfit + Inter)
- Image params: scale=image width/frame width, offset=fraction of frame
- Week navigation: PageView (1-20), initial page = current week from semester first day
- Background auto-init: DiffuseBackground.load() on first build
- Notifications: Timer polling every 30s + Foreground Service anchor (no AlarmManager)
- Android native: MainActivity (3 MethodChannels), CourseForegroundService (specialUse)
