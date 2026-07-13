import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/helpers.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../provider/auth_provider.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {

  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {

    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();

    final success = await authProvider.signup(
      fullName: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      confirmPassword: _confirmPasswordController.text,
    );

    if (!mounted) return;

    if (success) {
      context.go(AppRoutes.welcome);
    } else {
      Helpers.showSnackBar(
        context,
        authProvider.errorMessage,
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.transparent,

      body: SizedBox.expand(
      child: Container(
      decoration: const BoxDecoration(
      gradient: AppColors.backgroundGradient,
    ),

        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),

            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,

                child: Form(
                  key: _formKey,

                  child: Column(
                    children: [

                      /// BACK BUTTON
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios),
                          color: AppColors.textPrimary,
                          onPressed: () => context.go(AppRoutes.login),
                        ),
                      ),

                      const SizedBox(height: 20),

                      /// ROUND LOGO
                      Container(
  width: 90,
  height: 90,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    border: Border.all(
      color: AppColors.primary,
      width: 2.5,
    ),
   boxShadow: [
  BoxShadow(
    color: AppColors.primary.withOpacity(0.6),
    blurRadius: 20,
    spreadRadius: 2,
  ),
],
  ),
  child: ClipOval(
    child: Image.asset(
      'assets/images/eagle_logo.png',
      fit: BoxFit.cover,
    ),
  ),
),

                      const SizedBox(height: 24),

                      /// TITLE
                      const Text(
                        AppStrings.createAccount,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        AppStrings.signupSubtitle,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary,
                        ),
                      ),

                      const SizedBox(height: 32),

                      /// NAME
                      CustomTextField(
                        controller: _nameController,
                        hintText: AppStrings.fullName,
                        prefixIcon: Icons.person_outline,
                        validator: (v) =>
                            Validators.validateRequired(v, 'Full name'),
                      ),

                      const SizedBox(height: 16),

                      /// EMAIL
                      CustomTextField(
                        controller: _emailController,
                        hintText: AppStrings.email,
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: Validators.validateEmail,
                      ),

                      const SizedBox(height: 16),

                      /// PASSWORD
                      CustomTextField(
                        controller: _passwordController,
                        hintText: AppStrings.password,
                        prefixIcon: Icons.lock_outline,
                        obscureText: _obscurePassword,
                        validator: Validators.validatePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),

                      const SizedBox(height: 16),

                      /// CONFIRM PASSWORD
                      CustomTextField(
                        controller: _confirmPasswordController,
                        hintText: AppStrings.confirmPassword,
                        prefixIcon: Icons.lock_outline,
                        obscureText: _obscureConfirm,
                        validator: (v) =>
                            Validators.validateConfirmPassword(
                          v,
                          _passwordController.text,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirm = !_obscureConfirm;
                            });
                          },
                        ),
                      ),

                      const SizedBox(height: 32),

                      /// SIGNUP BUTTON
                      Consumer<AuthProvider>(
                        builder: (context, auth, _) {
                          return CustomButton(
                            text: AppStrings.signUp,
                            isLoading: auth.isLoading,
                            onPressed: _handleSignup,
                          );
                        },
                      ),

                      const SizedBox(height: 24),

                      /// LOGIN LINK
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [

                          const Text(
                            AppStrings.hasAccount,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: AppColors.textSecondary,
                            ),
                          ),

                          GestureDetector(
                            onTap: () => context.go(AppRoutes.login),
                            child: const Text(
                              AppStrings.login,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }
}