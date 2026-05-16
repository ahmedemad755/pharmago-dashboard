
import 'package:dartz/dartz.dart';
import 'package:fruitesdashboard/core/errors/faliur.dart';
import 'package:image_picker/image_picker.dart';

abstract class ImagRepo {
  Future<Either<Faliur, String>> uploadImage(XFile image);
  Future<Either<Faliur, String>> uploadImageFromUrl(String imageUrl);
}
