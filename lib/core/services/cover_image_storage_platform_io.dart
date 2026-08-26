import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

Future<String> persistImage(XFile image) async {
  final directory = await getApplicationDocumentsDirectory();
  final extensionIndex = image.name.lastIndexOf('.');
  final extension =
      extensionIndex < 0 ? '.jpg' : image.name.substring(extensionIndex);
  final path =
      '${directory.path}/trip-cover-${DateTime.now().microsecondsSinceEpoch}$extension';
  return (await File(image.path).copy(path)).path;
}
