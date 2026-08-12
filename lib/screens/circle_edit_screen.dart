import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';
import '../models/background_preset.dart';
import '../providers/background_provider.dart';

/// Edit a preset's circles with drag-to-position on a live preview.
class CircleEditScreen extends StatefulWidget {
  final String presetId;
  /// If provided, skip provider lookup (used when creating from custom_screen).
  final BackgroundPreset? preset;

  const CircleEditScreen({super.key, required this.presetId, this.preset});

  @override
  State<CircleEditScreen> createState() => _CircleEditScreenState();
}

class _CircleEditScreenState extends State<CircleEditScreen> {
  late BackgroundPreset _preset;
  bool _dirty = false;
  bool _initialized = false;
  int? _selectedIndex;
  final GlobalKey _previewKey = GlobalKey();
  bool _editingName = false;
  final _nameController = TextEditingController();

  bool _dragging = false;
  double _previewWidth = 0;
  double _previewHeight = 0;
  Offset _lastDragPos = Offset.zero;

  static const _refWidth = 393.0;
  static const _refHeight = 852.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    if (widget.preset != null) {
      _preset = BackgroundPreset(
        id: widget.preset!.id,
        name: widget.preset!.name,
        circles: widget.preset!.circles
            .map((c) => CircleConfig(
                  x: c.x, y: c.y, width: c.width, height: c.height,
                  radius: c.radius, colorValue: c.colorValue,
                ))
            .toList(),
        imagePath: widget.preset!.imagePath,
        isActive: widget.preset!.isActive,
      );
      return;
    }
    final bp = context.read<BackgroundProvider>();
    final p = bp.presets.firstWhere((p) => p.id == widget.presetId);
    _preset = BackgroundPreset(
      id: p.id,
      name: p.name,
      circles: p.circles
          .map((c) => CircleConfig(
                x: c.x,
                y: c.y,
                width: c.width,
                height: c.height,
                radius: c.radius,
                colorValue: c.colorValue,
              ))
          .toList(),
      imagePath: p.imagePath,
      isActive: p.isActive,
    );
  }

  Future<void> _save() async {
    await context.read<BackgroundProvider>().updatePreset(_preset);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存'), backgroundColor: AppColors.green),
      );
      setState(() => _dirty = false);
    }
  }

  void _markDirty() => setState(() => _dirty = true);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_dirty) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('未保存的更改'),
              content: const Text('你有未保存的更改，确定要离开吗？'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('继续编辑')),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                  child: const Text('放弃更改'),
                ),
              ],
            ),
          );
        } else {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.contentPadding),
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (_dirty) {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('未保存的更改'),
                                  content: const Text('你有未保存的更改，确定要离开吗？'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('继续编辑')),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        Navigator.pop(context);
                                      },
                                      style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                                      child: const Text('放弃更改'),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              Navigator.pop(context);
                            }
                          },
                          child: const Icon(Icons.arrow_back, size: AppSpacing.iconSize),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _editingName
                              ? TextField(
                                  controller: _nameController,
                                  autofocus: true,
                                  style: AppTypography.pageTitle,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
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
                                  child: Text(_preset.name, style: AppTypography.pageTitle),
                                ),
                        ),
                        if (_dirty)
                          GestureDetector(
                            onTap: _save,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.blue,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('保存', style: TextStyle(
                                fontFamily: 'Inter', fontWeight: FontWeight.w600,
                                fontSize: 14, color: Colors.white,
                              )),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _dragging
                          ? '拖动中...松手定位'
                          : _selectedIndex != null
                              ? '已选圆形 ${_selectedIndex! + 1} — 点击其他圆切换'
                              : '点击选中圆形，长按拖动调整位置',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // ── Live preview ──
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _previewWidth = constraints.maxWidth;
                    _previewHeight = constraints.maxHeight;
                    return GestureDetector(
                      onTapUp: (d) => _handleTap(d.localPosition),
                      child: Container(
                        key: _previewKey,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.divider.withOpacity(0.2),
                          border: Border.all(color: AppColors.divider, width: 1),
                        ),
                        child: Stack(
                          children: [
                            ..._preset.circles.asMap().entries.map((e) {
                              final i = e.key;
                              final c = e.value;
                              final isSelected = _selectedIndex == i;
                              return Positioned(
                                left: c.x * _scaleX,
                                top: c.y * _scaleY,
                                child: GestureDetector(
                                  onTap: () => setState(() => _selectedIndex = i),
                                  onLongPressStart: (d) {
                                    setState(() {
                                      _selectedIndex = i;
                                      _dragging = true;
                                      _lastDragPos = d.localPosition;
                                    });
                                  },
                                  onLongPressMoveUpdate: (d) {
                                    final pos = d.localPosition;
                                    final dx = pos.dx - _lastDragPos.dx;
                                    final dy = pos.dy - _lastDragPos.dy;
                                    _lastDragPos = pos;
                                    if (dx.abs() < 0.5 && dy.abs() < 0.5) return;
                                    setState(() {
                                      c.x += dx / _scaleX;
                                      c.y += dy / _scaleY;
                                      _dirty = true;
                                    });
                                  },
                                  onLongPressEnd: (_) {
                                    setState(() {
                                      _dragging = false;
                                    });
                                  },
                                  child: Container(
                                    width: c.width * _scaleX,
                                    height: c.height * _scaleY,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(c.radius * _scaleX),
                                      border: isSelected
                                          ? Border.all(color: AppColors.blue, width: 2)
                                          : null,
                                      gradient: RadialGradient(
                                        colors: [Color(c.colorValue), Color(c.colorValue).withOpacity(0)],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // ── Bottom toolbar ──
              Container(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.contentPadding, AppSpacing.sm,
                    AppSpacing.contentPadding, AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  border: Border(top: BorderSide(color: AppColors.divider)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_selectedIndex != null)
                      _SelectedCircleToolbar(
                          circle: _preset.circles[_selectedIndex!],
                          onChanged: _markDirty,
                          onDelete: _preset.circles.length > 1
                              ? () {
                                  setState(() {
                                    _preset.circles.removeAt(_selectedIndex!);
                                    _selectedIndex = null;
                                    _dirty = true;
                                  });
                                }
                              : null,
                        ),
                    _BottomActions(onAdd: _addCircle, circleCount: _preset.circles.length),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  double get _scaleX => _previewWidth > 0 ? _previewWidth / _refWidth : 1;
  double get _scaleY => _previewHeight > 0 ? _previewHeight / _refHeight : 1;

  void _handleTap(Offset pos) {
    for (int i = _preset.circles.length - 1; i >= 0; i--) {
      final c = _preset.circles[i];
      final left = c.x * _scaleX;
      final top = c.y * _scaleY;
      final w = c.width * _scaleX;
      final h = c.height * _scaleY;
      if (pos.dx >= left && pos.dx <= left + w &&
          pos.dy >= top && pos.dy <= top + h) {
        setState(() => _selectedIndex = i);
        return;
      }
    }
    setState(() => _selectedIndex = null);
  }

  void _addCircle() {
    setState(() {
      final idx = _preset.circles.length;
      _preset.circles.add(CircleConfig(
        x: 60 + idx * 15.0,
        y: 200 + idx * 30.0,
        colorValue: AppColors.courseColors[idx % 6].value,
      ));
      _selectedIndex = _preset.circles.length - 1;
      _dirty = true;
    });
  }
}

/// Bottom bar when a circle is selected.
class _SelectedCircleToolbar extends StatelessWidget {
  final CircleConfig circle;
  final VoidCallback onChanged;
  final VoidCallback? onDelete;

  const _SelectedCircleToolbar({required this.circle, required this.onChanged, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => _pickColor(context),
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: Color(circle.colorValue),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.divider),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Text('颜色'),
            const Spacer(),
            _SizeButton(icon: Icons.zoom_out, onTap: () {
              circle.width = (circle.width - 40).clamp(50, 600);
              circle.height = (circle.height - 40).clamp(50, 600);
              circle.radius = (circle.radius - 20).clamp(20, 400);
              onChanged();
            }),
            const SizedBox(width: 6),
            Text('大小', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(width: 6),
            _SizeButton(icon: Icons.zoom_in, onTap: () {
              circle.width = (circle.width + 40).clamp(50, 600);
              circle.height = (circle.height + 40).clamp(50, 600);
              circle.radius = (circle.radius + 20).clamp(20, 400);
              onChanged();
            }),
            const Spacer(),
            if (onDelete != null)
              GestureDetector(
                onTap: onDelete,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.delete_outline, size: 22, color: AppColors.danger),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 28,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: AppColors.courseColors.asMap().entries.map((e) {
              final color = e.value;
              return GestureDetector(
                onTap: () {
                  circle.colorValue = color.value;
                  onChanged();
                },
                child: Container(
                  width: 28, height: 28,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    border: circle.colorValue == color.value
                        ? Border.all(color: AppColors.textPrimary, width: 2)
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  void _pickColor(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择颜色'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: Color(circle.colorValue),
            onColorChanged: (c) {
              circle.colorValue = c.value;
              onChanged();
            },
            enableAlpha: false,
            hexInputBar: true,
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('确定'))],
      ),
    );
  }
}

class _SizeButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _SizeButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: AppColors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: AppColors.blue),
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  final VoidCallback onAdd;
  final int circleCount;
  const _BottomActions({required this.onAdd, required this.circleCount});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onAdd,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add, size: 18, color: AppColors.blue),
                const SizedBox(width: 6),
                Text('添加圆形', style: TextStyle(
                  fontFamily: 'Inter', fontWeight: FontWeight.w600,
                  fontSize: 13, color: AppColors.blue,
                )),
              ],
            ),
          ),
        ),
        const Spacer(),
        Text('共 $circleCount 个', style: TextStyle(
          fontFamily: 'Inter', fontSize: 12, color: AppColors.textSecondary,
        )),
      ],
    );
  }
}
