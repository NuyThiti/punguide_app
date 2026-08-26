import 'package:image_picker/image_picker.dart';

import 'cover_image_storage_platform.dart'
    if (dart.library.io) 'cover_image_storage_platform_io.dart';

Future<String> persistCoverImage(XFile image) => persistImage(image);
