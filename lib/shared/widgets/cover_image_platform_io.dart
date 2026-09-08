import 'dart:io';

import 'package:flutter/material.dart';

Widget buildCoverImage(String source, BoxFit fit, Alignment alignment) {
  if (source.startsWith('assets/')) {
    return Image.asset(
      source,
      fit: fit,
      alignment: alignment,
      errorBuilder: coverImageFallback,
    );
  }

  final uri = Uri.tryParse(source);
  final isRemote = uri != null &&
      (uri.scheme == 'http' ||
          uri.scheme == 'https' ||
          uri.scheme == 'data' ||
          uri.scheme == 'blob');

  return isRemote
      ? Image.network(
          source,
          fit: fit,
          alignment: alignment,
          errorBuilder: coverImageFallback,
        )
      : Image.file(
          File(source),
          fit: fit,
          alignment: alignment,
          errorBuilder: coverImageFallback,
        );
}

/// Keeps a missing cover from painting Flutter's red error box over a card.
Widget coverImageFallback(BuildContext context, Object error, StackTrace? _) {
  return const ColoredBox(
    color: Color(0xFFEDEAE6),
    child: Center(
      child: Icon(Icons.photo_outlined, color: Color(0xFFB4ADA6), size: 22),
    ),
  );
}
