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
- ✅ debugFireNow debug button removed (v1.2 dead-code cleanup, confirmed by grep)
- ✅ Notification copy cleaned: no emoji, simple ` · ` separators (纯文本"课程提醒"/"正在上课"/"即将上课")
- ✅ Test suite green: 24/24 — fixed 2 legacy-broken CSV parser tests (test data didn't match real 8-column CSV layout; rewritten with quoted multiline cells + time label in col 0)
- ✅ CSV import encoding fallback: UTF-8 strict → GBK (charset package), 教务原始导出无需转码; real-file e2e 15 courses verified
- ✅ CSV column mapping: day-of-week columns detected from header row (self-adaptive)
- ✅ 教务在线导入: EduWebViewScreen (webview_flutter) — desktop UA + wide viewport + pinch zoom; 直通入口 xk.csust.edu.cn; INTERNET permission + cleartext whitelist (csust.edu.cn)
- ✅ 课表提取: edu_extractor.dart — injection JS (iframe-aware kbtable extraction, innerHTML <br> handling) + Dart parser (multi-course split, odd/even weeks, 姓名(职称) format); Chrome headless verified on real DOM, 15/15 courses match CSV result
- ✅ 导入流程复用: ImportScreen parameterized (initialCourses), 设置页导课入口弹菜单 (CSV/在线导入), 旧课表处理弹窗先于方式选择
- ✅ 账密本地存储: flutter_secure_storage (Keystore 加密) + 记住账密开关 (实时 input 捕获 → 跳离登录页落盘) + 登录页自动填充 (验证码手输) + 设置页「已保存的教务账号」管理 (查看/清除)
- ✅ 登录页调研: form#loginForm / #userAccount / #userPassword / #RANDOMCODE(图片验证码); login() 提交前清空输入框 → 捕获必须实时
- ✅ 多账密交互(v1.5.2): 账密列表存储(同账号覆盖置顶) + 选中持久化 + 「账密：0135」按钮(后缀显示所选后四位,点击展开列表选择/删除,删空自动收起) + 手动「填充」按钮 + 右上角「保存」开关(持久化,默认关)控制登录时保存; 移除设置页账号条目
- ✅ 账密捕获兜底(v1.5.4): input 事件 + 登录按钮点击 + 回车 + submit 三路兜底(覆盖浏览器自动填充无 input 事件的场景)
- ✅ 导入页提示弹窗(v1.5.3~1.5.5): 浅色卡片式(白底深字圆角描边) + 0.75s + 上移(底部 84px)不遮挡三按钮 + 左右边距 32px
- ✅ 网页后退按钮(v1.5.6): 顶部栏 ↶ 后退(无历史置灰); 调研结论: 强智 iframe 逐级后退会触发会话失效整窗跳登录页(服务端机制),故后退=主 frame goBack 回登录页
- ✅ 快捷导入同步(v1.5.9): 课程表页入口与设置页同流程(旧课处理 → 导入方式菜单 → 学期检查)
- ✅ 主界面空状态(v1.5.10~1.5.14): 移除「去添加课程」按钮(保留 header 日历入口); 折纸鹤插图 OrigamiCrane(CustomPaint 重绘 cranes.svg 7 色块,鲜艳暖色系 80% 透明度); 文字纯黑
- ✅ 「今天没有课程」流动效果(v1.5.16~1.5.23): 六课程色渐变 ShaderMask 沿文字平移(TileMode.repeated 平铺无缝 + 末尾补回首色消除边界硬切),渐变带 4 宽每色段 2/3 文字宽,6.4s 周期
- ✅ 彩蛋(v1.5.11): 空状态文案表情晚 7 点后 ☀️→🌙

## Pending
- ⬜ Verify timed notification delivery (changing phone time may not trigger due to Android doze) — code reviewed: Timer aligned to :00/:30 wall-clock, foreground service anchor; needs real-device test
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
│   ├── database_service.dart          # SharedPreferences storage + CSV parse entry + GBK fallback
│   ├── csv_parser.dart                # CSV parser (8-col grid, multi-course cell splitting, header-adaptive columns)
│   ├── preset_storage_service.dart    # Independent preset storage
│   ├── notification_service.dart      # Notification polling (Timer every 30s, Foreground Service)
│   ├── native_alarm_service.dart      # MethodChannel bridge (fireImmediate, cancelNotification)
│   ├── foreground_service_manager.dart # Android Foreground Service start/stop
│   ├── edu_extractor.dart             # 教务在线导入: injection JS + Dart parser (kbtable DOM)
│   ├── edu_login_scripts.dart         # 登录页检测/自动填充/输入捕获 JS
│   └── credential_storage_service.dart # 教务账密 Keystore 加密存储
├── widgets/
│   ├── diffuse_background.dart        # Background renderer (auto-loads preset on first build)
│   ├── course_card.dart               # Course card widget
│   ├── course_detail_sheet.dart       # Bottom sheet detail view
│   ├── edit_course_screen_wire.dart   # Add/edit course form wrapper
│   ├── edge_aware_physics.dart        # Inner week PageView physics: at week 1/20 passes swipe outward to parent
│   ├── origami_crane.dart             # 折纸鹤 CustomPaint（cranes.svg 色块重绘，空状态插图）
│   └── settings_row.dart              # Settings row + card widget
└── screens/
    ├── main_screen.dart                # Root scaffold: fade-transition content switcher (home/schedule)
    ├── home_screen.dart               # Today's courses (home)
    ├── schedule_screen.dart           # Schedule grid (PageView, weeks 1-20)
    ├── settings_screen.dart           # Settings (debug notification button removed in v1.2)
    ├── import_screen.dart             # CSV import with preview (also reused by online import)
    ├── edu_webview_screen.dart        # 教务在线导入 WebView (桌面 UA/缩放/记住账密)
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
