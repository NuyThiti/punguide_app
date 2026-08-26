import 'package:flutter/material.dart';

import 'cover_image_platform.dart'
    if (dart.library.io) 'cover_image_platform_io.dart';

class CoverImage extends StatelessWidget {
  const CoverImage({
    super.key,
    required this.source,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  final String source;
  final BoxFit fit;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: buildCoverImage(source, fit),
    );
  }
}
