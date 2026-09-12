import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/glass_depth.dart';

/// True when the active theme is the Glass theme.
/// Every glass-specific visual below is gated behind this so Dark / Light /
/// AMOLED always keep their exact existing appearance.
bool isGlassTheme(BuildContext context) => PyloGlass.isActive(context);

/// Frosted-glass 3-surface wrapper shared by the whole Glass design system.
///
/// In Glass mode it renders a translucent surface at one of the three depth
/// levels (see [GlassDepth]) with a carefully controlled blur so surfaces
/// appear to float above the ambient background. In any other theme, the
/// child passes through untouched.
///
/// Performance rules baked in:
///  - [blur] defaults to the depth level's configured value and is only
///    applied when non-zero (BackdropFilter is expensive).
///  - The surface is a single [Container] (no nested blur layers).
///  - When the app is not in Glass mode there is zero decoration cost.
class GlassSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final GlassDepth depth;
  final double? blur;
  final Color? surfaceColor;
  final Color? borderColor;
  final List<BoxShadow>? shadows;
  final VoidCallback? onTap;

  const GlassSurface({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 20,
    this.depth = GlassDepth.level2,
    this.blur,
    this.surfaceColor,
    this.borderColor,
    this.shadows,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!isGlassTheme(context)) {
      Widget result = padding != null
          ? Padding(padding: padding!, child: child)
          : child;
      if (onTap != null) {
        result = InkWell(onTap: onTap, child: result);
      }
      return result;
    }

    final config = GlassDepthConfig.of(depth);
    final effectiveColor = surfaceColor ??
        _surfaceForDepth(context, depth, config.opacity);
    final effectiveBlur = blur ?? config.blur;
    final effectiveShadows = shadows ?? config.shadows;

    Widget surface = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: effectiveColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? config.borderColor,
          width: 1,
        ),
        boxShadow: effectiveShadows,
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );

    if (onTap != null) {
      surface = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: surface,
        ),
      );
    }

    if (effectiveBlur > 0) {
      surface = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: effectiveBlur * 0.5,
            sigmaY: effectiveBlur * 0.5,
          ),
          child: surface,
        ),
      );
    }

    return RepaintBoundary(child: surface);
  }

  Color _surfaceForDepth(
      BuildContext context, GlassDepth depth, double opacity) {
    return switch (depth) {
      GlassDepth.level1 => GlassColors.level1,
      GlassDepth.level2 => GlassColors.level2,
      GlassDepth.level3 => GlassColors.level3,
    };
  }
}

/// Physical card preset of [GlassSurface]: level-2 glass with a card radius.
/// Card's own margin is disabled to match GlassSurface's margin handling.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? surfaceColor;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.surfaceColor,
  });

  @override
  Widget build(BuildContext context) {
    if (!isGlassTheme(context)) {
      Widget result = Card(
        margin: margin ?? EdgeInsets.zero,
        child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
      );
      if (onTap != null) {
        result = InkWell(onTap: onTap, child: result);
      }
      return result;
    }
    return GlassSurface(
      padding: padding,
      margin: margin,
      depth: GlassDepth.level2,
      borderRadius: 18,
      onTap: onTap,
      child: child,
    );
  }
}

/// Glass-themed button with press feedback. In non-Glass themes it renders a
/// standard [FilledButton] with identical shape/behaviour.
class GlassButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final EdgeInsets? padding;
  final double radius;
  final bool outlined;

  const GlassButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.padding,
    this.radius = 14,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!isGlassTheme(context)) {
      return outlined
          ? OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(padding: padding),
              child: child,
            )
          : FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(padding: padding),
              child: child,
            );
    }

    final style = BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: outlined
          ? null
          : const LinearGradient(
              colors: [GlassColors.accent, GlassColors.accentStrong],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
      color: outlined ? GlassColors.level2 : null,
      border: Border.all(
        color: outlined
            ? GlassColors.borderStrong
            : Colors.transparent,
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: outlined
              ? const Color(0x28000000)
              : GlassColors.accentGlow,
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ],
    );

    return GestureDetector(
      onTap: onPressed,
      child: AnimatedScale(
        scale: 1.0,
        duration: const Duration(milliseconds: 80),
        child: Container(
          padding: padding ?? const EdgeInsets.symmetric(
              horizontal: 20, vertical: 12),
          alignment: Alignment.center,
          decoration: style,
          child: DefaultTextStyle(
            style: TextStyle(
              color: outlined
                  ? GlassColors.textPrimary
                  : GlassColors.onAccent,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Glass-themed icon button. Non-Glass renders a plain [IconButton].
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? iconColor;
  final double size;
  final String? tooltip;

  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.iconColor,
    this.size = 42,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ??
        (isGlassTheme(context)
            ? GlassColors.textSecondary
            : Theme.of(context).iconTheme.color);
    if (!isGlassTheme(context)) {
      return IconButton(
        icon: Icon(icon, color: color),
        onPressed: onPressed,
        tooltip: tooltip,
      );
    }
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: GlassColors.level1,
          borderRadius: BorderRadius.circular(size / 2),
          border: Border.all(color: GlassColors.border, width: 1),
        ),
        child: Icon(icon, color: color, size: size * 0.5),
      ),
    );
  }
}

/// Glass-themed switch row compatible with Material [SwitchListTile]
/// semantics. Non-Glass renders a standard [SwitchListTile].
class GlassSwitch extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData icon;

  const GlassSwitch({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon = Icons.toggle_on_outlined,
  });

  @override
  Widget build(BuildContext context) {
    if (!isGlassTheme(context)) {
      return SwitchListTile.adaptive(
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        value: value,
        onChanged: onChanged,
        secondary: Icon(icon),
      );
    }
    return ListTile(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      leading: Icon(icon, color: GlassColors.textSecondary),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
      tileColor: Colors.transparent,
    );
  }
}

/// Glass-themed input field. Non-Glass renders a standard [TextField] with
/// the same decoration.
class GlassInput extends StatelessWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final String? errorText;
  final String? helperText;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final bool obscureText;
  final int maxLines;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;

  const GlassInput({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.errorText,
    this.helperText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        errorText: errorText,
        helperText: helperText,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        suffixIcon: suffixIcon != null ? Icon(suffixIcon) : null,
      ),
    );
  }
}

/// Glass-themed chip. Non-Glass renders a standard [Chip] / [FilterChip].
class GlassChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  const GlassChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
    );
  }
}

/// Glass-themed dialog helper. Non-Glass uses the standard [showDialog].
Future<T?> showGlassDialog<T>(
  BuildContext context, {
  required String title,
  required Widget content,
  List<Widget> actions = const [],
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: content,
      actions: actions,
    ),
  );
}

/// Glass-themed bottom sheet helper. Non-Glass uses standard showModalBottomSheet.
Future<T?> showGlassBottomSheet<T>(
  BuildContext context, {
  required Widget child,
  bool isScrollControlled = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    builder: (context) {
      if (!isGlassTheme(context)) {
        return child;
      }
      return GlassSurface(
        borderRadius: 24,
        depth: GlassDepth.level3,
        padding: const EdgeInsets.only(bottom: 24),
        child: child,
      );
    },
  );
}