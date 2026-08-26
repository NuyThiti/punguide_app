import 'dart:io';

import 'package:flutter/material.dart';

Widget buildCoverImage(String source, BoxFit fit) {
  final uri = Uri.tryParse(source);
  final isRemote = uri != null &&
      (uri.scheme == 'http' ||
          uri.scheme == 'https' ||
          uri.scheme == 'data' ||
          uri.scheme == 'blob');

  return isRemote
      ? Image.network(source, fit: fit)
      : Image.file(File(source), fit: fit);
}
