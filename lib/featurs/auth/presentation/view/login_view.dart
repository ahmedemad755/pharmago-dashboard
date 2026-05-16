import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fruitesdashboard/core/function_helper/build_overlay_bar.dart';
import 'package:fruitesdashboard/core/function_helper/on_generate_routing.dart';
import 'package:fruitesdashboard/core/function_helper/widgets/custom_button.dart';
import 'package:fruitesdashboard/core/services/shared_prefs_singelton.dart';
import 'package:fruitesdashboard/core/utils/app_colors.dart';
import 'package:fruitesdashboard/featurs/auth/presentation/cubits/login/pharmacy_login_cubit.dart';
import 'package:fruitesdashboard/featurs/auth/presentation/cubits/login/pharmacy_login_state.dart';
import 'package:fruitesdashboard/featurs/auth/widgets/cusstom_textfield.dart';
import 'package:fruitesdashboard/featurs/auth/widgets/customProgressLoading.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  // 1. استخدام Controllers لضمان دقة البيانات والتحكم بها
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  AutovalidateMode autovalidateMode = AutovalidateMode.disabled;
  bool _obscurePassword = true;
  String? savedStatus;

  @override
  void initState() {
    super.initState();
    // ✅ قراءة الحالة المخزنة عند فتح الصفحة
    savedStatus = Prefs.getString("pharmacy_status");
  }

  @override
  void dispose() {
    // تنظيف الذاكرة
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('تسجيل دخول الصيدلية'),
      ),
      body: BlocConsumer<PharmacyLoginCubit, PharmacyLoginState>(
        listener: (context, state) async {
          // أضفنا async هنا
          if (state is PharmacyLoginSuccess) {
            // 1. استخراج بيانات الصيدلية من الـ Entity
            final pharmacy = state.pharmacyEntity;

            // 2. تحويل البيانات لـ JSON وحفظها فوراً
            Map<String, dynamic> userData = {
              'uId': pharmacy.uId, // هذا هو الـ ID الذي يحل مشكلة الـ Indicator
              'pharmacyName': pharmacy.pharmacyName,
              'status': pharmacy.status,
            };

            // حفظ في الذاكرة الدائمة
            await Prefs.setString("kUserData", jsonEncode(userData));
            await Prefs.setString("pharmacy_status", pharmacy.status);

            print("✅ Data Saved to Prefs: $userData");

            // 3. الانتقال بناءً على الحالة
            if (pharmacy.status == 'approved') {
              Navigator.of(context).pushReplacementNamed(AppRoutes.home);
            } else {
              Navigator.of(
                context,
              ).pushReplacementNamed(AppRoutes.pendingApproval);
            }
          }

          if (state is PharmacyLoginFailure) {
            if (state.message.trim().isNotEmpty) {
              showBar(context, state.message);
            }
          }

          if (state is AccountDisabledLogout) {
            showBar(context, state.message);
          }
        },
        builder: (context, state) {
          return CustomProgresIndecatorHUD(
            isLoading: state is PharmacyLoginLoading,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 24 : 40,
                  vertical: 32,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: SingleChildScrollView(
                      reverse:
                          true, // يساعد في تجربة المستخدم عند ظهور الكيبورد
                      child: Form(
                        key: formKey,
                        autovalidateMode: autovalidateMode,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 20),
                            Text(
                              'مرحباً دكتور،',
                              style: TextStyle(
                                fontSize: isMobile ? 28 : 32,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'سجل دخولك لإدارة صيدليتك',
                              style: TextStyle(
                                fontSize: isMobile ? 14 : 16,
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 40),

                            // 3. حقل البريد مع Validator متقدم
                            CustomTextFormField(
                              controller: emailController,
                              hintText: 'البريد الإلكتروني',
                              prefixIcon: Icons.email_outlined,
                              textInputType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'الرجاء إدخال البريد الإلكتروني';
                                }
                                final emailRegex = RegExp(
                                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                );
                                if (!emailRegex.hasMatch(value)) {
                                  return 'البريد الإلكتروني غير صالح';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            // 4. حقل كلمة المرور مع التحكم في الرؤية
                            CustomTextFormField(
                              controller: passwordController,
                              hintText: 'كلمة المرور',
                              prefixIcon: Icons.lock_outline,
                              obscureText: _obscurePassword,
                              textInputType: TextInputType.visiblePassword,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.grey,
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'الرجاء إدخال كلمة المرور';
                                }
                                if (value.length < 6) {
                                  return 'كلمة المرور قصيرة جداً';
                                }
                                return null;
                              },
                            ),

                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: () {
                                  Navigator.of(
                                    context,
                                  ).pushNamed(AppRoutes.forgotPassword);
                                },
                                child: const Text(
                                  'نسيت كلمة المرور؟',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 32),

                            // 5. زر الدخول مع الـ Trim لضمان دقة الإرسال
                            GradientButton(
                              label: 'تسجيل دخول',
                              onPressed: () {
                                if (formKey.currentState!.validate()) {
                                  context
                                      .read<PharmacyLoginCubit>()
                                      .signInWithEmailAndPassword(
                                        email: emailController.text.trim(),
                                        password: passwordController.text,
                                      );
                                } else {
                                  setState(() {
                                    autovalidateMode = AutovalidateMode.always;
                                  });
                                }
                              },
                            ),

                            const SizedBox(height: 24),

                            Center(
                              child: RichText(
                                text: TextSpan(
                                  text: 'لا تمتلك حساب صيدلية؟ ',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontWeight: FontWeight.w600,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: 'قدم طلب انضمام',
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      recognizer: TapGestureRecognizer()
                                        ..onTap = () {
                                          Navigator.of(
                                            context,
                                          ).pushNamed(AppRoutes.signup);
                                        },
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
