import 'package:image_picker/image_picker.dart';

Future<String> persistImage(XFile image) async => image.path;
