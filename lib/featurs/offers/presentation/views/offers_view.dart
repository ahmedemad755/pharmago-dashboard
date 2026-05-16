import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fruitesdashboard/featurs/offers/domain/entities/fer_entity.dart';
import '../cubit/offers_cubit.dart';

class OffersView extends StatelessWidget {
  const OffersView({super.key});

  @override
  Widget build(BuildContext context) {
    final String pharmacyId = FirebaseAuth.instance.currentUser?.uid ?? "";

    return Scaffold(
      appBar: AppBar(title: const Text("إدارة العروض")),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddOfferSheet(context, pharmacyId),
        child: const Icon(Icons.add),
      ),
      body: BlocBuilder<OffersCubit, OffersState>(
        builder: (context, state) {
          if (state is OffersLoading) return const Center(child: CircularProgressIndicator());
          if (state is OffersLoaded) {
            return ListView.builder(
              itemCount: state.offers.length,
              itemBuilder: (context, index) {
                final offer = state.offers[index];
                return ListTile(
                  title: Text(offer.title),
                  subtitle: Text("${offer.discountPercentage}% خصم"),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => context.read<OffersCubit>().removeOffer(offer.id),
                  ),
                );
              },
            );
          }
          return const Center(child: Text("لا توجد عروض"));
        },
      ),
    );
  }
// features/offers/presentation/views/offers_view.dart

void _showAddOfferSheet(BuildContext context, String pharmacyId) {
  final titleController = TextEditingController();
  final discountController = TextEditingController();
  String? selectedCategoryId;
  String? selectedCategoryName;
  DateTime selectedDate = DateTime.now().add(const Duration(days: 7));

  // 💡 نقوم بحفظ نسخة من الـ Cubit الحالي قبل فتح الـ BottomSheet
  final offersCubit = context.read<OffersCubit>();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
    ),
    builder: (ctx) => BlocProvider.value(
      // ✅ نمرر الـ Cubit المحفوظ للـ context الجديد
      value: offersCubit,
      child: StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("إضافة عرض لقسم كامل", 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: "عنوان العرض", 
                    border: OutlineInputBorder()
                  ),
                ),
                const SizedBox(height: 15),

                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('categories').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const CircularProgressIndicator();
                    
                    return DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: "اختر القسم المستهدف", 
                        border: OutlineInputBorder()
                      ),
                      initialValue: selectedCategoryId,
                      items: snapshot.data!.docs.map((doc) {
                        return DropdownMenuItem<String>(
                          value: doc.id,
                          child: Text(doc['name'] ?? 'بدون اسم'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setModalState(() {
                          selectedCategoryId = val;
                          selectedCategoryName = snapshot.data!.docs
                              .firstWhere((d) => d.id == val)['name'];
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 15),

                TextField(
                  controller: discountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "نسبة الخصم", 
                    suffixText: "%", 
                    border: OutlineInputBorder()
                  ),
                ),
                const SizedBox(height: 20),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pinkAccent,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  onPressed: () {
                    if (selectedCategoryId == null || titleController.text.isEmpty) return;
                    
                    final newOffer = OfferEntity(
                      id: '',
                      title: titleController.text,
                      description: "خصم %${discountController.text} على منتجات $selectedCategoryName",
                      discountPercentage: int.parse(discountController.text),
                      expiryDate: selectedDate,
                      pharmacyId: pharmacyId,
                     targetCategory : selectedCategoryId,
                    );

                    // ✅ الآن سيعمل هذا السطر بدون أخطاء
                    context.read<OffersCubit>().createOffer(newOffer);
                    Navigator.pop(ctx);
                  },
                  child: const Text("تطبيق العرض", style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
}