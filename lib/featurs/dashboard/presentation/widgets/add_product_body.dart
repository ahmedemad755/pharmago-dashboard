// ignore_for_file: must_be_immutable
import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fruitesdashboard/core/const/dashboardPageTemplate.dart';
import 'package:fruitesdashboard/core/function_helper/widgets/custom_button.dart';
import 'package:fruitesdashboard/core/services/shared_prefs_singelton.dart';
import 'package:fruitesdashboard/featurs/add_product/domain/entities/add_product_intety.dart';
import 'package:fruitesdashboard/featurs/add_product/presentation/manger/cubit/add_product_cubit.dart';
import 'package:fruitesdashboard/featurs/dashboard/data/services/global_product_matching_service.dart';
import 'package:fruitesdashboard/featurs/dashboard/presentation/widgets/cusstom_textfield.dart';
import 'package:fruitesdashboard/featurs/dashboard/presentation/widgets/imag_feild.dart';
import 'package:image_picker/image_picker.dart';

class AddProductBody extends StatefulWidget {
  XFile? image;
  String? name, code, description, pharmacyId;
  num? price;
  num? cost;
  int? expirationDate;
  int? unitAmount;
  bool hasDiscount = false;
  num? discountPercentage = 0;
  String? selectedCategory;
  String? pharmacyName;
  double? pharmacyLat;
  double? pharmacyLng;
  bool isPrescriptionRequired = false;

  AddProductBody({
    super.key,
    this.image,
    this.name,
    this.price,
    this.cost,
    this.code,
    this.description,
    this.expirationDate,
    this.unitAmount,
    this.pharmacyId,
    this.pharmacyName,
    this.pharmacyLat,
    this.pharmacyLng,
  });

  @override
  State<AddProductBody> createState() => _AddProductBodyState();
}

class _AddProductBodyState extends State<AddProductBody> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final GlobalProductMatchingService _matchingService =
      GlobalProductMatchingService();

  AutovalidateMode autovalidateMode = AutovalidateMode.disabled;
  Timer? _barcodeDebounce;
  bool _isLookingUpBarcode = false;
  bool _isMatchingExcel = false;
  bool _isCommittingBulk = false;
  String? _globalImageUrl;
  String? _barcodeStatusMessage;
  List<BulkProductMatch> _previewMatches = const [];
  final Map<String, TextEditingController> _previewPriceControllers = {};

  late final TextEditingController nameController;
  late final TextEditingController barcodeController;
  late final TextEditingController descriptionController;
  late final TextEditingController priceController;
  late final TextEditingController costController;
  late final TextEditingController unitAmountController;
  late final TextEditingController expirationController;
  late final TextEditingController pharmacyNameController;
  late final TextEditingController pharmacistIdController;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.name ?? '');
    barcodeController = TextEditingController(text: widget.code ?? '');
    descriptionController =
        TextEditingController(text: widget.description ?? '');
    priceController =
        TextEditingController(text: widget.price?.toString() ?? '');
    costController = TextEditingController(text: widget.cost?.toString() ?? '');
    unitAmountController =
        TextEditingController(text: widget.unitAmount?.toString() ?? '');
    expirationController = TextEditingController();
    pharmacyNameController = TextEditingController();
    pharmacistIdController = TextEditingController();
    barcodeController.addListener(_onBarcodeChanged);
    _getPharmacyIdFromPrefs();
  }

  @override
  void dispose() {
    _barcodeDebounce?.cancel();
    nameController.dispose();
    barcodeController.dispose();
    descriptionController.dispose();
    priceController.dispose();
    costController.dispose();
    unitAmountController.dispose();
    expirationController.dispose();
    pharmacyNameController.dispose();
    pharmacistIdController.dispose();
    for (final controller in _previewPriceControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<Map<String, dynamic>?> _getUserData() async {
    String userData = Prefs.getString("kUserData");
    if (userData.isNotEmpty) {
      try {
        return jsonDecode(userData);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  void _getPharmacyIdFromPrefs() async {
    Map<String, dynamic>? userData = await _getUserData();
    final authPharmacyId = FirebaseAuth.instance.currentUser?.uid;
    final savedPharmacyId = userData?['uId']?.toString().trim();
    final pharmacyId = savedPharmacyId != null && savedPharmacyId.isNotEmpty
        ? savedPharmacyId
        : authPharmacyId;

    if (!mounted) return;
    setState(() {
      widget.pharmacyId = pharmacyId;
      widget.pharmacyName = userData?['pharmacyName']?.toString();
    });
  }

  Future<bool> _ensureCurrentPharmacy() async {
    if (widget.pharmacyId != null && widget.pharmacyId!.trim().isNotEmpty) {
      return true;
    }

    final authPharmacyId = FirebaseAuth.instance.currentUser?.uid;
    if (authPharmacyId == null || authPharmacyId.trim().isEmpty) {
      return false;
    }

    if (!mounted) return false;
    setState(() => widget.pharmacyId = authPharmacyId);
    return true;
  }

  void _onBarcodeChanged() {
    _barcodeDebounce?.cancel();
    _barcodeDebounce = Timer(const Duration(milliseconds: 500), () {
      _lookupGlobalProduct(barcodeController.text);
    });
  }

  Future<void> _lookupGlobalProduct(String barcode) async {
    final normalizedBarcode = barcode.trim();
    if (normalizedBarcode.isEmpty) {
      if (!mounted) return;
      setState(() {
        _globalImageUrl = null;
        _barcodeStatusMessage = null;
      });
      return;
    }

    setState(() {
      _isLookingUpBarcode = true;
      _barcodeStatusMessage = null;
    });

    try {
      final globalProduct =
          await _matchingService.findByBarcode(normalizedBarcode);
      if (!mounted) return;

      setState(() {
        _isLookingUpBarcode = false;
        if (globalProduct == null) {
          _globalImageUrl = null;
          _barcodeStatusMessage =
              "لم يتم العثور على المنتج في المكتبة العالمية";
          return;
        }

        nameController.text = globalProduct.name;
        descriptionController.text = globalProduct.description;
        widget.selectedCategory = globalProduct.category.isEmpty
            ? widget.selectedCategory
            : globalProduct.category;
        _globalImageUrl = globalProduct.imageUrl;
        _barcodeStatusMessage =
            "تم العثور على المنتج. أدخل السعر والتكلفة والكمية فقط.";
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLookingUpBarcode = false;
        _barcodeStatusMessage = "تعذر البحث في المكتبة العالمية";
      });
    }
  }

  Future<void> _pickAndMatchExcel() async {
    _clearPreviewPriceControllers();
    setState(() {
      _isMatchingExcel = true;
      _previewMatches = const [];
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
        withData: true,
      );
      final bytes = result?.files.single.bytes;
      if (result == null || bytes == null) {
        if (!mounted) return;
        setState(() => _isMatchingExcel = false);
        return;
      }

      final matches = await _matchingService.matchExcelBytes(bytes);
      if (!mounted) return;
      _seedPreviewPriceControllers(matches);
      setState(() {
        _previewMatches = matches;
        _isMatchingExcel = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isMatchingExcel = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("تعذر قراءة ملف Excel: $e")),
      );
    }
  }

  Future<void> _commitBulkPreview() async {
    final hasPharmacy = await _ensureCurrentPharmacy();
    if (!hasPharmacy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("تعذر تحديد الصيدلية الحالية")),
      );
      return;
    }

    final matchedCount =
        _previewMatches.where((match) => match.isMatched).length;
    if (matchedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("لا توجد منتجات مطابقة للحفظ")),
      );
      return;
    }

    setState(() => _isCommittingBulk = true);
    try {
      final matchesWithEditedPrices = _matchesWithEditedPrices();
      await _matchingService.commitMatchedProducts(
        pharmacyId: widget.pharmacyId!,
        pharmacyName: widget.pharmacyName ?? pharmacyNameController.text,
        pharmacyLat: widget.pharmacyLat ?? 0.0,
        pharmacyLng: widget.pharmacyLng ?? 0.0,
        matches: matchesWithEditedPrices,
      );
      if (!mounted) return;
      _clearPreviewPriceControllers();
      setState(() {
        _isCommittingBulk = false;
        _previewMatches = const [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("تم حفظ $matchedCount منتج بنجاح")),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCommittingBulk = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("تعذر حفظ المنتجات: $e")),
      );
    }
  }

  void _seedPreviewPriceControllers(List<BulkProductMatch> matches) {
    for (final match in matches) {
      _previewPriceControllers[match.barcode] = TextEditingController(
        text: match.price.toString(),
      );
    }
  }

  void _clearPreviewPriceControllers() {
    for (final controller in _previewPriceControllers.values) {
      controller.dispose();
    }
    _previewPriceControllers.clear();
  }

  List<BulkProductMatch> _matchesWithEditedPrices() {
    return _previewMatches.map((match) {
      final controller = _previewPriceControllers[match.barcode];
      final editedPrice = num.tryParse(controller?.text.trim() ?? '');
      return match.copyWith(price: editedPrice ?? match.price);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWeb = screenWidth > 800;

    return DashboardPageTemplate(
      title: "إضافة دواء جديد",
      subtitle:
          "استخدم الباركود للبحث في المكتبة العالمية أو ارفع ملف Excel للربط الذكي",
      content: SliverList(
        delegate: SliverChildListDelegate([
          Form(
            key: formKey,
            autovalidateMode: autovalidateMode,
            child: Column(
              children: [
                _buildSectionTitle("بيانات الصيدلية المصدر"),
                buildReadOnlyPharmacyFields(isWeb),
                const SizedBox(height: 24),
                _buildSectionTitle("المعلومات الأساسية"),
                _buildResponsiveRow(isWeb, [
                  buildNameField(),
                  buildCategoryField(),
                ]),
                _buildResponsiveRow(isWeb, [
                  buildPriceField(),
                  buildCostField(),
                ]),
                _buildResponsiveRow(isWeb, [
                  buildCodeField(),
                  buildUnitAmountField(),
                ]),
                if (_isLookingUpBarcode)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: LinearProgressIndicator(color: Colors.teal),
                  ),
                if (_barcodeStatusMessage != null)
                  _buildLookupBanner(_barcodeStatusMessage!),
                _buildSectionTitle("الصلاحية والخيارات المتقدمة"),
                _buildResponsiveRow(isWeb, [
                  buildExpirationDateField(),
                  buildDiscountSection(),
                ]),
                const SizedBox(height: 16),
                buildDescriptionField(),
                const SizedBox(height: 32),
                _buildActionSection(isWeb),
                const SizedBox(height: 28),
                _buildBulkUploadSection(isWeb),
                const SizedBox(height: 24),
              ],
            ),
          ),
          if (_previewMatches.isNotEmpty) _buildPreviewSection(),
          const SizedBox(height: 60),
        ]),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.teal,
          ),
        ),
      ),
    );
  }

  Widget _buildResponsiveRow(bool isWeb, List<Widget> children) {
    if (!isWeb) {
      return Column(
        children: children
            .map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: c,
                ))
            .toList(),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children
            .map((c) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: c,
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildLookupBanner(String message) {
    final found = _globalImageUrl != null && _globalImageUrl!.isNotEmpty;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: found ? Colors.teal.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: found ? Colors.teal : Colors.orange),
      ),
      child: Row(
        children: [
          Icon(found ? Icons.check_circle : Icons.info_outline,
              color: found ? Colors.teal : Colors.orange),
          const SizedBox(width: 10),
          Expanded(child: Text(message, textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _buildActionSection(bool isWeb) {
    final hasGlobalImage = _globalImageUrl != null && _globalImageUrl!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 40,
        runSpacing: 24,
        children: [
          SizedBox(
            width: isWeb ? 350 : double.infinity,
            child: hasGlobalImage
                ? _buildGlobalImagePreview(_globalImageUrl!)
                : buildImageField(),
          ),
          SizedBox(
            width: isWeb ? 300 : double.infinity,
            child: buildAddButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalImagePreview(String imageUrl) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            imageUrl,
            height: 130,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 130,
              color: Colors.grey.shade100,
              alignment: Alignment.center,
              child: const Icon(Icons.image_not_supported_outlined),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "سيتم استخدام صورة المكتبة العالمية",
          style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildBulkUploadSection(bool isWeb) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionTitle("رفع Excel ذكي"),
          Text(
            "الأعمدة المطلوبة بالترتيب: Barcode, Price, Cost, Quantity",
            textAlign: TextAlign.right,
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 16),
          GradientButton(
            gradientColors: const [Colors.blueGrey, Colors.teal],
            label: _isMatchingExcel ? "جاري المطابقة..." : "اختيار ملف Excel",
            onPressed: () {
              if (_isMatchingExcel) return;
              _pickAndMatchExcel();
            },
          ),
          if (_isMatchingExcel)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(color: Colors.teal),
            ),
        ],
      ),
    );
  }

  Widget _buildPreviewSection() {
    final matched =
        _previewMatches.where((match) => match.isMatched).length;
    final unmatched = _previewMatches.length - matched;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                "Preview: $matched matched / $unmatched unmatched",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            SizedBox(
              width: 240,
              child: GradientButton(
                gradientColors: const [Colors.teal, Colors.green],
                label: _isCommittingBulk ? "جاري الحفظ..." : "تأكيد الحفظ",
                onPressed: () {
                  if (_isCommittingBulk) return;
                  _commitBulkPreview();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._previewMatches.map(_buildPreviewRow),
      ],
    );
  }

  Widget _buildPreviewRow(BulkProductMatch match) {
    final isMatched = match.isMatched;
    final imageUrl = match.productImageUrl;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMatched ? Colors.white : Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isMatched ? Colors.grey.shade200 : Colors.red.shade200,
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: isMatched && imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _previewPlaceholder(),
                  )
                : _previewPlaceholder(),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMatched ? match.productName : "غير موجود في المكتبة العالمية",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text("Barcode: ${match.barcode}"),
                if (isMatched) Text(match.productCategory),
              ],
            ),
          ),
          SizedBox(
            width: 120,
            child: TextFormField(
              controller: _previewPriceControllers[match.barcode],
              enabled: isMatched && !_isCommittingBulk,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Price",
                isDense: true,
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          Expanded(child: Text("Cost\n${match.cost}")),
          Expanded(child: Text("Qty\n${match.quantity}")),
          Icon(
            isMatched ? Icons.check_circle : Icons.warning_amber_rounded,
            color: isMatched ? Colors.teal : Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _previewPlaceholder() {
    return Container(
      width: 56,
      height: 56,
      color: Colors.grey.shade100,
      child: const Icon(Icons.medication_outlined, color: Colors.grey),
    );
  }

  Widget buildNameField() => CustomTextFormField(
        controller: nameController,
        hintText: "اسم الدواء",
        textInputType: TextInputType.text,
        onSaved: (value) => widget.name = value!.trim(),
      );

  Widget buildPriceField() => CustomTextFormField(
        controller: priceController,
        hintText: "السعر الأساسي للبيع",
        textInputType: TextInputType.number,
        onSaved: (value) => widget.price = num.tryParse(value!) ?? 0,
      );

  Widget buildCostField() => CustomTextFormField(
        controller: costController,
        hintText: "تكلفة المنتج (الشراء)",
        textInputType: TextInputType.number,
        onSaved: (value) => widget.cost = num.tryParse(value!) ?? 0,
      );

  Widget buildCodeField() => CustomTextFormField(
        controller: barcodeController,
        hintText: "كود المنتج (Barcode)",
        textInputType: TextInputType.text,
        suffixIcon: const Icon(Icons.qr_code_scanner, color: Colors.teal),
        onSaved: (value) => widget.code = value!.trim(),
      );

  Widget buildUnitAmountField() => CustomTextFormField(
        controller: unitAmountController,
        hintText: "الكمية المتوفرة بالمخزن",
        textInputType: TextInputType.number,
        onSaved: (value) => widget.unitAmount = int.tryParse(value!) ?? 0,
      );

  Widget buildDescriptionField() => CustomTextFormField(
        controller: descriptionController,
        hintText: "وصف المنتج واستخداماته...",
        textInputType: TextInputType.multiline,
        maxLines: 4,
        onSaved: (value) => widget.description = value!.trim(),
      );

  Widget buildExpirationDateField() => CustomTextFormField(
        controller: expirationController,
        hintText: "تاريخ انتهاء الصلاحية",
        textInputType: TextInputType.datetime,
        readOnly: true,
        suffixIcon: const Icon(Icons.calendar_today, color: Colors.teal),
        onTap: () async {
          DateTime? pickedDate = await showDatePicker(
            context: context,
            initialDate: DateTime.now().add(const Duration(days: 365)),
            firstDate: DateTime.now(),
            lastDate: DateTime(2100),
          );
          if (pickedDate != null) {
            setState(() {
              expirationController.text =
                  "${pickedDate.year}-${pickedDate.month}-${pickedDate.day}";
              widget.expirationDate = int.parse(
                "${pickedDate.year}${pickedDate.month.toString().padLeft(2, '0')}${pickedDate.day.toString().padLeft(2, '0')}",
              );
            });
          }
        },
      );

  Widget buildCategoryField() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('categories').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const LinearProgressIndicator(color: Colors.teal);
        }

        final categories = snapshot.data!.docs
            .map((doc) => doc['name'].toString())
            .toSet()
            .toList();
        if (widget.selectedCategory != null &&
            widget.selectedCategory!.isNotEmpty &&
            !categories.contains(widget.selectedCategory)) {
          categories.add(widget.selectedCategory!);
        }

        return DropdownButtonFormField<String>(
          hint: const Text("اختر التصنيف"),
          initialValue: widget.selectedCategory,
          items: categories.map((category) {
            return DropdownMenuItem<String>(
              value: category,
              child: Text(category),
            );
          }).toList(),
          onChanged: (value) => setState(() => widget.selectedCategory = value),
          validator: (value) => (value == null) ? "التصنيف مطلوب" : null,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey.shade100,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.teal, width: 2),
            ),
          ),
        );
      },
    );
  }

  Widget buildReadOnlyPharmacyFields(bool isWeb) {
    if (widget.pharmacyId == null) {
      return const LinearProgressIndicator(color: Colors.teal);
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pharmacies')
          .doc(widget.pharmacyId)
          .snapshots(),
      builder: (context, firestoreSnapshot) {
        if (!firestoreSnapshot.hasData || !firestoreSnapshot.data!.exists) {
          return const SizedBox();
        }

        var data = firestoreSnapshot.data!.data() as Map<String, dynamic>;
        widget.pharmacyLat = (data['lat'] as num?)?.toDouble() ?? 0.0;
        widget.pharmacyLng = (data['lng'] as num?)?.toDouble() ?? 0.0;
        widget.pharmacyName = data['pharmacyName']?.toString();

        if (pharmacyNameController.text != data['pharmacyName']) {
          pharmacyNameController.text = data['pharmacyName'] ?? '';
        }
        if (pharmacistIdController.text != data['pharmacistId']) {
          pharmacistIdController.text = data['pharmacistId'] ?? '';
        }

        return _buildResponsiveRow(isWeb, [
          CustomTextFormField(
            hintText: "اسم الصيدلية",
            controller: pharmacyNameController,
            readOnly: true,
            textInputType: TextInputType.text,
          ),
          CustomTextFormField(
            hintText: "معرف الصيدلي",
            controller: pharmacistIdController,
            readOnly: true,
            textInputType: TextInputType.text,
          ),
        ]);
      },
    );
  }

  Widget buildDiscountSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          SwitchListTile(
            title: const Text(
              "يتطلب روشتة طبية",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.redAccent,
              ),
            ),
            subtitle: const Text(
              "سيطلب من العميل رفع صورة الروشتة",
              style: TextStyle(fontSize: 10),
            ),
            value: widget.isPrescriptionRequired,
            activeThumbColor: Colors.red,
            onChanged: (val) =>
                setState(() => widget.isPrescriptionRequired = val),
          ),
          const Divider(height: 20),
          SwitchListTile(
            title: const Text("تفعيل الخصم", style: TextStyle(fontSize: 14)),
            value: widget.hasDiscount,
            activeThumbColor: Colors.teal,
            onChanged: (val) => setState(() => widget.hasDiscount = val),
          ),
          if (widget.hasDiscount)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: CustomTextFormField(
                hintText: "نسبة الخصم %",
                textInputType: TextInputType.number,
                onSaved: (value) =>
                    widget.discountPercentage = num.tryParse(value!) ?? 0,
              ),
            ),
        ],
      ),
    );
  }

  Widget buildImageField() => ImagFeild(
        onImagePicked: (image) => setState(() => widget.image = image),
      );

  Widget buildAddButton() => GradientButton(
        gradientColors: const [Colors.teal, Colors.green],
        label: "تأكيد وإضافة الدواء",
        onPressed: () {
          final hasGlobalImage =
              _globalImageUrl != null && _globalImageUrl!.isNotEmpty;
          if (!hasGlobalImage && widget.image == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content:
                    Text("يرجى اختيار صورة للمنتج أو استخدام باركود عالمي"),
              ),
            );
            return;
          }

          if (formKey.currentState!.validate()) {
            formKey.currentState!.save();

            DateTime expiry;
            try {
              String dateStr = widget.expirationDate.toString();
              if (dateStr.length == 8) {
                expiry = DateTime(
                  int.parse(dateStr.substring(0, 4)),
                  int.parse(dateStr.substring(4, 6)),
                  int.parse(dateStr.substring(6, 8)),
                );
              } else {
                expiry = DateTime.now();
              }
            } catch (e) {
              expiry = DateTime.now();
            }

            final entite = AddProductIntety(
              category: widget.selectedCategory!,
              name: widget.name ?? '',
              price: widget.price ?? 0,
              code: widget.code ?? '',
              description: widget.description ?? '',
              image: widget.image,
              imageurl: _globalImageUrl,
              expirationDate: expiry,
              unitAmount: widget.unitAmount ?? 0,
              reviews: const [],
              hasDiscount: widget.hasDiscount,
              discountPercentage: widget.discountPercentage ?? 0,
              pharmacyId: widget.pharmacyId,
              cost: widget.cost ?? 0,
              isPrescriptionRequired: widget.isPrescriptionRequired,
              pharmacyName: widget.pharmacyName ?? '',
              pharmacyLat: widget.pharmacyLat ?? 0.0,
              pharmacyLng: widget.pharmacyLng ?? 0.0,
            );

            context.read<AddProductCubit>().addProduct(
                  entite,
                  documentId: "${widget.code}_${widget.pharmacyId}",
                );
          } else {
            setState(() => autovalidateMode = AutovalidateMode.always);
          }
        },
      );
}

