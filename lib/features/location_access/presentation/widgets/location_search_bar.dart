import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// The floating chrome over the map: back, the place field, and the control
/// that switches what the map draws.
///
/// It floats rather than sitting in an app bar because the map runs full
/// bleed behind it — the design keeps the photography edge to edge.
class LocationSearchBar extends StatelessWidget {
  const LocationSearchBar({
    super.key,
    required this.controller,
    required this.onBack,
    required this.onChanged,
    required this.onToggleLayer,
    this.hintText = 'ค้นหาตำแหน่ง',
  });

  final TextEditingController controller;
  final VoidCallback onBack;
  final ValueChanged<String> onChanged;

  /// Switches the map between the plain and the satellite view.
  final VoidCallback onToggleLayer;

  final String hintText;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Floating(
          shape: BoxShape.circle,
          child: InkResponse(
            onTap: onBack,
            radius: 28,
            child: const SizedBox(
              width: 52,
              height: 52,
              child: Icon(Icons.chevron_left, size: 26),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _Floating(
            radius: 28,
            child: SizedBox(
              height: 56,
              child: Row(
                children: [
                  const SizedBox(width: 18),
                  const Icon(
                    Icons.search,
                    size: 20,
                    color: AppColors.postFieldHint,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      onChanged: onChanged,
                      textInputAction: TextInputAction.search,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.foreground,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: hintText,
                        hintStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.postFieldHint,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _LayerButton(onTap: onToggleLayer),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LayerButton extends StatelessWidget {
  const _LayerButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'สลับมุมมองแผนที่',
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: AppColors.locationLayerWell,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.map_outlined,
            size: 20,
            color: AppColors.foreground,
          ),
        ),
      ),
    );
  }
}

/// White, soft-shadowed, and clipped so the ripple stays inside the shape.
class _Floating extends StatelessWidget {
  const _Floating({
    required this.child,
    this.radius = 0,
    this.shape = BoxShape.rectangle,
  });

  final Widget child;
  final double radius;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    final borderRadius =
        shape == BoxShape.circle ? null : BorderRadius.circular(radius);

    return DecoratedBox(
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: AppColors.screen,
        shape: shape == BoxShape.circle ? const CircleBorder() : null,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}
