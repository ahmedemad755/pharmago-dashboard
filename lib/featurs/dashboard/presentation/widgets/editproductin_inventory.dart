// ملف: lib/featurs/inventory/presentation/views/inventory_view.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fruitesdashboard/core/utils/app_colors.dart';
import 'package:fruitesdashboard/featurs/inventory/domain/entities/inventory_entity.dart';
import 'package:fruitesdashboard/featurs/inventory/presentation/cubit/inventory_cubit.dart';
import 'package:fruitesdashboard/featurs/inventory/presentation/cubit/inventory_state.dart';

class InventoryView extends StatelessWidget {
  const InventoryView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: AppColors.primaryColor,
        elevation: 0,
        title: const Text(
          "المخزن الذكي - لوحة التحكم",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: BlocBuilder<InventoryCubit, InventoryState>(
        builder: (context, state) {
          if (state is InventoryLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is InventoryLoaded) {
            if (state.inventoryList.isEmpty) {
              return const Center(child: Text("المخزن فارغ"));
            }

            // تجميع حسب التصنيف
            Map<String, List<InventoryEntity>> groupedByCategory = {};
            for (var item in state.inventoryList) {
              groupedByCategory.putIfAbsent(item.category, () => []).add(item);
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                // تحديد عدد الأعمدة بناءً على العرض (ويب vs موبايل)
                int crossAxisCount = constraints.maxWidth > 1200
                    ? 3
                    : (constraints.maxWidth > 800 ? 2 : 1);

                return Center(
                  child: Container(
                    constraints: const BoxConstraints(
                      maxWidth: 1400,
                    ), // أقصى عرض للمحتوى في الويب
                    child: GridView.builder(
                      padding: const EdgeInsets.all(24),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 20,
                        mainAxisExtent: 500, // ارتفاع ثابت للكارد لتوحيد المظهر
                      ),
                      itemCount: groupedByCategory.keys.length,
                      itemBuilder: (context, index) {
                        String category = groupedByCategory.keys.elementAt(
                          index,
                        );
                        return _buildCategoryCard(
                          category,
                          groupedByCategory[category]!,
                        );
                      },
                    ),
                  ),
                );
              },
            );
          }
          return const SizedBox();
        },
      ),
    );
  }

  Widget _buildCategoryCard(String category, List<InventoryEntity> items) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.category, color: AppColors.primaryColor),
                const SizedBox(width: 10),
                Text(
                  category,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const Spacer(),
                Badge(
                  label: Text("${items.length}"),
                  backgroundColor: AppColors.primaryColor,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(8),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, idx) =>
                  _buildProductItem(context, items[idx]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductItem(BuildContext context, InventoryEntity item) {
    bool isLowStock = item.quantity < 10;
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          item.productImageUrl ?? "",
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported),
        ),
      ),
      title: Text(
        item.productName,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(
        "الرصيد: ${item.quantity}",
        style: TextStyle(
          color: isLowStock ? Colors.red : Colors.green,
          fontWeight: FontWeight.bold,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.add_box, color: Colors.blue, size: 20),
            onPressed: () => _showSupplyDialog(context, item),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.orange, size: 20),
            onPressed: () {
              // هنا تفتح صفحة التعديل
            },
          ),
        ],
      ),
    );
  }

  // (دوال الديالوج تظل كما هي مع تحسين العرض في الويب)
  void _showSupplyDialog(BuildContext context, InventoryEntity item) {
    final TextEditingController amountController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("توريد ${item.productName}"),
        content: SizedBox(
          width: 400, // عرض ثابت للديالوج في الويب
          child: TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "الكمية المراد نقلها",
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
            ),
            onPressed: () {
              /* منطق الحفظ */
              Navigator.pop(context);
            },
            child: const Text(
              "تأكيد التوريد",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
