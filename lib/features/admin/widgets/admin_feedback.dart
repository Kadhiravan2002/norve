import 'package:flutter/material.dart';

import '../../../core/theme/norve_admin_tokens.dart';
import 'admin_buttons.dart';

/// Reusable empty state reflecting NORVÉ's editorial aesthetic with smooth entrance fade.
class AdminEmptyState extends StatelessWidget {
  const AdminEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.symmetric(
      vertical: AdminSpacing.huge,
      horizontal: AdminSpacing.xl,
    ),
  });

  final String title;
  final String? message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: AdminMotion.duration(context, AdminMotion.component),
      curve: AdminMotion.curveFast,
      builder: (context, opacity, child) {
        return Opacity(
          opacity: opacity,
          child: child,
        );
      },
      child: Center(
        child: Padding(
          padding: padding,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: AdminColors.surfaceSubtle,
                    shape: BoxShape.circle,
                    border: AdminBorders.subtle,
                  ),
                  child: Icon(
                    icon,
                    size: 26,
                    color: AdminColors.muted,
                  ),
                ),
                const SizedBox(height: AdminSpacing.lg),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AdminTypography.sectionTitle,
                ),
                if (message != null) ...[
                  const SizedBox(height: AdminSpacing.xs),
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: AdminTypography.body.copyWith(
                      color: AdminColors.muted,
                    ),
                  ),
                ],
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: AdminSpacing.xl),
                  AdminButton.secondary(
                    label: actionLabel!,
                    onPressed: onAction,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Minimal loading indicator with smooth entrance animation.
class AdminLoading extends StatelessWidget {
  const AdminLoading({
    super.key,
    this.message,
    this.padding = const EdgeInsets.all(AdminSpacing.huge),
  });

  final String? message;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: AdminMotion.duration(context, AdminMotion.component),
      curve: AdminMotion.curveFast,
      builder: (context, opacity, child) {
        return Opacity(opacity: opacity, child: child);
      },
      child: Center(
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox.square(
                dimension: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AdminColors.charcoal,
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: AdminSpacing.md),
                Text(
                  message!,
                  style: AdminTypography.caption,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Premium modal confirmation dialog for administration operations with
/// polished fade-and-scale micro-interactions adhering to NORVÉ motion tokens.
class AdminConfirmationDialog extends StatelessWidget {
  const AdminConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.isDestructive = false,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String? cancelLabel;
  final bool isDestructive;

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String? cancelLabel = 'Cancel',
    bool isDestructive = false,
  }) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: const Color(0x66000000),
      transitionDuration: AdminMotion.duration(context, AdminMotion.modal),
      pageBuilder: (context, anim, secAnim) => AdminConfirmationDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
      ),
      transitionBuilder: (context, anim, secAnim, child) {
        final curve = CurvedAnimation(
          parent: anim,
          curve: AdminMotion.curveDecelerate,
        );
        return FadeTransition(
          opacity: curve,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.97, end: 1.0).animate(curve),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AdminColors.white,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: AdminRadii.radiusSm,
        side: AdminBorders.sideSubtle,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(AdminSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AdminTypography.modalTitle,
              ),
              const SizedBox(height: AdminSpacing.sm),
              Text(
                message,
                style: AdminTypography.body.copyWith(color: AdminColors.muted),
              ),
              const SizedBox(height: AdminSpacing.xxl),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AdminSpacing.sm,
                  runSpacing: AdminSpacing.sm,
                  children: [
                    if (cancelLabel != null)
                      AdminButton.secondary(
                        label: cancelLabel!,
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                    AdminButton(
                      label: confirmLabel,
                      variant: isDestructive
                          ? AdminButtonVariant.destructive
                          : AdminButtonVariant.primary,
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Standardized notification toast/snackbar helper adhering to NORVÉ tokens.
abstract final class AdminSnackbar {
  static void show(
    BuildContext context, {
    required String message,
    bool isError = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? AdminColors.error : AdminColors.charcoal,
        elevation: 2,
        shape: const RoundedRectangleBorder(
          borderRadius: AdminRadii.radiusSm,
        ),
        margin: const EdgeInsets.all(AdminSpacing.lg),
        duration: duration,
        content: Text(
          message,
          style: AdminTypography.caption.copyWith(
            color: AdminColors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
