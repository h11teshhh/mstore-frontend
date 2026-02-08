import 'dart:ui'; // Required for ImageFilter
import 'package:flutter/material.dart';
import '../api/api_service.dart';
import '../storage/token_storage.dart';
import '../screens/dashboard.dart';
import '../utils/app_constants.dart'; // Importing your constants
import '../utils/ui_utils.dart'; // Importing your UI Utils

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final ApiService api = ApiService();
  final TokenStorage storage = TokenStorage();

  bool loading = false;
  // We don't need a string for error message in UI anymore,
  // we use Toasts as requested.

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    // Simple fade-in animation for smoother entry
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    mobileController.dispose();
    passwordController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> handleLogin() async {
    // 1. Local Validation
    if (mobileController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty) {
      UIUtils.showErrorToast("Please enter both Mobile Number and Password");
      return;
    }

    // 2. Hide Keyboard
    FocusScope.of(context).unfocus();

    setState(() {
      loading = true;
    });

    // 3. User Feedback (Wait message)
    UIUtils.showProcessingSnackbar(
      context,
      message: "Verifying credentials...",
    );

    try {
      final response = await api.login(
        mobileController.text.trim(),
        passwordController.text.trim(),
      );

      // The ApiService interceptor handles HTTP errors.
      // If we reach here, we assume success or a valid response structure.
      if (response.data != null) {
        final token = response.data["access_token"];
        final name = response.data["name"]; // Ensure backend sends this
        final role = response.data["role"]; // Ensure backend sends this

        if (token != null) {
          await storage.saveLoginData(
            token: token,
            name: name ?? "User",
            role: role ?? "Guest",
          );

          UIUtils.showSuccessToast("Welcome back, $name!");

          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const Dashboard()),
              (route) => false, // Remove back stack
            );
          }
        } else {
          throw Exception("Login failed: No token received");
        }
      }
    } catch (e) {
      // The Interceptor in ApiService already showed the specific error toast.
      // We just ensure the loading state stops here.
      // We strictly do NOT show technical error logs to the user.
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Using Sneat-inspired colors from AppConstants
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // --- Background Decorative Elements (blobs) ---
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              height: 200,
              width: 200,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              height: 200,
              width: 200,
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // --- Main Glass Content ---
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    // Logo or Title
                    const Icon(
                      Icons.inventory_2_outlined,
                      size: 60,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Welcome to M-Store",
                      style: AppTypography.heading,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Please sign-in to your account",
                      style: AppTypography.body,
                    ),
                    const SizedBox(height: 40),

                    // --- Glassmorphism Card ---
                    ClipRRect(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.borderRadius * 2,
                      ),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.all(30),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(
                              0.7,
                            ), // Glass opacity
                            borderRadius: BorderRadius.circular(
                              AppDimensions.borderRadius * 2,
                            ),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.8),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.secondary.withOpacity(0.1),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Mobile Input
                              const Text(
                                "Mobile Number",
                                style: AppTypography.label,
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: mobileController,
                                keyboardType: TextInputType.phone,
                                style: const TextStyle(
                                  color: AppColors.textDark,
                                ),
                                decoration: InputDecoration(
                                  hintText: "Enter your mobile number",
                                  hintStyle: const TextStyle(
                                    color: AppColors.textMuted,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.5),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppDimensions.borderRadius,
                                    ),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppDimensions.borderRadius,
                                    ),
                                    borderSide: const BorderSide(
                                      color: AppColors.primary,
                                      width: 1.5,
                                    ),
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.phone_android,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Password Input
                              const Text(
                                "Password",
                                style: AppTypography.label,
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: passwordController,
                                obscureText: true,
                                style: const TextStyle(
                                  color: AppColors.textDark,
                                ),
                                decoration: InputDecoration(
                                  hintText: "············",
                                  hintStyle: const TextStyle(
                                    color: AppColors.textMuted,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.5),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppDimensions.borderRadius,
                                    ),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppDimensions.borderRadius,
                                    ),
                                    borderSide: const BorderSide(
                                      color: AppColors.primary,
                                      width: 1.5,
                                    ),
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.lock_outline,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 30),

                              // Login Button
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: loading ? null : handleLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    shadowColor: AppColors.primary.withOpacity(
                                      0.4,
                                    ),
                                    elevation: 5,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppDimensions.borderRadius,
                                      ),
                                    ),
                                  ),
                                  child: loading
                                      ? const SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text(
                                          "LOGIN",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
