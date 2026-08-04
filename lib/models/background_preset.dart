/// Configuration for one blur circle in the diffuse background.
class CircleConfig {
  double x;
  double y;
  double width;
  double height;
  double radius;
  int colorValue; // stored as 0xAARRGGBB

  CircleConfig({
    this.x = 0,
    this.y = 0,
    this.width = 380,
    this.height = 380,
    this.radius = 180,
    this.colorValue = 0xFFFFE3F0,
  });

  Map<String, dynamic> toMap() => {
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'radius': radius,
        'colorValue': colorValue,
      };

  factory CircleConfig.fromMap(Map<String, dynamic> m) => CircleConfig(
        x: (m['x'] as num).toDouble(),
        y: (m['y'] as num).toDouble(),
        width: (m['width'] as num).toDouble(),
        height: (m['height'] as num).toDouble(),
        radius: (m['radius'] as num).toDouble(),
        colorValue: m['colorValue'] as int,
      );
}

/// A saved background preset.
class BackgroundPreset {
  final String id;
  String name;
  List<CircleConfig> circles;
  String? imagePath; // null = no image
  double imageScale;    // 1.0 = image width == frame width
  double imageOffsetX;  // fraction of frame width (0 = centered)
  double imageOffsetY;  // fraction of frame height (0 = centered)
  int imageOriginalW;   // original image pixel width (set on import)
  int imageOriginalH;   // original image pixel height (set on import)
  bool isActive;
  DateTime createdAt;

  BackgroundPreset({
    String? id,
    required this.name,
    required this.circles,
    this.imagePath,
    this.imageScale = 1.0,
    this.imageOffsetX = 0.0,
    this.imageOffsetY = 0.0,
    this.imageOriginalW = 0,
    this.imageOriginalH = 0,
    this.isActive = false,
    DateTime? createdAt,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'circles': circles.map((c) => c.toMap()).toList(),
        'imagePath': imagePath,
        'imageScale': imageScale,
        'imageOffsetX': imageOffsetX,
        'imageOffsetY': imageOffsetY,
        'imageOriginalW': imageOriginalW,
        'imageOriginalH': imageOriginalH,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
      };

  factory BackgroundPreset.fromMap(Map<String, dynamic> m) => BackgroundPreset(
        id: m['id'] as String,
        name: m['name'] as String,
        circles: (m['circles'] as List<dynamic>)
            .map((e) => CircleConfig.fromMap(e as Map<String, dynamic>))
            .toList(),
        imagePath: m['imagePath'] as String?,
        imageScale: (m['imageScale'] as num?)?.toDouble() ?? 1.0,
        imageOffsetX: (m['imageOffsetX'] as num?)?.toDouble() ?? 0.0,
        imageOffsetY: (m['imageOffsetY'] as num?)?.toDouble() ?? 0.0,
        imageOriginalW: m['imageOriginalW'] as int? ?? 0,
        imageOriginalH: m['imageOriginalH'] as int? ?? 0,
        isActive: m['isActive'] as bool? ?? false,
        createdAt: DateTime.tryParse(m['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );

  /// Default preset matching the current hardcoded diffuse background.
  factory BackgroundPreset.defaultPreset() => BackgroundPreset(
        name: '默认',
        isActive: true,
        circles: [
          CircleConfig(
              x: 0, y: 0, width: 380, height: 380, radius: 180, colorValue: 0xFFFFE3F0),
          CircleConfig(
              x: 93, y: 0, width: 380, height: 380, radius: 160, colorValue: 0xFFE0EBFF),
          CircleConfig(
              x: 60, y: 380, width: 360, height: 350, radius: 170, colorValue: 0xFFD6FFF5),
        ],
      );

  /// A preset with no circles — plain white background.
  factory BackgroundPreset.plainWhite() => BackgroundPreset(
        name: '纯白',
        isActive: false,
        circles: [],
      );
}
