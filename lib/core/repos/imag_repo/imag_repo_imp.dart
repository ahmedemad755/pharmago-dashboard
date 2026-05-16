import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:fruitesdashboard/core/errors/faliur.dart';
import 'package:fruitesdashboard/core/repos/imag_repo/imag_repo.dart';
import 'package:fruitesdashboard/core/services/storge_service.dart';
import 'package:fruitesdashboard/core/utils/backend_points.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

class ImagRepoImp implements ImagRepo {
  final StorgeService storgeService;
  ImagRepoImp(this.storgeService);
  @override
  Future<Either<Faliur, String>> uploadImage(XFile image) async {
    try {
      return await storgeService.uploadImage(image, BackendPoints.urlImag).then((
        value,
      ) {
        if (value == null) {
          return left(
            ServerFaliur(
              'server error image is null or failed to upload so its uploaded already',
            ),
          );
        }
        return right(value);
      });
    } catch (e) {
      return left(ServerFaliur('server error to upload image'));
    }
  }
  
@override
Future<Either<Faliur, String>> uploadImageFromUrl(String imageUrl) async {
  try {
    // 1. تحميل الصورة من الرابط الخارجي
    final response = await http.get(Uri.parse(imageUrl));

    if (response.statusCode == 200) {
      final Uint8List bytes = response.bodyBytes;
      
      // 2. استخراج اسم الملف من الرابط أو إنشاء اسم فريد
      // بنستخدم الـ barcode أو timestamp عشان الاسم ميتكررش
      String fileName = p.basename(Uri.parse(imageUrl).path);
      if (fileName.isEmpty) {
        fileName = 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      }

      // 3. الرفع باستخدام storgeService
      // ملحوظة: لو storgeService محتاجة XFile، هنستخدم uploadImageBytes لو متوفرة
      // أو نعدل storgeService تقبل Uint8List وده الأفضل للروابط
      final String? downloadedUrl = await storgeService.uploadImageBytes(
        bytes,
        '${BackendPoints.urlImag}/$fileName',
      );

      if (downloadedUrl != null) {
        return right(downloadedUrl);
      } else {
        return left(ServerFaliur('Failed to upload image bytes to Supabase'));
      }
    } else {
      return left(ServerFaliur('Failed to download image from original URL'));
    }
  } catch (e) {
    return left(ServerFaliur('Error during URL image siphoning: ${e.toString()}'));
  }
}
}
