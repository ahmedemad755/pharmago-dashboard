import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

abstract class StorgeService {
  Future<String?> uploadImage(XFile file, String path);

  Future<String?> uploadImageBytes(Uint8List bytes, String path);

  Future<void> deleteFile(String path);
}
