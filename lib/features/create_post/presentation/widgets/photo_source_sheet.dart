import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import 'composer_sheet.dart';

/// Camera or library for the topic photo. Returns null when dismissed.
Future<ImageSource?> showPhotoSourceSheet(BuildContext context) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (sheetContext) => ComposerSheet(
      title: 'เพิ่มรูป',
      onClose: () => Navigator.of(sheetContext).pop(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SourceRow(
            iconAsset: 'assets/icons/add_camera.svg',
            label: 'ถ่ายรูป',
            onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
          ),
          const SizedBox(height: 16),
          // The one Figma highlights with its own light wash — the most used
          // of the three ways in.
          _SourceRow(
            iconAsset: 'assets/icons/add_photo_alternate.svg',
            label: 'เลือกจากคลังภาพ',
            highlighted: true,
            onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.iconAsset,
    required this.label,
    required this.onTap,
    this.highlighted = false,
  });

  final String iconAsset;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlighted ? AppColors.postSourceSelectedRow : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.postSourceIconWell,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: SvgPicture.asset(iconAsset, width: 24, height: 24),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.foreground,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
