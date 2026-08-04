import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';
import '../theme/app_shadows.dart';

/// Settings list row — label on left, optional value/chevron on right.
/// Used in Settings screen, Custom screen, and Edit Course form rows.
class SettingsRow extends StatelessWidget {
  final String label;
  final String? value;
  final IconData? icon;
  final bool showChevron;
  final bool showDivider;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool isDestructive;

  const SettingsRow({
    super.key,
    required this.label,
    this.value,
    this.icon,
    this.showChevron = false,
    this.showDivider = true,
    this.onTap,
    this.trailing,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Container(
            height: AppSpacing.formRowHeight,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Label
                Text(
                  label,
                  style: isDestructive
                      ? AppTypography.deleteText
                      : AppTypography.body,
                ),
                // Right side
                if (trailing != null)
                  trailing!
                else if (value != null || showChevron)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (value != null)
                        Text(value!, style: AppTypography.bodySecondary),
                      if (value != null && showChevron)
                        const SizedBox(width: AppSpacing.sm),
                      if (showChevron)
                        Icon(
                          Icons.chevron_right,
                          size: AppSpacing.iconSmall,
                          color: AppColors.textPrimary,
                        ),
                    ],
                  ),
              ],
            ),
          ),
          if (showDivider)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              height: AppSpacing.dividerHeight,
              color: AppColors.divider,
            ),
        ],
      ),
    );
  }
}

/// A settings card containing multiple [SettingsRow] children.
class SettingsCard extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsets? margin;

  const SettingsCard({
    super.key,
    required this.children,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: margin,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        boxShadow: AppShadows.formCard,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}
