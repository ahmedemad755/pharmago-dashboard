
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:fruitesdashboard/core/services/storge_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as b;
import 'package:path/path.dart' as p;

class FireStorge implements StorgeService {
  final storgerefrance = FirebaseStorage.instance.ref();

  @override
  Future<String?> uploadImage(XFile file, String path) async {
    // إضافة uniqueId لاسم الملف لمنع التكرار
    String uniqueId = DateTime.now().millisecondsSinceEpoch.toString();
    String fileName = b.basename(file.path);
    String filePath = '$path/${uniqueId}_$fileName';

    var imagereference = storgerefrance.child(filePath);
    final bytes = await file.readAsBytes();
return await imagereference.putData(bytes).then((value) async {
      var downloadimageUrl = await value.ref.getDownloadURL();
      return downloadimageUrl;
    });

  }

  

  @override
  Future<void> deleteFile(String path) async {
    await storgerefrance.child(path).delete();
  }
  
@override
Future<String?> uploadImageBytes(Uint8List bytes, String path) async {
  final uniqueId = DateTime.now().millisecondsSinceEpoch.toString();
  final folder = p.dirname(path).replaceAll(r'\', '/');
  final fileName = p.basename(path).isEmpty ? 'image.jpg' : p.basename(path);
  final filePath =
      folder == '.' ? '${uniqueId}_$fileName' : '$folder/${uniqueId}_$fileName';

  final imagereference = storgerefrance.child(filePath);
  final value = await imagereference.putData(bytes);

  return value.ref.getDownloadURL();
}



}
