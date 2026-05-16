// lib/featurs/inventory/presentation/views/inventory_view.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fruitesdashboard/core/utils/app_colors.dart';
import 'package:fruitesdashboard/featurs/inventory/domain/entities/inventory_entity.dart';
import 'package:fruitesdashboard/featurs/inventory/presentation/cubit/inventory_cubit.dart';
import 'package:fruitesdashboard/featurs/inventory/presentation/cubit/inventory_state.dart';
import 'package:intl/intl.dart';

class InventoryView extends StatelessWidget {
  const InventoryView({super.key});

  @override
  Widget build(BuildContext context) {
        final String currentPharmacyId =
        FirebaseAuth.instance.currentUser?.uid ?? "";
        context.read<InventoryCubit>().getInventory(currentPharmacyId);
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: _buildAppBar(),
      body: BlocBuilder<InventoryCubit, InventoryState>(
        builder: (context, state) {
          if (state is InventoryLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is InventoryLoaded) {
            return _InventoryBody(inventory: state.inventoryList);
          }
          if (state is InventoryError) {
            return Center(child: Text(state.message));
          }
          return const Center(child: Text("لا توجد بيانات"));
        },
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: AppColors.primaryColor,
      title: const Text(
        "نظام الإدارة الذكية للمخزون",
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontSize: 18,
        ),
      ),
      centerTitle: true,
    );
  }
}

class _InventoryBody extends StatelessWidget {
  final List<InventoryEntity> inventory;
  const _InventoryBody({required this.inventory});

  @override
  Widget build(BuildContext context) {
    // 1. فلترة الكميات الصفرية للتأكد من نظافة الواجهة
    final activeItems = inventory.where((item) => item.quantity > 0).toList();

    if (activeItems.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text("المخزن فارغ حالياً", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    // 2. حساب الإحصائيات بدقة
    final totalAvailable = activeItems
        .where(
          (i) => i.expiryDate == null || i.expiryDate!.isAfter(DateTime.now()),
        )
        .fold(0, (sum, i) => sum + i.quantity);

    final totalExpired = activeItems
        .where(
          (i) => i.expiryDate != null && i.expiryDate!.isBefore(DateTime.now()),
        )
        .fold(0, (sum, i) => sum + i.quantity);

    final lowStockCount = activeItems.where((i) => i.quantity < 10).length;
    final totalItemsCount = activeItems.length;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: _InventoryDashboard(
            available: totalAvailable,
            expired: totalExpired,
            lowStock: lowStockCount,
            totalItems: totalItemsCount,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final categories = activeItems
                  .map((e) => e.category)
                  .toSet()
                  .toList();
              final category = categories[index];
              final categoryItems = activeItems
                  .where((e) => e.category == category)
                  .toList();
              return _CategoryCard(
                categoryName: category,
                items: categoryItems,
              );
            }, childCount: activeItems.map((e) => e.category).toSet().length),
          ),
        ),
      ],
    );
  }
}

class _InventoryDashboard extends StatelessWidget {
  final int available, expired, lowStock, totalItems;
  const _InventoryDashboard({
    required this.available,
    required this.expired,
    required this.lowStock,
    required this.totalItems,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              _StatCard(
                label: "المتاح للبيع",
                value: "$available",
                icon: Icons.check_circle,
                color: Colors.green,
              ),
              const SizedBox(width: 12),
              _StatCard(
                label: "إجمالي المنتجات",
                value: "$totalItems",
                icon: Icons.inventory_2,
                color: Colors.blue,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatCard(
                label: "نواقص (أصناف)",
                value: "$lowStock",
                icon: Icons.trending_down,
                color: Colors.orange,
              ),
              const SizedBox(width: 12),
              _StatCard(
                label: "منتهي الصلاحية",
                value: "$expired",
                icon: Icons.dangerous,
                color: Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String categoryName;
  final List<InventoryEntity> items;
  const _CategoryCard({required this.categoryName, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ExpansionTile(
        leading: const Icon(Icons.folder_open, color: AppColors.primaryColor),
        title: Text(
          categoryName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        children: _buildProductGroups(items),
      ),
    );
  }

List<Widget> _buildProductGroups(List<InventoryEntity> items) {
  final Map<String, List<InventoryEntity>> products = {};
  for (var i in items) {
    products.putIfAbsent(i.productName, () => []).add(i);
  }

  return products.entries.map((entry) {
    final hasExpired = entry.value.any(
      (i) => i.expiryDate != null && i.expiryDate!.isBefore(DateTime.now()),
    );
    
    final totalQty = entry.value.fold(0, (sum, i) => sum + i.quantity);
    // الحصول على رابط الصورة من أول باتش (Batch) للمنتج
    final imageUrl = entry.value.first.productImageUrl;

    return Container(
      decoration: BoxDecoration(
        border: hasExpired
            ? const Border(right: BorderSide(color: Colors.red, width: 5))
            : null,
      ),
      child: ExpansionTile(
        // ✅ التعديل هنا: عرض صورة المنتج بدلاً من الأيقونة الثابتة
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.blueGrey.withOpacity(0.1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: (imageUrl != null && imageUrl.isNotEmpty)
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => 
                        const Icon(Icons.medication, color: Colors.blueGrey),
                  )
                : const Icon(Icons.medication, color: Colors.blueGrey),
          ),
        ),
        title: Text(
          entry.key,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        subtitle: Row(
          children: [
            Text("إجمالي الرصيد: $totalQty", style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 8),
            if (hasExpired)
              const Text("⚠️ تالف", style: TextStyle(color: Colors.red, fontSize: 11)),
          ],
        ),
        children: entry.value.map((batch) => _BatchItemRow(item: batch)).toList(),
      ),
    );
  }).toList();
}
}

class _BatchItemRow extends StatelessWidget {
  final InventoryEntity item;
  const _BatchItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final bool isExpired =
        item.expiryDate != null && item.expiryDate!.isBefore(DateTime.now());

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isExpired
            ? Colors.red.withOpacity(0.05)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "انتهاء: ${item.expiryDate != null ? DateFormat('yyyy-MM-dd').format(item.expiryDate!) : 'غير محدد'}",
                  style: TextStyle(
                    color: isExpired ? Colors.red : Colors.black87,
                    fontSize: 12,
                    fontWeight: isExpired ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                Text(
                  "الكمية: ${item.quantity}",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          _ActionButton(
            icon: Icons.local_shipping,
            color: Colors.green,
            onTap: isExpired ? null : () => _showQtyDialog(context, item, true),
            isDisabled: isExpired,
          ),
          const SizedBox(width: 8),
          _ActionButton(
            icon: isExpired ? Icons.auto_delete : Icons.delete_sweep,
            color: Colors.red,
            onTap: () => _showQtyDialog(context, item, false),
          ),
        ],
      ),
    );
  }

  void _showQtyDialog(
    BuildContext context,
    InventoryEntity item,
    bool isSupply,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => _QuantityDialog(
        item: item,
        isSupply: isSupply,
        cubitContext: context,
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool isDisabled;
  const _ActionButton({
    required this.icon,
    required this.color,
    this.onTap,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (isDisabled ? Colors.grey : color).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: isDisabled ? Colors.grey : color, size: 18),
      ),
    );
  }
}

class _QuantityDialog extends StatefulWidget {
  final InventoryEntity item;
  final bool isSupply;
  final BuildContext cubitContext;

  const _QuantityDialog({
    required this.item,
    required this.isSupply,
    required this.cubitContext,
  });

  @override
  State<_QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<_QuantityDialog> {
  late final TextEditingController controller;
  final formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // نبدأ بـ 1 ككمية افتراضية بدلاً من الفراغ
    controller = TextEditingController(text: "1");
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _adjustQuantity(int delta) {
    final current = int.tryParse(controller.text) ?? 0;
    final newValue = current + delta;
    if (newValue >= 1 && newValue <= widget.item.quantity) {
      setState(() {
        controller.text = newValue.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.isSupply ? Colors.green : Colors.red;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: EdgeInsets.zero,
      title: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: themeColor.withOpacity(0.1),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Row(
          children: [
            Icon(
              widget.isSupply ? Icons.local_shipping : Icons.delete_sweep,
              color: themeColor,
            ),
            const SizedBox(width: 12),
            Text(
              widget.isSupply ? "نقل للمتجر" : "تسجيل توالف",
              style: TextStyle(
                color: themeColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "المنتج: ${widget.item.productName}",
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blueGrey.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "الرصيد المتاح حالياً: ${widget.item.quantity}",
              style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
            ),
          ),
          const SizedBox(height: 20),
          Form(
            key: formKey,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _circularIconButton(Icons.remove, () => _adjustQuantity(-1)),
                const SizedBox(width: 15),
                SizedBox(
                  width: 80,
                  child: TextFormField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: themeColor, width: 2),
                      ),
                    ),
                    validator: (v) {
                      final val = int.tryParse(v ?? "") ?? 0;
                      if (val <= 0) return "خطأ";
                      if (val > widget.item.quantity) return "تجاوز";
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 15),
                _circularIconButton(Icons.add, () => _adjustQuantity(1)),
              ],
            ),
          ),
        ],
      ),
 actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        // ✅ الحل هنا: إضافة Row ليكون هو الأب المباشر للـ Expanded
        Row(
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("إلغاء", style: TextStyle(color: Colors.grey)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    final qty = int.parse(controller.text);
                    if (widget.isSupply) {
                      widget.cubitContext
                          .read<InventoryCubit>()
                          .transferStockToProduct(widget.item, qty);
                    } else {
                      widget.cubitContext
                          .read<InventoryCubit>()
                          .updateInventoryQuantity(widget.item, qty, false);
                    }
                    Navigator.pop(context);
                  }
                },
                child: const Text(
                  "تأكيد العملية",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _circularIconButton(IconData icon, VoidCallback onPressed) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(50),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: Colors.black87),
        ),
      ),
    );
  }
}
