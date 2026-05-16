import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:fruitesdashboard/core/utils/app_colors.dart';
import 'package:fruitesdashboard/core/utils/backend_points.dart';

class DashboardAnalyticsView extends StatefulWidget {
  const DashboardAnalyticsView({super.key});

  @override
  State<DashboardAnalyticsView> createState() => _DashboardAnalyticsViewState();
}

class _DashboardAnalyticsViewState extends State<DashboardAnalyticsView> {
  String selectedFilter = 'Daily';

  DateTime getStartDate() {
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    switch (selectedFilter) {
      case 'Daily':
        return today;
      case 'Weekly':
        return today.subtract(const Duration(days: 7));
      case 'Monthly':
        return DateTime(now.year, now.month - 1, now.day);
      case 'Yearly':
        return DateTime(now.year, 1, 1);
      default:
        return today;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String currentPharmacyId =
        FirebaseAuth.instance.currentUser?.uid ?? "";
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWeb = screenWidth > 900; // تحديد وضع الويب بناءً على العرض

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: AppColors.primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "التحليلات والمبيعات",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(BackendPoints.getOrders)
            .where('pharmacyId', isEqualTo: currentPharmacyId)
            .snapshots(),
        builder: (context, ordersSnapshot) {
          if (ordersSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryColor),
            );
          }

          final allOrders = ordersSnapshot.data?.docs ?? [];
          DateTime startDate = getStartDate();
          double deliveredSales = 0;
          double totalPeriodProfit = 0;
          int deliveredCount = 0;
          int cancelledCount = 0;
          int pendingCount = 0;
          Map<double, double> chartDataMap = {};

          final filteredOrders = allOrders.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final String? dateStr = data['date'];
            if (dateStr == null) return false;
            DateTime? orderDate = DateTime.tryParse(dateStr);
            if (orderDate == null) return false;
            return orderDate.isAfter(startDate) ||
                orderDate.isAtSameMomentAs(startDate);
          }).toList();

          for (var doc in filteredOrders) {
            final data = doc.data() as Map<String, dynamic>;
            final String status = (data['status'] ?? 'pending')
                .toString()
                .toLowerCase();
            final double totalPrice = (data['totalPrice'] ?? 0).toDouble();
            final DateTime? orderDate = DateTime.tryParse(data['date'] ?? "");

            if (orderDate != null &&
                (status == 'delivered' || status == 'shipped')) {
              double key = selectedFilter == 'Daily'
                  ? orderDate.hour.toDouble()
                  : orderDate.day.toDouble();
              chartDataMap[key] = (chartDataMap[key] ?? 0) + totalPrice;
            }

            if (status == 'delivered' || status == 'shipped') {
              deliveredSales += totalPrice;
              deliveredCount++;
              final List? products = data['orderProducts'];
              if (products != null) {
                for (var item in products) {
                  totalPeriodProfit +=
                      ((item['price'] ?? 0) - (item['cost'] ?? 0)) *
                      (item['quantity'] ?? 1);
                }
              }
            } else if (status.contains('cancel')) {
              cancelledCount++;
            } else {
              pendingCount++;
            }
          }

          return Center(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: isWeb ? 1200 : double.infinity,
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isWeb ? 40 : 16,
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle("تحديد النطاق الزمني"),
                    const SizedBox(height: 12),
                    isWeb
                        ? Center(
                            child: SizedBox(
                              width: 600,
                              child: _buildTimeFilter(),
                            ),
                          )
                        : _buildTimeFilter(),
                    const SizedBox(height: 30),

                    // تخطيط متجاوب للويب: الرسم البياني بجانب الإحصائيات
                    if (isWeb)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildChartWithTitle(chartDataMap),
                          ),
                          const SizedBox(width: 30),
                          Expanded(
                            flex: 1,
                            child: _buildStatGrid(
                              currentPharmacyId: currentPharmacyId,
                              deliveredSales: deliveredSales,
                              totalProfit: totalPeriodProfit,
                              deliveredCount: deliveredCount,
                              cancelled: cancelledCount,
                              pending: pendingCount,
                              isWeb: true,
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _buildChartWithTitle(chartDataMap),
                      const SizedBox(height: 25),
                      _buildSectionTitle(
                        "أداء المبيعات (${_getArabicFilterName()})",
                      ),
                      const SizedBox(height: 15),
                      _buildStatGrid(
                        currentPharmacyId: currentPharmacyId,
                        deliveredSales: deliveredSales,
                        totalProfit: totalPeriodProfit,
                        deliveredCount: deliveredCount,
                        cancelled: cancelledCount,
                        pending: pendingCount,
                        isWeb: false,
                      ),
                    ],

                    const SizedBox(height: 30),
                    _buildSectionTitle("المنتجات الأكثر مبيعاً (إجمالي)"),
                    const SizedBox(height: 15),
                    _buildTopProductsLayout(currentPharmacyId, isWeb),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // المساعدة في تجميع عنوان الشارت مع الويدجت
  Widget _buildChartWithTitle(Map<double, double> chartDataMap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("تحليل نمو المبيعات"),
        const SizedBox(height: 15),
        _buildSalesBarChart(chartDataMap),
      ],
    );
  }

  // تعديل الإحصائيات لتناسب الويب
  Widget _buildStatGrid({
    required String currentPharmacyId,
    required double deliveredSales,
    required double totalProfit,
    required int deliveredCount,
    required int cancelled,
    required int pending,
    required bool isWeb,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('pharmacyId', isEqualTo: currentPharmacyId)
          .snapshots(),
      builder: (context, prodSnapshot) {
        int productCount = prodSnapshot.hasData
            ? prodSnapshot.data!.docs.length
            : 0;
        return GridView.count(
          crossAxisCount: isWeb
              ? 1
              : 2, // عمود واحد في الويب ليكون بجانب الشارت
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: isWeb ? 2.5 : 1.3,
          children: [
            _buildStatCard(
              "إجمالي المبيعات",
              "${deliveredSales.toStringAsFixed(0)} \$",
              Icons.payments_rounded,
              const LinearGradient(
                colors: [Color(0xFF2E7D32), Color(0xFF4CAF50)],
              ),
            ),
            _buildStatCard(
              "صافي ربح الفترة",
              "${totalProfit.toStringAsFixed(0)} \$",
              Icons.trending_up_rounded,
              const LinearGradient(
                colors: [Color(0xFF00B09B), Color(0xFF96C93D)],
              ),
            ),
            _buildStatCard(
              "طلبات ناجحة",
              deliveredCount.toString(),
              Icons.verified_rounded,
              const LinearGradient(
                colors: [Color(0xFF0288D1), Color(0xFF26C6DA)],
              ),
            ),
            _buildStatCard(
              "إجمالي الأصناف",
              productCount.toString(),
              Icons.inventory_2_rounded,
              const LinearGradient(
                colors: [Color(0xFF7E57C2), Color(0xFFAB47BC)],
              ),
            ),
          ],
        );
      },
    );
  }

  // تعديل قائمة المنتجات لتكون Grid في الويب
  Widget _buildTopProductsLayout(String pharmacyId, bool isWeb) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('pharmacyId', isEqualTo: pharmacyId)
          .where('status', whereIn: ['delivered', 'shipped'])
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final orders = snapshot.data!.docs;
        Map<String, Map<String, dynamic>> productStats = {};
        for (var orderDoc in orders) {
          final items = orderDoc['orderProducts'] as List?;
          if (items != null) {
            for (var item in items) {
              String name = item['name'] ?? 'منتج غير معروف';
              if (productStats.containsKey(name)) {
                productStats[name]!['count'] += item['quantity'];
                productStats[name]!['profit'] +=
                    ((item['price'] ?? 0) - (item['cost'] ?? 0)) *
                    (item['quantity'] ?? 1);
              } else {
                productStats[name] = {
                  'count': item['quantity'],
                  'profit':
                      ((item['price'] ?? 0) - (item['cost'] ?? 0)) *
                      (item['quantity'] ?? 1),
                  'image': item['imageUrl'] ?? '',
                  'price': item['price'],
                  'cost': item['cost'],
                };
              }
            }
          }
        }
        var top5 = productStats.entries.toList()
          ..sort((a, b) => b.value['count'].compareTo(a.value['count']));
        top5 = top5.take(5).toList();
        if (top5.isEmpty) return const Text("لا توجد مبيعات مؤكدة.");

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isWeb ? 2 : 1,
            mainAxisSpacing: 12,
            crossAxisSpacing: 15,
            mainAxisExtent: 130, // طول ثابت للكارت
          ),
          itemCount: top5.length,
          itemBuilder: (context, index) => _buildProductCard(top5[index]),
        );
      },
    );
  }

  Widget _buildProductCard(MapEntry<String, Map<String, dynamic>> entry) {
    final stats = entry.value;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              stats['image'],
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.medication, size: 30),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  entry.key,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  "بيع ${stats['count']} قطعة",
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  "الربح: ${stats['profit'].toStringAsFixed(1)} \$",
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                "السعر",
                style: TextStyle(fontSize: 10, color: Colors.blue),
              ),
              Text(
                "${(stats['price'] ?? 0).toStringAsFixed(1)} \$",
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- الرسوم البيانية والألوان (نفس الكود الأصلي مع تحسين الحجم) ---
  Widget _buildSalesBarChart(Map<double, double> data) {
    // تحويل البيانات إلى قائمة من BarChartGroupData
    List<BarChartGroupData> barGroups = data.entries.map((e) {
      return BarChartGroupData(
        x: e.key.toInt(),
        barRods: [
          BarChartRodData(
            toY: e.value,
            color: AppColors.primaryColor,
            width: 16, // عرض العمود
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(6),
            ), // تدوير الحواف العلوية فقط
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: data.values.isEmpty
                  ? 0
                  : data.values.reduce(
                      (a, b) => a > b ? a : b,
                    ), // خلفية خفيفة لبيان الطول الأقصى
              color: AppColors.primaryColor.withOpacity(0.1),
            ),
          ),
        ],
      );
    }).toList()..sort((a, b) => a.x.compareTo(b.x));

    return Container(
      height: 400,
      padding: const EdgeInsets.fromLTRB(15, 25, 15, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15),
        ],
      ),
      child: BarChart(
        BarChartData(
          alignment:
              BarChartAlignment.spaceAround, // توزيع الأعمدة بشكل متساوٍ وواضح
          maxY: data.values.isEmpty
              ? 100
              : data.values.reduce((a, b) => a > b ? a : b) *
                    1.2, // ترك مساحة علوية
          // --- تفاصيل محور X (الأفقي) ---
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) => Text(
                  '${value.toInt()}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: 1, // إظهار عنوان لكل عمود لضمان الوضوح التام
                getTitlesWidget: (value, meta) {
                  String text = '';
                  // تخصيص النص بناءً على الفلتر المختير
                  if (selectedFilter == 'Daily') {
                    int hour = value.toInt();
                    text = hour >= 12
                        ? '${hour == 12 ? 12 : hour - 12}م'
                        : '${hour == 0 ? 12 : hour}ص';
                  } else if (selectedFilter == 'Yearly') {
                    List<String> months = [
                      "",
                      "يناير",
                      "فبراير",
                      "مارس",
                      "أبريل",
                      "مايو",
                      "يونيو",
                      "يوليو",
                      "أغسطس",
                      "سبتمبر",
                      "أكتوبر",
                      "نوفمبر",
                      "ديسمبر",
                    ];
                    text = (value.toInt() >= 1 && value.toInt() <= 12)
                        ? months[value.toInt()]
                        : "";
                  } else {
                    text = value.toInt().toString(); // لليومي أو الأسبوعي
                  }

                  return SideTitleWidget(
                    meta: meta,
                    space: 8,
                    fitInside: SideTitleFitInsideData(
                      enabled: true,
                      axisPosition: meta.axisPosition,
                      parentAxisSize: meta.parentAxisSize,
                      distanceFromEdge: 0,
                    ),
                    child: Text(
                      text,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // --- تفاعل اللمس ---
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => Colors.blueGrey,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${rod.toY.toStringAsFixed(1)} \$',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),

          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) =>
                FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1),
          ),
          barGroups: barGroups,
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Gradient gradient,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: Colors.white70, size: 28),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                title,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
  Widget _buildTimeFilter() {
    final filters = ['Daily', 'Weekly', 'Monthly', 'Yearly'];
    return Row(
      children: filters.map((filter) {
        bool isSelected = selectedFilter == filter;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => selectedFilter = filter),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryColor : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primaryColor
                      : Colors.grey.shade300,
                ),
              ),
              child: Center(
                child: Text(
                  _translateFilter(filter),
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black54,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _translateFilter(String f) => f == 'Daily'
      ? "اليوم"
      : f == 'Weekly'
      ? "الأسبوع"
      : f == 'Monthly'
      ? "الشهر"
      : "السنة";
  String _getArabicFilterName() => _translateFilter(selectedFilter);
  Widget _buildSectionTitle(String title) => Text(
    title,
    style: const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: Color(0xFF1A237E),
    ),
  );
}
