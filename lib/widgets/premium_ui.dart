import 'dart:ui';
import 'package:flutter/material.dart';

/// Shared premium UI helpers.
/// These widgets are visual-only and do not own any app/business logic.
class PremiumScaffoldBackground extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const PremiumScaffoldBackground({
    super.key,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE9FFF8),
            Color(0xFFF6F0FF),
            Color(0xFFFFF7ED),
          ],
        ),
      ),
      child: Stack(
        children: [
          const _AmbientBlob(
            top: -90,
            left: -70,
            size: 220,
            color: Color(0xFF1BAE9A),
            opacity: 0.18,
          ),
          const _AmbientBlob(
            top: 90,
            right: -80,
            size: 210,
            color: Color(0xFFFF8EB8),
            opacity: 0.14,
          ),
          const _AmbientBlob(
            bottom: -110,
            left: 40,
            size: 260,
            color: Color(0xFF8FD8FF),
            opacity: 0.16,
          ),
          Padding(
            padding: padding ?? EdgeInsets.zero,
            child: child,
          ),
        ],
      ),
    );
  }
}

class _AmbientBlob extends StatelessWidget {
  final double? top;
  final double? left;
  final double? right;
  final double? bottom;
  final double size;
  final Color color;
  final double opacity;

  const _AmbientBlob({
    this.top,
    this.left,
    this.right,
    this.bottom,
    required this.size,
    required this.color,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: IgnorePointer(
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(opacity),
            ),
          ),
        ),
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color tint;
  final double blur;
  final Border? border;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final List<BoxShadow>? boxShadow;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
    this.tint = Colors.white,
    this.blur = 16,
    this.border,
    this.onTap,
    this.onLongPress,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final content = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: tint.withOpacity(0.68),
            borderRadius: BorderRadius.circular(radius),
            border: border ?? Border.all(color: Colors.white.withOpacity(0.58)),
            boxShadow: boxShadow ??
                [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 26,
                    offset: const Offset(0, 14),
                  ),
                ],
          ),
          padding: padding,
          child: child,
        ),
      ),
    );

    if (onTap == null && onLongPress == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        onLongPress: onLongPress,
        child: content,
      ),
    );
  }
}

class GradientIconBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;
  final double radius;

  const GradientIconBox({
    super.key,
    required this.icon,
    required this.color,
    this.size = 56,
    this.iconSize = 28,
    this.radius = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.94),
            color.withOpacity(0.68),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: iconSize),
    );
  }
}

class PremiumSectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color color;

  const PremiumSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.color = const Color(0xFF00796B),
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF12312D),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF12312D).withOpacity(0.58),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class PremiumPill extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color color;
  final Color? backgroundColor;

  const PremiumPill({
    super.key,
    this.icon,
    required this.label,
    required this.color,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.maybeOf(context)?.size.width ?? 360;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth - 48),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: backgroundColor ?? color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(0.14)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
