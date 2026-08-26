import 'package:flutter/material.dart';

Widget buildCoverImage(String source, BoxFit fit) {
  return Image.network(source, fit: fit);
}
