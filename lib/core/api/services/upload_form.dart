import 'package:dio/dio.dart';

/// Builds the `multipart/form-data` body the upload endpoints expect, with the
/// file under the field name `file`.
///
/// Pass [filePath] on mobile and desktop, or [bytes] with a [filename] on the
/// web, where there is no file system to read from.
Future<FormData> buildUploadForm({
  String? filePath,
  List<int>? bytes,
  String? filename,
  Map<String, String> fields = const <String, String>{},
}) async {
  final MultipartFile file;
  if (bytes != null) {
    file = MultipartFile.fromBytes(bytes, filename: filename ?? 'upload');
  } else if (filePath != null) {
    file = await MultipartFile.fromFile(
      filePath,
      filename: filename ?? _basename(filePath),
    );
  } else {
    throw ArgumentError('Pass either filePath or bytes to upload a file.');
  }
  return FormData.fromMap(<String, dynamic>{...fields, 'file': file});
}

/// The last path segment, handling both separators so this stays free of
/// `dart:io` and keeps working on the web.
String _basename(String path) {
  final segments = path.split(RegExp(r'[/\\]'));
  final last = segments.isEmpty ? '' : segments.last;
  return last.isEmpty ? 'upload' : last;
}
