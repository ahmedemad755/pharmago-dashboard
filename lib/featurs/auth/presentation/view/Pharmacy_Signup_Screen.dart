// ignore_for_file: must_be_immutable
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb; // للتمييز بين الويب والموبايل
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fruitesdashboard/core/di/injection.dart';
import 'package:fruitesdashboard/core/function_helper/build_overlay_bar.dart';
import 'package:fruitesdashboard/core/function_helper/on_generate_routing.dart';
import 'package:fruitesdashboard/core/function_helper/widgets/custom_button.dart';
import 'package:fruitesdashboard/core/repos/imag_repo/imag_repo.dart';
import 'package:fruitesdashboard/core/utils/app_colors.dart';
import 'package:fruitesdashboard/featurs/auth/presentation/cubits/signup/pharmacy_signup_cubit.dart';
import 'package:fruitesdashboard/featurs/auth/widgets/cusstom_textfield.dart';
import 'package:fruitesdashboard/featurs/auth/widgets/password_field.dart';
import 'package:fruitesdashboard/featurs/auth/widgets/showtermsandcondetions.dart';
import 'package:image_picker/image_picker.dart';
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';

class PharmacySignupView extends StatefulWidget {
  const PharmacySignupView({super.key});

  @override
  State<PharmacySignupView> createState() => _PharmacySignupViewState();
}

class _PharmacySignupViewState extends State<PharmacySignupView> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  AutovalidateMode autovalidateMode = AutovalidateMode.disabled;
  final TextEditingController _addressController = TextEditingController();
double? latitude;
double? longitude;

  bool _isTermsAccepted = false;
  bool _isUploadingImage = false;
  
  // تغيير النوع لـ XFile ليتوافق مع الويب والموبايل ويحل مشكلة _Namespace
  XFile? _licenseImage; 
  String? _uploadedImageUrl;
  
  late String nationalId;
  late String email, password, pharmacyName, phoneNumber, address;
  late String pharmacistName, pharmacistId, licenseNumber;


Future<void> _pickLocationFromMap() async {
  final result = await Navigator.of(context).pushNamed(AppRoutes.mapScreen);

  if (result != null && result is Map<String, dynamic>) {
    setState(() {
      // تحديث النص في الحقل فوراً بالعنوان الفعلي
      _addressController.text = result['address'] ?? "عنوان غير معروف";
      
      // تخزين القيم للإرسال للسيرفر
      address = result['address'] ?? "";
      latitude = result['lat'];
      longitude = result['lng'];
    });
  }
}
  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (image != null) {
      setState(() {
        _licenseImage = image; // هنا نخزن الـ XFile مباشرة
        _isUploadingImage = true;
      });

      // نمرر الـ XFile للـ Repo (تأكد أن Repo يستقبل XFile أو File)
      final result = await getIt<ImagRepo>().uploadImage(image);

      result.fold(
        (failure) {
          setState(() {
            _isUploadingImage = false;
            _licenseImage = null;
          });
          showBar(context, "فشل رفع الصورة: ${failure.message}");
        },
        (url) {
          setState(() {
            _uploadedImageUrl = url;
            _isUploadingImage = false;
          });
          showBar(context, "تم رفع صورة الترخيص بنجاح ✅");
        },
      );
    }
  }

  void _submitForm() {
    if (!_isTermsAccepted) {
      showBar(context, 'يجب الموافقة على الشروط والأحكام أولاً');
      return;
    }

    // التعديل هنا يا هندسة: لازم نتأكد إن اللوكيشن اتحدد
  if (latitude == null || longitude == null) {
    showBar(context, 'الرجاء تحديد موقع الصيدلية من الخريطة');
    return;
  }

    if (_uploadedImageUrl == null) {
      showBar(context, 'الرجاء رفع صورة ترخيص الصيدلية (مطلوب)');
      return;
    }

    if (formKey.currentState!.validate()) {
      formKey.currentState!.save();

      context.read<PharmacySignupCubit>().createPharmacy(
        email: email,
        password: password,
        pharmacyName: pharmacyName,
        phoneNumber: phoneNumber,
        address: address,
        licenseUrl: _uploadedImageUrl!,
        pharmacistName: pharmacistName,
        pharmacistId: pharmacistId,
        licenseNumber: licenseNumber,
        nationalId: nationalId,
         lat: latitude!, 
      lng: longitude!,

      );
    } else {
      setState(() => autovalidateMode = AutovalidateMode.always);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تسجيل صيدلية جديدة'),
        centerTitle: true,
      ),
      body: BlocConsumer<PharmacySignupCubit, PharmacySignupState>(
        listener: (context, state) {
          if (state is PharmacySignupSuccess) {
            showBar(context, "تم إرسال طلبك بنجاح، انتظر مراجعة الإدارة");
            Navigator.of(context).pushReplacementNamed(AppRoutes.pendingApproval);
          }
          if (state is PharmacySignupFailure) {
            showBar(context, state.message);
          }
        },
        builder: (context, state) {
          return ModalProgressHUD(
            inAsyncCall: state is PharmacySignupLoading,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Form(
                key: formKey,
                autovalidateMode: autovalidateMode,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "بيانات الدكتور المسؤول",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    CustomTextFormField(
                      hintText: 'اسم الصيدلي المسؤول',
                      onSaved: (value) => pharmacistName = value!,
                    ),

                    CustomTextFormField(
                      hintText: 'الرقم القومي للصيدلي (14 رقم)',
                      textInputType: TextInputType.number,
                      onSaved: (value) => nationalId = value!,
                      validator: (value) {
                        if (value == null || value.isEmpty || value.length != 14) {
                          return 'يرجى إدخال رقم قومي صحيح مكون من 14 رقم';
                        }
                        return null;
                      },
                    ),

                    CustomTextFormField(
                      hintText: 'رقم القيد النقابي / الكارنيه',
                      onSaved: (value) => pharmacistId = value!,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "بيانات الصيدلية",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                    ),
                    const SizedBox(height: 12),
                    CustomTextFormField(
                      hintText: 'اسم الصيدلية الرسمي',
                      onSaved: (value) => pharmacyName = value!,
                    ),
                    CustomTextFormField(
                      hintText: 'رقم ترخيص الصيدلية',
                      onSaved: (value) => licenseNumber = value!,
                    ),
                    CustomTextFormField(
                      hintText: 'البريد الإلكتروني للعمل',
                      textInputType: TextInputType.emailAddress,
                      onSaved: (value) => email = value!,
                    ),
                    CustomTextFormField(
                      hintText: 'رقم هاتف التواصل',
                      textInputType: TextInputType.phone,
                      onSaved: (value) => phoneNumber = value!,
                    ),
 CustomTextFormField(
  controller: _addressController, // اربطه بالكنترولر
  hintText: 'عنوان الصيدلية بالتفصيل',
  readOnly: true, // خليه ميكتبش بإيده عشان نضمن إنه اختار من الخريطة
  onTap: _pickLocationFromMap, // يفتح الخريطة لما يضغط على الحقل
  suffixIcon: IconButton(
    icon: const Icon(Icons.map_outlined, color: Colors.blue),
    onPressed: _pickLocationFromMap,
  ),
  onSaved: (value) => address = value!,
),
                    const SizedBox(height: 20),
                    const Text(
                      "المستندات القانونية",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    _buildImagePickerBox(),
                    const SizedBox(height: 16),
                    PasswordField(onSaved: (value) => password = value!),
                    const SizedBox(height: 8),
                    _buildTermsCheckbox(),
                    const SizedBox(height: 24),
                    GradientButton(
                      label: 'إرسال طلب الانضمام',
                      onPressed: _isUploadingImage ? () {} : _submitForm,
                    ),
                    const SizedBox(height: 16),
                    _buildLoginRedirect(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildImagePickerBox() {
    return GestureDetector(
      onTap: _isUploadingImage ? null : _pickAndUploadImage,
      child: Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _uploadedImageUrl != null ? Colors.green : AppColors.primary.withOpacity(0.3),
            style: BorderStyle.solid,
          ),
        ),
        child: _isUploadingImage
            ? const Center(child: CircularProgressIndicator())
            : _licenseImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        // العرض باستخدام kIsWeb لضمان عدم حدوث خطأ _Namespace
                        kIsWeb 
                          ? Image.network(_licenseImage!.path, fit: BoxFit.cover, width: double.infinity)
                          : Image.file(File(_licenseImage!.path), fit: BoxFit.cover, width: double.infinity),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: CircleAvatar(
                            backgroundColor: Colors.black54,
                            child: IconButton(
                              icon: const Icon(Icons.edit, color: Colors.white),
                              onPressed: _pickAndUploadImage,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.upload_file_rounded, size: 48, color: AppColors.primary),
                      const SizedBox(height: 10),
                      const Text("اضغط لرفع صورة الترخيص (Image)"),
                      const Text("JPG, PNG", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
      ),
    );
  }

  Widget _buildTermsCheckbox() {
    return Row(
      children: [
        Checkbox(
          value: _isTermsAccepted,
          onChanged: (value) => setState(() => _isTermsAccepted = value!),
          activeColor: AppColors.primary,
        ),
        Expanded(
          child: RichText(
            text: TextSpan(
              text: 'أوافق على ',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
              children: [
                TextSpan(
                  text: 'الشروط والأحكام الخاصة بالصيادلة',
                  style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => showTermsAndConditionsDialog(
                      context,
                      (v) => setState(() => _isTermsAccepted = v),
                    ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginRedirect() {
    return Center(
      child: TextButton(
        onPressed: () => Navigator.of(context).pushReplacementNamed(AppRoutes.login),
        child: const Text('هل لديك حساب بالفعل؟ تسجيل دخول'),
      ),
    );
  }
}