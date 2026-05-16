// ignore: depend_on_referenced_packages
import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:fruitesdashboard/core/repos/imag_repo/imag_repo.dart';
import 'package:fruitesdashboard/core/repos/product_repo/product_repo.dart';
import 'package:fruitesdashboard/core/services/account_status_service.dart';
import 'package:fruitesdashboard/featurs/add_product/domain/entities/add_product_intety.dart';
import 'package:fruitesdashboard/featurs/data/models/add_product_input_model.dart';
import 'package:fruitesdashboard/featurs/inventory/domain/repos/inventory_repo.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart' as path_provider;

part 'add_product_state.dart';

class AddProductCubit extends Cubit<AddProductState> {
  AddProductCubit(this.imagRepo, this.productRepo, this._inventoryRepo)
      : super(AddProductInitial());

  final ImagRepo imagRepo;
  final ProductRepo productRepo;
  // Kept because this cubit is registered with it and other code may still rely
  // on the constructor shape.
  // ignore: unused_field
  final InventoryRepo _inventoryRepo;
  final AccountStatusService _accountStatusService = AccountStatusService();

  Future<XFile?> _compressImage(XFile file) async {
    if (kIsWeb) return file;

    try {
      final tempDir = await path_provider.getTemporaryDirectory();
      final targetPath = path.join(
        tempDir.path,
        "${DateTime.now().millisecondsSinceEpoch}.jpg",
      );

      final result = await FlutterImageCompress.compressAndGetFile(
        file.path,
        targetPath,
        quality: 70,
        minWidth: 1024,
        minHeight: 1024,
        format: CompressFormat.jpeg,
      );

      return result != null ? XFile(result.path) : null;
    } catch (e) {
      print("Compression Error: $e");
      return null;
    }
  }

  Future<void> addProduct(
    AddProductIntety addProductIntety, {
    String? documentId,
  }) async {
    emit(AddProductLoading());
    final pharmacyId = addProductIntety.pharmacyId;

    Future<bool> canContinueWriting() async {
      if (pharmacyId == null || pharmacyId.trim().isEmpty) {
        emit(AddProductError(error: 'تعذر تحديد الصيدلية الحالية'));
        return false;
      }

      try {
        await _accountStatusService.ensureAccountCanWrite(pharmacyId);
        return true;
      } on AccountDisabledException catch (e) {
        emit(AddProductAccountDisabled(message: e.message));
        return false;
      }
    }

    if (!await canContinueWriting()) return;

    Future<void> saveProductWithImageUrl(String imageUrl) async {
      addProductIntety.imageurl = imageUrl;

      try {
        if (!await canContinueWriting()) return;

        final firestore = FirebaseFirestore.instance;
        final String finalDocId =
            documentId ?? "${addProductIntety.code}_$pharmacyId";

        final batch = firestore.batch();
        final productRef = firestore.collection('products').doc(finalDocId);
        final pharmacyProductRef = firestore
            .collection('pharmacies')
            .doc(pharmacyId)
            .collection('products')
            .doc(addProductIntety.code);
        final inventoryRef = firestore.collection('inventory').doc(finalDocId);

        final productJson =
            AddProductInputModel.fromentity(addProductIntety).toJson();
        productJson['pharmacyId'] = pharmacyId;
        productJson['pharmacyName'] = addProductIntety.pharmacyName;
        productJson['pharmacyLat'] = addProductIntety.pharmacyLat;
        productJson['pharmacyLng'] = addProductIntety.pharmacyLng;
        productJson['isPrescriptionRequired'] =
            addProductIntety.isPrescriptionRequired;
        productJson['imageurl'] = imageUrl;
        productJson['global_image_url'] = imageUrl;

        batch.set(productRef, productJson, SetOptions(merge: true));
        batch.set(pharmacyProductRef, productJson, SetOptions(merge: true));

        batch.set(inventoryRef, {
          'productId': finalDocId,
          'productName': addProductIntety.name,
          'quantity': FieldValue.increment(addProductIntety.unitAmount),
          'pharmacyId': pharmacyId,
          'category': addProductIntety.category,
          'expiryDate': Timestamp.fromDate(addProductIntety.expirationDate),
          'costPrice': addProductIntety.cost,
          'sellingPrice': addProductIntety.price,
          'productImageUrl': imageUrl,
          'code': addProductIntety.code,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await batch.commit();
        emit(AddProductSuccess());
      } catch (e) {
        emit(AddProductError(error: "خطأ في مزامنة المخزن: ${e.toString()}"));
      }
    }

    final existingImageUrl = addProductIntety.imageurl?.trim();
    if (existingImageUrl != null && existingImageUrl.isNotEmpty) {
      await saveProductWithImageUrl(existingImageUrl);
      return;
    }

    if (addProductIntety.image == null) {
      emit(AddProductError(
        error: "يرجى اختيار صورة للمنتج أو استخدام منتج من المكتبة العالمية",
      ));
      return;
    }

    XFile imageToUpload = addProductIntety.image!;
    emit(AddProductError(error: "جاري ضغط الصورة..."));

    final compressedXFile = await _compressImage(addProductIntety.image!);
    if (compressedXFile != null) {
      imageToUpload = compressedXFile;
    }

    final uploadResult = await imagRepo.uploadImage(imageToUpload);
    await uploadResult.fold(
      (failure) async => emit(AddProductError(error: failure.message)),
      (imageUrl) async => saveProductWithImageUrl(imageUrl),
    );
  }
}
