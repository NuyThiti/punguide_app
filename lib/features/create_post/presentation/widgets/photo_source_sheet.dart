import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import 'composer_sheet.dart';

/// Camera or library for the topic photo. Returns null when dismissed.
Future<ImageSource?> showPhotoSourceSheet(BuildContext context) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (_) => ComposerSheet(
      title: 'รูปภาพ',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SourceRow(
            icon: Icons.photo_camera,
            label: 'ถ่ายรูป',
            onTap: () => Navigator.of(context).pop(ImageSource.camera),
          ),
          _SourceRow(
            icon: Icons.photo_library_outlined,
            label: 'เลือกจากคลังภาพ',
            onTap: () => Navigator.of(context).pop(ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.postIconWell,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: AppColors.brandOrange),
      ),
      title: Text(
        label,
        style: const TextStyle(
          color: AppColors.foreground,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
