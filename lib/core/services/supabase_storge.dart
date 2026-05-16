import 'dart:io';
import 'dart:typed_data';

import 'package:fruitesdashboard/core/const/const.dart';
import 'package:fruitesdashboard/core/services/storge_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as b;
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseStorgeService implements StorgeService {
  static Future<void> initSupabase() async {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }

  Future<void> ensureBucketExists(String bucketName) async {
    final client = Supabase.instance.client;

    try {
      // هات كل البوكيتات
      final buckets = await client.storage.listBuckets();

      // شوف إذا البوكيت موجود
      final exists = buckets.any((bucket) => bucket.name == bucketName);

      if (!exists) {
        await client.storage.createBucket(
          bucketName,
          const BucketOptions(public: true),
        );
        print('Bucket $bucketName created successfully');
      } else {
        final bucket = buckets.firstWhere((bucket) => bucket.name == bucketName);
        if (!bucket.public) {
          await client.storage.updateBucket(
            bucketName,
            const BucketOptions(public: true),
          );
          print('Bucket $bucketName updated to public');
          return;
        }
        print('Bucket $bucketName already exists, skipping creation');
      }
    } catch (e) {
      print('❌ Error checking/creating bucket: $e');
    }
  }

  @override
  Future<String?> uploadImage(XFile file, String path) async {
    try {
      // تعديل هنا: إضافة الوقت الحالي لاسم الملف لجعله فريداً
      final String uniqueId = DateTime.now().millisecondsSinceEpoch.toString();
      final fileName = b.basename(file.path);
      final filePath =
          '$path/${uniqueId}_$fileName'; // دمج المعرف الفريد مع الاسم
final bytes = await file.readAsBytes();
await Supabase.instance.client.storage
          .from(supabaseBucketName)
          .uploadBinary(filePath, bytes, 
              fileOptions: const FileOptions(cacheControl: '3600', upsert: false));
      final publicUrl = Supabase.instance.client.storage
          .from(supabaseBucketName)
          .getPublicUrl(filePath);

      return publicUrl;
    } on StorageException catch (e) {
      print('Storage Error: ${e.message}');
      return null;
    } catch (e) {
      print('Unexpected Error: $e');
      return null;
    }
  }

  @override
  Future<void> deleteFile(String path) async {
    try {
      await Supabase.instance.client.storage.from(supabaseBucketName).remove([
        path,
      ]);
    } catch (e) {
      print('❌ Error deleting file from Supabase: $e');
    }
  }

@override
Future<String?> uploadImageBytes(Uint8List bytes, String path) async {
  try {
    final uniqueId = DateTime.now().millisecondsSinceEpoch.toString();
    final folder = p.dirname(path).replaceAll(r'\', '/');
    final fileName = p.basename(path).isEmpty ? 'image.jpg' : p.basename(path);
    final filePath = folder == '.'
        ? '${uniqueId}_$fileName'
        : '$folder/${uniqueId}_$fileName';

    await Supabase.instance.client.storage
        .from(supabaseBucketName)
        .uploadBinary(
          filePath,
          bytes,
          fileOptions: const FileOptions(
            cacheControl: '3600',
            upsert: false,
          ),
        );

    return Supabase.instance.client.storage
        .from(supabaseBucketName)
        .getPublicUrl(filePath);
  } on StorageException catch (e) {
    print('Storage Error: ${e.message}');
    return null;
  } catch (e) {
    print('Unexpected Error: $e');
    return null;
  }
}

}

