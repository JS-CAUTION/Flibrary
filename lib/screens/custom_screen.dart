import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';
import '../theme/app_shadows.dart';
import '../models/background_preset.dart';
import '../providers/background_provider.dart';
import 'circle_edit_screen.dart';
import 'image_edit_screen.dart';
import '../widgets/diffuse_background.dart';

/// 自定义 — Custom Screen
/// Preset management: browse, activate, delete saved backgrounds.
class CustomScreen extends StatefulWidget {
  const CustomScreen({super.key});

  @override
  State<CustomScreen> createState() => _CustomScreenState();
}

class _CustomScreenState extends State<CustomScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BackgroundProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
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
                        horizontal: AppSpacing.contentPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppSpacing.lg),

                        // ── Header ──
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Row(
                            children: [
                              const Icon(Icons.arrow_back,
                                  size: AppSpacing.iconSize),
                              const SizedBox(width: AppSpacing.md),
                              Text('自定义', style: AppTypography.pageTitle),
                            ],
                          ),
                        ),

                        const SizedBox(height: AppSpacing.xl),

                        // ── Section title ──
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('背景存档', style: AppTypography.bodySemiBold),
                            GestureDetector(
                              onTap: () => _addPreset(context),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppColors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.add,
                                    size: 20, color: AppColors.blue),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // ── Preset list ──
                        Expanded(
                          child: Consumer<BackgroundProvider>(
                            builder: (context, bp, _) {
                              if (!bp.loaded) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              final presets = bp.presets;
                              if (presets.isEmpty) {
                                return Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.wallpaper,
                                          size: 48,
                                          color: AppColors.divider),
                                      const SizedBox(height: AppSpacing.md),
                                      Text('还没有存档',
                                          style: AppTypography.bodySecondary),
                                    ],
                                  ),
                                );
                              }

                              return ListView.separated(
                                itemCount: presets.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: AppSpacing.sm),
                                itemBuilder: (_, i) =>
                                    _PresetCard(preset: presets[i]),
                              );
                            },
                          ),
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

  void _addPreset(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('新建存档', style: AppTypography.bodySemiBold),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '选择要自定义的内容类型',
                style: AppTypography.caption,
              ),
              const SizedBox(height: AppSpacing.lg),
              _AddOptionCard(
                icon: Icons.blur_on,
                title: '弥散圆形',
                subtitle: '调整背景圆形的颜色、位置和数量',
                onTap: () {
                  Navigator.pop(ctx);
                  _createPreset(context, withCircles: true);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              _AddOptionCard(
                icon: Icons.image_outlined,
                title: '背景图片',
                subtitle: '选择一张图片作为背景',
                onTap: () {
                  Navigator.pop(ctx);
                  _createPreset(context, withCircles: false);
                },
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  void _createPreset(BuildContext context, {required bool withCircles}) async {
    final defaultName = withCircles ? '圆形背景' : '图片背景';
    final controller = TextEditingController(text: defaultName);
    final nameResult = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建存档'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入存档名称',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    final name = (nameResult ?? '').trim();
    if (name.isEmpty) return;

    final bp = context.read<BackgroundProvider>();
    final preset = BackgroundPreset(
      name: name,
      circles: withCircles ? List.from(BackgroundPreset.defaultPreset().circles) : [],
      imagePath: null, // image background starts empty, user imports in editor
    );
    bp.addPreset(preset);

    // Open the editor immediately after creation
    if (!mounted) return;
    Widget page;
    if (withCircles) {
      page = CircleEditScreen(presetId: preset.id, preset: preset);
    } else {
      page = ImageEditScreen(presetId: preset.id, preset: preset);
    }
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }
}

/// Background preset card with inline actions.
/// Tap to activate. Edit and delete buttons are always visible.
class _PresetCard extends StatelessWidget {
  final BackgroundPreset preset;

  const _PresetCard({required this.preset});

  @override
  Widget build(BuildContext context) {
    final bp = context.read<BackgroundProvider>();
    final isActive = preset.isActive;

    return GestureDetector(
      onTap: () {
        if (!isActive) bp.setActive(preset.id);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          boxShadow: AppShadows.formCard,
          border: isActive
              ? Border.all(color: AppColors.blue, width: 2)
              : null,
        ),
        child: Row(
          children: [
            _PresetThumbnail(preset: preset),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          preset.name,
                          style: AppTypography.bodySemiBold,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isActive)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.blue.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '使用中',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              color: AppColors.blue,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Edit button
            GestureDetector(
              onTap: () => _openEditor(context),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit, size: 18, color: AppColors.blue),
              ),
            ),
            const SizedBox(width: 8),
            // Delete button
            GestureDetector(
              onTap: () => _confirmDelete(context, bp),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openEditor(BuildContext context) {
    Widget page;
    if (preset.imagePath != null) {
      page = ImageEditScreen(presetId: preset.id);
    } else {
      page = CircleEditScreen(presetId: preset.id);
    }
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ).then((_) {
      if (context.mounted) {
        context.read<BackgroundProvider>();
      }
    });
  }

  void _confirmDelete(BuildContext context, BackgroundProvider bp) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除存档'),
        content: Text('确定删除「${preset.name}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              bp.deletePreset(preset.id);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

/// Mini preview rendering the actual preset background.
class _PresetThumbnail extends StatelessWidget {
  final BackgroundPreset preset;

  const _PresetThumbnail({required this.preset});

  @override
  Widget build(BuildContext context) {
    const refW = 393.0;
    const refH = 852.0;

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sc = constraints.maxWidth / refW;
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // Background image (scaled + positioned)
              if (preset.imagePath != null && File(preset.imagePath!).existsSync())
                Positioned.fill(
                  child: _MiniImageLayer(
                    preset: preset,
                    thumbW: constraints.maxWidth,
                    thumbH: constraints.maxHeight,
                    sc: sc,
                  ),
                ),
              // Circles
              ...preset.circles.map((c) => Positioned(
                    left: c.x * sc,
                    top: c.y * sc,
                    child: Container(
                      width: c.width * sc,
                      height: c.height * sc,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(c.radius * sc),
                        gradient: RadialGradient(
                          colors: [
                            Color(c.colorValue),
                            Color(c.colorValue).withOpacity(0),
                          ],
                        ),
                      ),
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }
}

/// Tiny image layer for thumbnail — same formula as diffuse_background.
class _MiniImageLayer extends StatelessWidget {
  final BackgroundPreset preset;
  final double thumbW;
  final double thumbH;
  final double sc;

  const _MiniImageLayer({
    required this.preset,
    required this.thumbW,
    required this.thumbH,
    required this.sc,
  });

  @override
  Widget build(BuildContext context) {
    final imgW = preset.imageOriginalW > 0 ? preset.imageOriginalW : 1080;
    final imgH = preset.imageOriginalH > 0 ? preset.imageOriginalH : 1920;
    final aspect = imgW / imgH;
    final scale = preset.imageScale;
    final dispW = thumbW * scale;
    final dispH = dispW / aspect;

    return ClipRect(
      child: Stack(
        children: [
          Positioned(
            left: (thumbW - dispW) / 2 + preset.imageOffsetX * thumbW,
            top: (thumbH - dispH) / 2 + preset.imageOffsetY * thumbH,
            width: dispW,
            height: dispH,
            child: Image.file(
              File(preset.imagePath!),
              fit: BoxFit.fill,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

/// An option card in the add-preset bottom sheet.
class _AddOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AddOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.blue, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.bodyMedium),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTypography.caption),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}
