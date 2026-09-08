import 'package:flutter/material.dart';

Widget buildCoverImage(String source, BoxFit fit, Alignment alignment) {
  final builder = (BuildContext context, Object error, StackTrace? _) =>
      const ColoredBox(
        color: Color(0xFFEDEAE6),
        child: Center(
          child: Icon(Icons.photo_outlined, color: Color(0xFFB4ADA6), size: 22),
        ),
      );

  return source.startsWith('assets/')
      ? Image.asset(source, fit: fit, alignment: alignment, errorBuilder: builder)
      : Image.network(source, fit: fit, alignment: alignment, errorBuilder: builder);
}
