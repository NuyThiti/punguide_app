import 'package:flutter/material.dart';

import 'cover_image_platform.dart'
    if (dart.library.io) 'cover_image_platform_io.dart';

/// Renders a cover from a bundled asset path, a remote URL, or a local file.
class CoverImage extends StatelessWidget {
  const CoverImage({
    super.key,
    required this.source,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.width,
    this.height,
  });

  final String source;
  final BoxFit fit;
  final Alignment alignment;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: buildCoverImage(source, fit, alignment),
    );
  }
}
