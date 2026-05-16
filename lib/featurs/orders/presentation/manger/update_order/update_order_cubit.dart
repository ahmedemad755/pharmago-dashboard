import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fruitesdashboard/core/enums/order_enum.dart';
import 'package:fruitesdashboard/featurs/orders/data/domain/enteties/order_entety.dart';
import 'package:fruitesdashboard/featurs/orders/data/domain/enteties/order_product_entety.dart';
import 'package:fruitesdashboard/featurs/orders/data/domain/repos/order_repo.dart';
import 'package:meta/meta.dart';

part 'update_order_state.dart';

class UpdateOrderCubit extends Cubit<UpdateOrderState> {
  UpdateOrderCubit(this.ordersRepo) : super(UpdateOrderInitial());

  final OrdersRepo ordersRepo;
  final List<OrderProductEntity> _tempProducts = [];
  double _tempTotalPrice = 0.0;

  // 1. إضافة منتج للقائمة المؤقتة وتحديث السعر
  void addProductToOrder(OrderProductEntity product) {
    _tempProducts.add(product);
    _tempTotalPrice += (product.price * product.quantity);

    emit(UpdateOrderProductsChanged(
      tempProducts: List.from(_tempProducts),
      totalPrice: _tempTotalPrice,
      timeStamp: DateTime.now(),
    ));
  }

  // 2. حذف منتج من القائمة المؤقتة
  void removeProductFromOrder(int index) {
    _tempTotalPrice -=
        (_tempProducts[index].price * _tempProducts[index].quantity);
    _tempProducts.removeAt(index);

    emit(UpdateOrderProductsChanged(
      tempProducts: List.from(_tempProducts),
      totalPrice: _tempTotalPrice,
      timeStamp: DateTime.now(),
    ));
  }

  // 3. العملية النهائية: تحديث الأوردر بالمنتجات، السعر، ونقص المخزن (للروشتة)
  Future<void> confirmAndShipPrescription({required String orderID,required String pharmacyId,}) async {
if (_tempProducts.isEmpty) {
      emit(UpdateOrderFailure("برجاء إضافة منتج واحد على الأقل للروشتة"));
      return;
    }

    emit(UpdateOrderLoading());

    try {
      final firestore = FirebaseFirestore.instance;
      
      // 1. جلب اسم الصيدلية الحقيقي من قاعدة البيانات
      String pharmacyName = "صيدلية عامة"; // قيمة افتراضية
      final pharmacyDoc = await firestore.collection('pharmacies').doc(pharmacyId).get(); 
      
      if (pharmacyDoc.exists && pharmacyDoc.data() != null) {
        // تأكد أن الحقل في Firestore اسمه 'name' أو 'pharmacyName'
     pharmacyName = pharmacyDoc.data()?['pharmacyName'] ?? "صيدلية عامة";
      }

      final batch = firestore.batch();
      final orderDocRef = firestore.collection('orders').doc(orderID);

      // تحويل المنتجات لـ JSON (التي تحتوي الآن على imageUrl الصحيحة)
      List<Map<String, dynamic>> productsJson =
          _tempProducts.map((e) => e.toJson()).toList();

      // 2. تحديث بيانات الطلب كاملة
      batch.update(orderDocRef, {
        'orderProducts': productsJson,
        'totalPrice': _tempTotalPrice,
        'status': OrderStatus.shipped.name,
        'confirmedByPhone': true,
        'pharmacyName': pharmacyName, // ✅ تم وضع الاسم الحقيقي هنا
      });

      // نقص المخزن لكل منتج تمت إضافته في الروشتة
      for (var product in _tempProducts) {
        final productQuery = await firestore
            .collection('products')
            .where('code', isEqualTo: product.code)
            .limit(1)
            .get();

        if (productQuery.docs.isNotEmpty) {
          final productDocRef = productQuery.docs.first.reference;
          batch.update(productDocRef, {
            'unitAmount': FieldValue.increment(-product.quantity),
          });
        }
      }

      await batch.commit();
      
      // تنظيف البيانات المؤقتة بعد النجاح
      _tempProducts.clear();
      _tempTotalPrice = 0.0;
      
      emit(UpdateOrderSuccess());
    } catch (e) {
      print("🔥 Error in confirmAndShipPrescription: $e");
      emit(UpdateOrderFailure("فشل في تحديث الطلب: ${e.toString()}"));
    }
  }

  // 4. تحديث حالة الطلب العام (تغيير حالات من Pending لـ Shipped لـ Delivered)
  Future<void> updateOrder({
    required OrderStatus status,
    required String orderID,
    required OrderEntity orderEntity,
  }) async {
    // حماية: منع إعادة تنفيذ العملية لو الحالة هي نفسها
    if (orderEntity.status == status) return;

    emit(UpdateOrderLoading());

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      final orderDocRef = firestore.collection('orders').doc(orderID);

      // تحديث حالة الطلب في الـ Batch
      batch.update(orderDocRef, {'status': status.name});

      // 🎯 منطق نقص المخزن وزيادة المبيعات: يتم فقط عند التحويل لـ "Delivered"
      // وبشرط أن الحالة السابقة لم تكن Delivered منعاً للتكرار
      if (status == OrderStatus.delivered &&
          orderEntity.status != OrderStatus.delivered) {
        for (var product in orderEntity.orderProducts) {
          // البحث عن المنتج بالكود لجلب الـ DocRef الخاص به
          final productQuery = await firestore
              .collection('products')
              .where('code', isEqualTo: product.code)
              .limit(1)
              .get();

          if (productQuery.docs.isNotEmpty) {
            final productDocRef = productQuery.docs.first.reference;

            // دمج كافة عمليات التحديث للمنتج الواحد في خطوة Batch واحدة
            batch.update(productDocRef, {
              'unitAmount': FieldValue.increment(-product.quantity), // نقص الكمية من المخزن
              'stockOut': FieldValue.increment(product.quantity),   // زيادة الكمية الخارجة
              'sellingcount': FieldValue.increment(product.quantity), // زيادة عداد المبيعات
            });
          }
        }
      }

      // تنفيذ كافة العمليات دفعة واحدة لضمان سلامة البيانات (Atomic Operation)
      await batch.commit();

      emit(UpdateOrderSuccess());
    } catch (e) {
      print("🔥 Error in UpdateOrderCubit: $e");
      emit(UpdateOrderFailure("حدث خطأ أثناء التحديث: ${e.toString()}"));
    }
  }
}