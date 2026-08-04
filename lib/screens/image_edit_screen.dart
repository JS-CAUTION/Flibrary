import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';
import '../models/background_preset.dart';
import '../providers/background_provider.dart';

/// 图片编辑器
///
/// 预览框 = 手机屏比例缩小版「取景窗」。图片在窗下层自由拖动/缩放，
/// 窗内所见 = 首页背景效果。公式与首页 diffuse_background 完全一致。
///
/// 参数语义（比例制）：
///   scale:    图片显示宽度 / 框宽度（1.0 = 等宽，>1 = 放大）
///   offsetX/Y:  平移量，框尺寸的分数（0 = 居中）
///   imageOriginalW/H: 原图像素尺寸（导入时记录，算宽高比用）
class ImageEditScreen extends StatefulWidget {
  final String presetId;
  /// If provided, skip provider lookup (used when creating from custom_screen).
  final BackgroundPreset? preset;

  const ImageEditScreen({super.key, required this.presetId, this.preset});
  @override
  State<ImageEditScreen> createState() => _ImageEditScreenState();
}

class _ImageEditScreenState extends State<ImageEditScreen> {
  late BackgroundPreset _preset;
  bool _dirty = false;
  double _baseScale = 1.0;
  static const _scaleMin = 0.3;
  static const _scaleMax = 4.0;
  bool _editingName = false;
  final _nameController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // If a preset was passed directly, use it; otherwise look it up in provider.
    if (widget.preset != null) {
      _preset = _copyPreset(widget.preset!);
      return;
    }
    final bp = context.read<BackgroundProvider>();
    _preset = _copyPreset(bp.presets.firstWhere((p) => p.id == widget.presetId));
  }

  BackgroundPreset _copyPreset(BackgroundPreset p) {
    return BackgroundPreset(
      id: p.id,
      name: p.name,
      circles: p.circles
          .map((c) => CircleConfig(
                x: c.x, y: c.y, width: c.width, height: c.height,
                radius: c.radius, colorValue: c.colorValue,
              ))
          .toList(),
      imagePath: p.imagePath,
      imageScale: p.imageScale,
      imageOffsetX: p.imageOffsetX,
      imageOffsetY: p.imageOffsetY,
      imageOriginalW: p.imageOriginalW,
      imageOriginalH: p.imageOriginalH,
      isActive: p.isActive,
    );
  }

  // ═══ Actions ═══

  Future<void> _save() async {
    if (_preset.imageScale < 0) return; // sentinel not yet initialized
    await context.read<BackgroundProvider>().updatePreset(_preset);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存'), backgroundColor: AppColors.green),
      );
      setState(() => _dirty = false);
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.single;
    if (picked.path == null) return;

    // Read original pixel dimensions
    int imgW = 0, imgH = 0;
    try {
      final data = await File(picked.path!).readAsBytes();
      final codec = await ui.instantiateImageCodec(data);
      final frame = await codec.getNextFrame();
      imgW = frame.image.width;
      imgH = frame.image.height;
      frame.image.dispose();
      codec.dispose();
    } catch (_) {}

    // Delete old file
    if (_preset.imagePath != null) {
      try { await File(_preset.imagePath!).delete(); } catch (_) {}
    }

    // Copy to app storage
    final dir = await getApplicationDocumentsDirectory();
    final ext = picked.extension ?? 'jpg';
    final destName = 'bg_${DateTime.now().microsecondsSinceEpoch}.$ext';
    await File(picked.path!).copy('${dir.path}/$destName');

    setState(() {
      _preset.imagePath = '${dir.path}/$destName';
      _preset.imageOriginalW = imgW;
      _preset.imageOriginalH = imgH;
      // Initial scale = 原图宽度 / 框宽度（原图效果）
      // frameW unknown here — compute in _buildPreview when we have frameW
      _preset.imageScale = -1; // sentinel: "needs init"
      _preset.imageOffsetX = 0.0;
      _preset.imageOffsetY = 0.0;
      _dirty = true;
    });
  }

  Future<void> _removeImage() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('移除图片'),
        content: const Text('确定移除背景图片吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (_preset.imagePath != null) {
      try { await File(_preset.imagePath!).delete(); } catch (_) {}
    }
    setState(() {
      _preset.imagePath = null;
      _preset.imageScale = 1.0;
      _preset.imageOffsetX = 0.0;
      _preset.imageOffsetY = 0.0;
      _preset.imageOriginalW = 0;
      _preset.imageOriginalH = 0;
      _dirty = true;
    });
  }

  void _resetTransform() {
    setState(() {
      _preset.imageScale = -1; // re-init via frameW
      _preset.imageOffsetX = 0.0;
      _preset.imageOffsetY = 0.0;
      _dirty = true;
    });
  }

  void _showUnsavedDialog() {
    final hasImage = _preset.imagePath != null && File(_preset.imagePath!).existsSync();
    final title = hasImage ? '未保存的更改' : '未导入图片';
    final content = hasImage
        ? '你有未保存的更改，确定要离开吗？'
        : '还没有导入图片，离开后该存档将没有背景图。确定离开吗？';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () { Navigator.pop(ctx); Navigator.pop(context); },
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('离开'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ═══ Build ═══

  @override
  Widget build(BuildContext context) {
    final hasImage = _preset.imagePath != null && File(_preset.imagePath!).existsSync();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_dirty || !hasImage) {
          _showUnsavedDialog();
        } else {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(children: [
            _buildHeader(hasImage),
            const SizedBox(height: AppSpacing.sm),
            Expanded(child: _buildPreview(hasImage)),
            _buildBottomBar(hasImage),
          ]),
        ),
      ),
    );
  }

  Widget _buildHeader(bool hasImage) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.contentPadding),
      child: Column(children: [
        const SizedBox(height: AppSpacing.lg),
        Row(children: [
          GestureDetector(
            onTap: () {
              if (_dirty || !hasImage) {
                _showUnsavedDialog();
              } else {
                Navigator.pop(context);
              }
            },
            child: Icon(Icons.arrow_back, size: AppSpacing.iconSize,
              color: AppColors.textPrimary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _editingName
                ? TextField(
                    controller: _nameController,
                    autofocus: true,
                    style: AppTypography.pageTitle,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintStyle: AppTypography.pageTitle.copyWith(
                        color: AppColors.textPrimary.withOpacity(0.4),
                      ),
                    ),
                    onSubmitted: (v) {
                      setState(() {
                        _editingName = false;
                        _preset.name = v.trim().isNotEmpty ? v.trim() : _preset.name;
                        _dirty = true;
                      });
                    },
                    onTapOutside: (_) {
                      setState(() {
                        _editingName = false;
                        final v = _nameController.text.trim();
                        _preset.name = v.isNotEmpty ? v : _preset.name;
                        _dirty = true;
                      });
                    },
                  )
                : GestureDetector(
                    onTap: () {
                      _nameController.text = _preset.name;
                      setState(() => _editingName = true);
                    },
                    child: Text(_preset.name,
                        style: AppTypography.pageTitle),
                  ),
          ),
          if (_dirty)
            GestureDetector(
              onTap: _save,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                    color: AppColors.blue, borderRadius: BorderRadius.circular(10)),
                child: const Text('保存',
                    style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600,
                        fontSize: 14, color: Colors.white)),
              ),
            ),
        ]),
        const SizedBox(height: AppSpacing.sm),
        Text(hasImage ? '拖动平移 · 双指缩放 · 框内即所得' : '点击"导入图片"选择背景图',
            style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
      ]),
    );
  }

  Widget _buildPreview(bool hasImage) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // 预览框 = 手机屏比例缩小
            final availW = constraints.maxWidth;
            final availH = constraints.maxHeight;
            const phoneAR = 9.0 / 19.5;
            double fw, fh;
            if (availW / availH > phoneAR) {
              fh = availH;
              fw = fh * phoneAR;
            } else {
              fw = availW;
              fh = fw / phoneAR;
            }

            // Sentinel: init scale so image fits inside frame (contain behavior).
            if (hasImage && _preset.imageScale < 0 && _preset.imageOriginalW > 0) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    final imgAspect = _preset.imageOriginalW / _preset.imageOriginalH;
                    // If image is wider than the phone frame, fit by width;
                    // if taller, fit by height so the full image is visible.
                    if (imgAspect >= phoneAR) {
                      _preset.imageScale = 1.0; // dispW = fw
                    } else {
                      _preset.imageScale = (fh * imgAspect / fw).clamp(_scaleMin, _scaleMax);
                    }
                  });
                }
              });
            }

            return Container(
              width: fw, height: fh,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.divider, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: hasImage
                  ? _buildEditableImage(fw, fh)
                  : Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.image_outlined, size: 48, color: AppColors.divider),
                        const SizedBox(height: AppSpacing.md),
                        Text('还未选择图片', style: AppTypography.bodySecondary),
                      ],
                    ),
                ),
            );
          },
        ),
      ),
    );
  }

  /// 触控层：拖动平移 + 双指缩放
  Widget _buildEditableImage(double fw, double fh) {
    return GestureDetector(
      onScaleStart: (_) => _baseScale = _preset.imageScale,
      onScaleUpdate: (d) {
        setState(() {
          if (d.pointerCount == 1) {
            _preset.imageOffsetX += d.focalPointDelta.dx / fw;
            _preset.imageOffsetY += d.focalPointDelta.dy / fh;
          }
          if (d.pointerCount >= 2) {
            _preset.imageScale =
                (_baseScale * d.scale).clamp(_scaleMin, _scaleMax);
          }
          _dirty = true;
        });
      },
      child: _imageLayer(fw, fh),
    );
  }

  /// 图片渲染层 —— 与首页 diffuse_background 公式完全一致
  Widget _imageLayer(double fw, double fh) {
    final scale = _preset.imageScale.clamp(_scaleMin, _scaleMax);
    final w = _preset.imageOriginalW > 0 ? _preset.imageOriginalW : 1080;
    final h = _preset.imageOriginalH > 0 ? _preset.imageOriginalH : 1920;
    final aspect = w > 0 && h > 0 ? w / h : 1.0;

    final dispW = fw * scale;
    final dispH = dispW / aspect;

    return ClipRect(
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            left: (fw - dispW) / 2 + _preset.imageOffsetX * fw,
            top: (fh - dispH) / 2 + _preset.imageOffsetY * fh,
            width: dispW,
            height: dispH,
            child: Image.file(
              File(_preset.imagePath!),
              fit: BoxFit.fill,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(bool hasImage) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.contentPadding, AppSpacing.sm, AppSpacing.contentPadding, AppSpacing.lg),
      decoration: BoxDecoration(
          color: AppColors.background,
          border: Border(top: BorderSide(color: AppColors.divider))),
      child: Row(children: [
        _BarButton(icon: Icons.image_outlined, label: hasImage ? '替换' : '导入图片',
            color: AppColors.blue, onTap: _pickImage),
        if (hasImage) ...[
          const SizedBox(width: AppSpacing.sm),
          _BarButton(icon: null, label: '重置', color: AppColors.textSecondary,
              onTap: _resetTransform),
          const Spacer(),
          _BarButton(icon: null, label: '移除', color: AppColors.danger,
              onTap: _removeImage),
        ],
      ]),
    );
  }
}

class _BarButton extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _BarButton({this.icon, required this.label, required this.color,
    required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: color), const SizedBox(width: 6)
          ],
          Text(label, style: TextStyle(fontFamily: 'Inter',
              fontWeight: FontWeight.w600, fontSize: 13, color: color)),
        ]),
      ),
    );
  }
}
