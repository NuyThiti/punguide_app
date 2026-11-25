import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/router/app_router.dart';
import 'create_post_screen.dart';
import 'providers/photo_library_providers.dart';
import 'widgets/photo_library_picker_screen.dart';
import 'widgets/post_photo_review_screen.dart';

/// The create sheet's "PunGuide" row: photo-first now, rather than a blank
/// composer. Our own picker (header, live preview, grid, "ต่อไป") opens
/// immediately: nothing picked (backed out, or access refused) leaves the
/// traveller exactly where they were. Picking anything moves on to the
/// review screen, whose own choice — AI or by hand — is already known
/// before the composer even opens.
Future<void> startPunGuidePost(BuildContext context, WidgetRef ref) async {
  final files = await showPhotoLibraryPicker(
    context,
    source: ref.read(photoLibrarySourceProvider),
  );
  if (files == null || files.isEmpty || !context.mounted) return;

  final choice = await showPostPhotoReviewScreen(
    context,
    picker: ImagePicker(),
    initialPhotos: files,
  );
  if (choice == null || !context.mounted) return;

  context.goNamed(
    AppRoute.createPost.name,
    extra: choice.useAi
        ? CreatePostRouteArgs(aiImport: choice.selection)
        : CreatePostRouteArgs(manualImport: choice.selection),
  );
}
