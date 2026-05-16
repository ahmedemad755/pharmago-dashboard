import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fruitesdashboard/core/utils/app_colors.dart';
import 'package:fruitesdashboard/core/utils/backend_points.dart';
import 'package:fruitesdashboard/featurs/dashboard/presentation/widgets/editProductView.dart';

class ProductsCategoryView extends StatelessWidget {
  const ProductsCategoryView({super.key});

  @override
  Widget build(BuildContext context) {
    final String currentPharmacyId =
        FirebaseAuth.instance.currentUser?.uid ?? "";

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primaryColor,
        title: const Text(
          "  المنتجات المتاحه ف الصيدليه ",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
      ),
      body:// استبدل StreamBuilder القديم بده:

StreamBuilder<QuerySnapshot>(
  key: ValueKey(currentPharmacyId),
  stream: FirebaseFirestore.instance
      .collection(BackendPoints.getProducts)
      .where('pharmacyId', isEqualTo: currentPharmacyId)
      .snapshots(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryColor));
    }
    // الحل هنا: نستخدم البيانات اللي جاية من الـ snapshot مباشرة
    // لو مفيش تغيير ظاهر، ده معناه إن الـ Stream بيعمل Cache
    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
      return _buildEmptyState();
    }

    // هنا الـ snapshot.data!.docs هي اللي فيها التحديثات
    // كل وثيقة (doc) جواها الداتا الجديدة
    var docs = snapshot.data!.docs;

    Map<String, List<QueryDocumentSnapshot>> groupedProducts = {};
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      String category = data['category'] ?? "منتجات عامة";
      groupedProducts.putIfAbsent(category, () => []).add(doc);
    }

    return ListView.builder(
      // ... باقي الكود كما هو
            padding: const EdgeInsets.all(16),
            itemCount: groupedProducts.keys.length,
            itemBuilder: (context, index) {
              String category = groupedProducts.keys.elementAt(index);
              List<QueryDocumentSnapshot> products = groupedProducts[category]!;

              return Container(
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ExpansionTile(
                  shape: const RoundedRectangleBorder(side: BorderSide.none),
                  collapsedShape: const RoundedRectangleBorder(
                    side: BorderSide.none,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primaryColor.withOpacity(0.1),
                    child: const Icon(
                      Icons.inventory_2,
                      color: AppColors.primaryColor,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    category,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    "${products.length} منتجات مسجلة",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  children: products
                      .map((product) => _buildProductItem(context, product))
                      .toList(),
                ),
              );
            },
          );
        },
      ),
    );
  }

Widget _buildProductItem(BuildContext context, QueryDocumentSnapshot doc) {
  final data = doc.data() as Map<String, dynamic>;
  bool hasDiscount = data['hasDiscount'] ?? false;

  // 1. جلب تاريخ الانتهاء والتحقق من الحالة
  DateTime? expiryDate;
  if (data['expirationDate'] != null) {
    if (data['expirationDate'] is Timestamp) {
      expiryDate = (data['expirationDate'] as Timestamp).toDate();
    }
  }

  // منطق التحقق من الانتهاء
  final bool isExpired = expiryDate != null && expiryDate.isBefore(DateTime.now());

  // 2. منطق الكمية والمخزون
  final dynamic rawAmount = data['unitAmount'];
  int amount = 0;
  if (rawAmount != null) {
    amount = (rawAmount is num) ? rawAmount.toInt() : int.tryParse(rawAmount.toString()) ?? 0;
  }
  if (amount < 0) amount = 0;

  Color stockColor;
  String stockStatus;

  // الأولوية للون الأحمر لو منتهي الصلاحية بغض النظر عن الكمية
  if (isExpired) {
    stockColor = Colors.red;
    stockStatus = "منتهي الصلاحية ⚠️";
  } else if (amount <= 5) {
    stockColor = Colors.red;
    stockStatus = "مخزون منخفض جداً";
  } else if (amount <= 10) {
    stockColor = Colors.orange;
    stockStatus = "بدأ ينفد";
  } else {
    stockColor = Colors.green;
    stockStatus = "متوفر";
  }

  return Column(
    key: ValueKey("${doc.id}_${amount}_$isExpired"),
    children: [
      const Divider(height: 1, indent: 70),
      Container(
        // إضافة خلفية خفيفة جداً لو المنتج منتهي
        color: isExpired ? Colors.red.withOpacity(0.03) : null,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          leading: Stack(
            children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  image: DecorationImage(
                    image: NetworkImage(data['imageurl'] ?? ""),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              // نقطة الحالة الملونة
              Positioned(
                right: 0, top: 0,
                child: Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                    color: stockColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          title: Text(
            data['name'] ?? "",
            style: TextStyle(
              fontWeight: FontWeight.w600,
              // شطب الاسم لو منتهي الصلاحية (اختياري)
              decoration: isExpired ? TextDecoration.lineThrough : null,
              color: isExpired ? Colors.red.shade900 : Colors.black,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    "${data['price']} جنيه مصري",
                    style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "($stockStatus: $amount)",
                      style: TextStyle(
                        color: stockColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              // عرض تاريخ الانتهاء تحت السعر
              if (expiryDate != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    "تنتهي في: ${expiryDate.year}-${expiryDate.month.toString().padLeft(2, '0')}-${expiryDate.day.toString().padLeft(2, '0')}",
                    style: TextStyle(
                      color: isExpired ? Colors.red : Colors.grey,
                      fontSize: 10,
                      fontWeight: isExpired ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              if (hasDiscount && !isExpired)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    "خصم فعال: ${data['discountPercentage']}%",
                    style: const TextStyle(color: Colors.orange, fontSize: 11),
                  ),
                ),
            ],
          ),
trailing: Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    // زر الخصم
    IconButton(
      icon: Icon(
        hasDiscount ? Icons.local_offer : Icons.local_offer_outlined,
        // تغيير اللون لرمادي باهت لو منتهي
        color: isExpired 
            ? Colors.grey.shade300 
            : (hasDiscount ? Colors.orange : Colors.grey.shade400),
      ),
      // تعطيل الضغط (onPressed = null)
      onPressed: isExpired ? null : () => _showDiscountDialog(
        context,
        doc.reference,
        hasDiscount,
        data['discountPercentage'],
      ),
    ),
    
    // زر التعديل
    IconButton(
      icon: Icon(
        Icons.edit_note_rounded,
        // تغيير اللون لرمادي لو منتهي
        color: isExpired ? Colors.grey.shade300 : Colors.blueAccent,
      ),
      // تعطيل الانتقال لصفحة التعديل
      onPressed: isExpired ? null : () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EditProductView(productId: doc.id, initialData: data),
        ),
      ),
    ),
  ],
),
        ),
      ),
    ],
  );
}

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.layers_clear_outlined,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          const Text(
            "لا توجد منتجات مضافة حالياً",
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  void _showDiscountDialog(
    BuildContext context,
    DocumentReference ref,
    bool hasDiscount,
    dynamic current,
  ) {
    final controller = TextEditingController(
      text: hasDiscount ? current.toString() : "",
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("إعداد خصم للمنتج"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: "نسبة الخصم %",
            hintText: "مثلاً: 15",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.update({'hasDiscount': false, 'discountPercentage': 0});
              Navigator.pop(context);
            },
            child: const Text("حذف الخصم", style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              int? val = int.tryParse(controller.text);
              if (val != null && val <= 100) {
                ref.update({'hasDiscount': true, 'discountPercentage': val});
                Navigator.pop(context);
              }
            },
            child: const Text("حفظ"),
          ),
        ],
      ),
    );
  }
}