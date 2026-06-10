import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../api/api_service.dart';
import '../storage/token_storage.dart';
import '../screens/dashboard.dart';
import '../utils/app_constants.dart';
import '../utils/ui_utils.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with TickerProviderStateMixin {
  // ── Login controllers ──────────────────────────────────────────────────
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  // ── Forgot Password controllers ─────────────────────────────────────────
  final TextEditingController masterPasswordController = TextEditingController();
  final TextEditingController fpMobileController     = TextEditingController();
  final TextEditingController fpEmailController      = TextEditingController();
  final TextEditingController otpController          = TextEditingController();
  final TextEditingController newPasswordController  = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  final ApiService api     = ApiService();
  final TokenStorage storage = TokenStorage();

  // ── Animation controllers ───────────────────────────────────────────────
  late AnimationController _fadeController;
  late Animation<double>   _fadeAnimation;
  late AnimationController _flipController;
  late Animation<double>   _flipAnimation;

  // ── State ────────────────────────────────────────────────────────────────
  bool _showForgotPassword = false;   // which face of the card
  bool _isFlipping         = false;   // guard during animation
  bool _loginLoading       = false;
  bool _fpLoading          = false;
  bool _obscurePassword    = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _obscureMaster      = true;

  // Forgot-password step: 1, 2, 3 or 4 (success)
  int  _fpStep = 1;

  // Store mobile across FP steps
  String _fpVerifiedMobile = "";

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnimation = CurvedAnimation(
        parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();

    _flipController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _flipController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    mobileController.dispose();
    passwordController.dispose();
    masterPasswordController.dispose();
    fpMobileController.dispose();
    fpEmailController.dispose();
    otpController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    _fadeController.dispose();
    _flipController.dispose();
    super.dispose();
  }

  // ── Flip helpers ─────────────────────────────────────────────────────────
  void _flipToForgotPassword() async {
    if (_isFlipping) return;
    setState(() => _isFlipping = true);
    await _flipController.forward();
    setState(() {
      _showForgotPassword = true;
      _fpStep = 1;
      _isFlipping = false;
    });
  }

  void _flipToLogin() async {
    if (_isFlipping) return;
    setState(() => _isFlipping = true);
    await _flipController.reverse();
    setState(() {
      _showForgotPassword = false;
      _isFlipping = false;
      // Reset FP fields
      masterPasswordController.clear();
      fpMobileController.clear();
      fpEmailController.clear();
      otpController.clear();
      newPasswordController.clear();
      confirmPasswordController.clear();
    });
  }

  // ── Login ────────────────────────────────────────────────────────────────
  Future<void> handleLogin() async {
    if (mobileController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty) {
      UIUtils.showErrorToast("Please enter both Mobile Number and Password");
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _loginLoading = true);
    UIUtils.showProcessingSnackbar(context, message: "Verifying credentials...");
    try {
      final response = await api.login(
          mobileController.text.trim(), passwordController.text.trim());
      if (response.data != null) {
        final token = response.data["access_token"];
        final name  = response.data["name"];
        final role  = response.data["role"];
        if (token != null) {
          await storage.saveLoginData(
              token: token, name: name ?? "User", role: role ?? "Guest");
          UIUtils.showSuccessToast("Welcome back, $name!");
          if (mounted) {
            Navigator.pushAndRemoveUntil(context,
                MaterialPageRoute(builder: (_) => const Dashboard()),
                (route) => false);
          }
        } else {
          throw Exception("Login failed: No token received");
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loginLoading = false);
    }
  }

  // ── Forgot Password Steps ────────────────────────────────────────────────

  // STEP 1: Verify master password
  Future<void> _handleVerifyMaster() async {
    final mp = masterPasswordController.text.trim();
    if (mp.isEmpty) {
      UIUtils.showErrorToast("Please enter the master password");
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _fpLoading = true);
    try {
      await api.forgotPasswordVerifyMaster(mp);
      setState(() => _fpStep = 2);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _fpLoading = false);
    }
  }

  // STEP 2: Verify mobile + email, send OTP
  Future<void> _handleSendOtp() async {
    final mobile = fpMobileController.text.trim();
    final email  = fpEmailController.text.trim();
    if (mobile.isEmpty || email.isEmpty) {
      UIUtils.showErrorToast("Please enter both Mobile Number and Email");
      return;
    }
    if (mobile.length != 10) {
      UIUtils.showErrorToast("Enter a valid 10-digit mobile number");
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _fpLoading = true);
    UIUtils.showProcessingSnackbar(context, message: "Sending OTP...");
    try {
      await api.forgotPasswordSendOtp(mobile: mobile, email: email);
      _fpVerifiedMobile = mobile;
      UIUtils.showSuccessToast("OTP sent to your email");
      setState(() => _fpStep = 3);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _fpLoading = false);
    }
  }

  // STEP 3: Verify OTP + reset password
  Future<void> _handleResetPassword() async {
    final otp      = otpController.text.trim();
    final newPass  = newPasswordController.text.trim();
    final confPass = confirmPasswordController.text.trim();
    if (otp.isEmpty || newPass.isEmpty || confPass.isEmpty) {
      UIUtils.showErrorToast("Please fill all fields");
      return;
    }
    if (newPass != confPass) {
      UIUtils.showErrorToast("Passwords do not match");
      return;
    }
    if (newPass.length < 6) {
      UIUtils.showErrorToast("Password must be at least 6 characters");
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _fpLoading = true);
    UIUtils.showProcessingSnackbar(context, message: "Resetting password...");
    try {
      await api.forgotPasswordReset(
          mobile: _fpVerifiedMobile, otp: otp, newPassword: newPass);
      setState(() => _fpStep = 4); // success
    } catch (_) {
    } finally {
      if (mounted) setState(() => _fpLoading = false);
    }
  }

  // ── Shared input decoration ──────────────────────────────────────────────
  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textMuted),
      filled: true,
      fillColor: Colors.white.withOpacity(0.5),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
          borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      prefixIcon: Icon(icon, color: AppColors.textMuted),
      suffixIcon: suffixIcon,
    );
  }

  // ── Progress Indicator (3 steps) ─────────────────────────────────────────
  Widget _buildProgressIndicator() {
    final steps = ["Master\nPassword", "User\nVerification", "OTP &\nReset"];
    final successStep = _fpStep == 4;
    final activeStep  = successStep ? 3 : _fpStep;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final stepNum = (i ~/ 2) + 1;
          final done = activeStep > stepNum;
          return Expanded(
            child: Container(
              height: 2,
              color: done ? AppColors.primary : AppColors.borderColor,
            ),
          );
        }
        final stepIdx = i ~/ 2;
        final stepNum = stepIdx + 1;
        final isDone   = activeStep > stepNum || successStep;
        final isActive = activeStep == stepNum && !successStep;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isDone
                    ? AppColors.success
                    : isActive
                        ? AppColors.primary
                        : AppColors.borderColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isDone
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : Text("$stepNum",
                        style: TextStyle(
                            color: isActive ? Colors.white : AppColors.textMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 4),
            Text(steps[stepIdx],
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 9,
                    color: isActive ? AppColors.primary : AppColors.textMuted,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal)),
          ],
        );
      }),
    );
  }

  // ── Build step content ────────────────────────────────────────────────────
  Widget _buildFpStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Master Password", style: AppTypography.label),
        const SizedBox(height: 8),
        TextFormField(
          controller: masterPasswordController,
          obscureText: _obscureMaster,
          style: const TextStyle(color: AppColors.textDark),
          decoration: _inputDecoration(
            hint: "Enter master password",
            icon: Icons.admin_panel_settings_outlined,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureMaster ? Icons.visibility_off : Icons.visibility,
                color: AppColors.textMuted,
              ),
              onPressed: () =>
                  setState(() => _obscureMaster = !_obscureMaster),
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _fpLoading ? null : _handleVerifyMaster,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.borderRadius))),
            child: _fpLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text("VERIFY",
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildFpStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.info.withOpacity(0.1),
            borderRadius:
                BorderRadius.circular(AppDimensions.borderRadius),
            border: Border.all(color: AppColors.info.withOpacity(0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline,
                  color: AppColors.info, size: 16),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  "A verification code will be sent to the email address entered below. Please ensure you have access to this email account.",
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textDark),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text("Mobile Number", style: AppTypography.label),
        const SizedBox(height: 8),
        TextFormField(
          controller: fpMobileController,
          keyboardType: TextInputType.phone,
          style: const TextStyle(color: AppColors.textDark),
          decoration: _inputDecoration(
              hint: "10-digit mobile number",
              icon: Icons.phone_android),
        ),
        const SizedBox(height: 16),
        const Text("Email Address", style: AppTypography.label),
        const SizedBox(height: 8),
        TextFormField(
          controller: fpEmailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: AppColors.textDark),
          decoration: _inputDecoration(
              hint: "Registered email address",
              icon: Icons.email_outlined),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _fpLoading ? null : _handleSendOtp,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.borderRadius))),
            child: _fpLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text("SEND OTP",
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildFpStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("OTP Code", style: AppTypography.label),
        const SizedBox(height: 8),
        TextFormField(
          controller: otpController,
          keyboardType: TextInputType.number,
          style: const TextStyle(
              color: AppColors.textDark,
              letterSpacing: 4,
              fontSize: 18,
              fontWeight: FontWeight.bold),
          decoration: _inputDecoration(
              hint: "Enter 6-digit OTP", icon: Icons.lock_clock_outlined),
        ),
        const SizedBox(height: 16),
        const Text("New Password", style: AppTypography.label),
        const SizedBox(height: 8),
        TextFormField(
          controller: newPasswordController,
          obscureText: _obscureNewPassword,
          style: const TextStyle(color: AppColors.textDark),
          decoration: _inputDecoration(
            hint: "Enter new password",
            icon: Icons.lock_outline,
            suffixIcon: IconButton(
              icon: Icon(
                  _obscureNewPassword
                      ? Icons.visibility_off
                      : Icons.visibility,
                  color: AppColors.textMuted),
              onPressed: () => setState(
                  () => _obscureNewPassword = !_obscureNewPassword),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text("Confirm Password", style: AppTypography.label),
        const SizedBox(height: 8),
        TextFormField(
          controller: confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          style: const TextStyle(color: AppColors.textDark),
          decoration: _inputDecoration(
            hint: "Re-enter new password",
            icon: Icons.lock_outline,
            suffixIcon: IconButton(
              icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_off
                      : Icons.visibility,
                  color: AppColors.textMuted),
              onPressed: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _fpLoading ? null : _handleResetPassword,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.borderRadius))),
            child: _fpLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text("RESET PASSWORD",
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildFpSuccess() {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_outline,
              color: AppColors.success, size: 40),
        ),
        const SizedBox(height: 16),
        const Text("Password Changed!",
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textHeading)),
        const SizedBox(height: 8),
        const Text("Password changed successfully.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.textDark)),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _flipToLogin,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.borderRadius))),
            child: const Text("BACK TO LOGIN",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  // ── Build Login card content ──────────────────────────────────────────────
  Widget _buildLoginCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Mobile Number", style: AppTypography.label),
        const SizedBox(height: 8),
        TextFormField(
          controller: mobileController,
          keyboardType: TextInputType.phone,
          style: const TextStyle(color: AppColors.textDark),
          decoration: _inputDecoration(
              hint: "Enter your mobile number", icon: Icons.phone_android),
        ),
        const SizedBox(height: 20),
        const Text("Password", style: AppTypography.label),
        const SizedBox(height: 8),
        TextFormField(
          controller: passwordController,
          obscureText: _obscurePassword,
          style: const TextStyle(color: AppColors.textDark),
          decoration: _inputDecoration(
            hint: "············",
            icon: Icons.lock_outline,
            suffixIcon: IconButton(
              icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.textMuted),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _isFlipping ? null : _flipToForgotPassword,
            style:
                TextButton.styleFrom(padding: EdgeInsets.zero),
            child: const Text(
              "Forgot Password?",
              style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _loginLoading ? null : handleLogin,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shadowColor: AppColors.primary.withOpacity(0.4),
                elevation: 5,
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.borderRadius))),
            child: _loginLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text("LOGIN",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1)),
          ),
        ),
      ],
    );
  }

  // ── Build FP card content ─────────────────────────────────────────────────
  Widget _buildForgotPasswordCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row with back button
        Row(
          children: [
            GestureDetector(
              onTap: _isFlipping ? null : _flipToLogin,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.borderRadius)),
                child: const Icon(Icons.arrow_back_ios_new,
                    color: AppColors.primary, size: 16),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text("Forgot Password",
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textHeading)),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Progress indicator (steps 1-3, or success)
        if (_fpStep != 4) ...[
          _buildProgressIndicator(),
          const SizedBox(height: 24),
        ],

        // Step content
        if (_fpStep == 1) _buildFpStep1(),
        if (_fpStep == 2) _buildFpStep2(),
        if (_fpStep == 3) _buildFpStep3(),
        if (_fpStep == 4) _buildFpSuccess(),
      ],
    );
  }

  // ── Main build ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background blobs
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              height: 200,
              width: 200,
              decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.5),
                  shape: BoxShape.circle),
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
                  shape: BoxShape.circle),
            ),
          ),

          // Main content
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const Icon(Icons.inventory_2_outlined,
                        size: 60, color: AppColors.primary),
                    const SizedBox(height: 20),
                    const Text("Welcome to M-Store",
                        style: AppTypography.heading),
                    const SizedBox(height: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        _showForgotPassword
                            ? "Reset your account password"
                            : "Please sign-in to your account",
                        key: ValueKey(_showForgotPassword),
                        style: AppTypography.body,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // ── Flip Card ──────────────────────────────────────────
                    AnimatedBuilder(
                      animation: _flipAnimation,
                      builder: (context, child) {
                        // The flip: 0.0→0.5 shows front, 0.5→1.0 shows back
                        final angle = _flipAnimation.value * math.pi;
                        final showBack = angle > math.pi / 2;

                        return Transform(
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.001)
                            ..rotateY(showBack ? angle - math.pi : angle),
                          alignment: Alignment.center,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                                AppDimensions.borderRadius * 2),
                            child: BackdropFilter(
                              filter:
                                  ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                padding: const EdgeInsets.all(30),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(
                                      AppDimensions.borderRadius * 2),
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.8)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.secondary
                                          .withOpacity(0.1),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: showBack
                                    ? _buildForgotPasswordCard()
                                    : _buildLoginCard(),
                              ),
                            ),
                          ),
                        );
                      },
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
