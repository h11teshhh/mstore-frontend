import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  // ── Controllers ─────────────────────────────────────────────────────────
  final _mobileCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _masterCtrl = TextEditingController();
  final _fpMobileCtrl = TextEditingController();
  final _fpEmailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confPassCtrl = TextEditingController();

  final _api = ApiService();
  final _storage = TokenStorage();

  // ── Animations ──────────────────────────────────────────────────────────
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  late AnimationController _flipCtrl;
  late Animation<double> _flipAnim;

  // ── State ────────────────────────────────────────────────────────────────
  bool _showFP = false;
  bool _isFlipping = false;
  bool _loginLoading = false;
  bool _fpLoading = false;
  bool _obscurePass = true;
  bool _obscureMaster = true;
  bool _obscureNew = true;
  bool _obscureConf = true;
  int _fpStep = 1; // 1=master, 2=user id, 3=OTP+reset, 4=success
  String _fpMobile = "";

  // Form keys for inline validation — one per card face
  final _loginFormKey = GlobalKey<FormState>();
  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();
  final _step3FormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    _flipCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _flipAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _flipCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    for (final c in [
      _mobileCtrl,
      _passCtrl,
      _masterCtrl,
      _fpMobileCtrl,
      _fpEmailCtrl,
      _otpCtrl,
      _newPassCtrl,
      _confPassCtrl,
    ])
      c.dispose();
    _fadeCtrl.dispose();
    _flipCtrl.dispose();
    super.dispose();
  }

  // ── Flip ─────────────────────────────────────────────────────────────────
  Future<void> _flipToFP() async {
    if (_isFlipping) return;
    _isFlipping = true;
    await _flipCtrl.forward();
    if (mounted)
      setState(() {
        _showFP = true;
        _fpStep = 1;
        _isFlipping = false;
      });
  }

  Future<void> _flipToLogin() async {
    if (_isFlipping) return;
    _isFlipping = true;
    await _flipCtrl.reverse();
    if (mounted)
      setState(() {
        _showFP = false;
        _isFlipping = false;
        _fpStep = 1;
        for (final c in [
          _masterCtrl,
          _fpMobileCtrl,
          _fpEmailCtrl,
          _otpCtrl,
          _newPassCtrl,
          _confPassCtrl,
        ])
          c.clear();
      });
  }

  // ── LOGIN ────────────────────────────────────────────────────────────────
  Future<void> _handleLogin() async {
    // Validate form fields inline before calling API
    if (!(_loginFormKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _loginLoading = true);
    UIUtils.showProcessingSnackbar(context, message: "Logging in...");
    try {
      final res = await _api.login(
        _mobileCtrl.text.trim(),
        _passCtrl.text.trim(),
      );
      if (!mounted) return;
      AppToast.dismiss(); // dismiss loading toast
      if (res.data != null) {
        final token = res.data["access_token"];
        if (token != null) {
          await _storage.saveLoginData(
            token: token,
            name: res.data["name"] ?? "User",
            role: res.data["role"] ?? "Guest",
          );
          UIUtils.showSnackBar(
            context,
            "Welcome, ${res.data["name"] ?? "User"}!",
          );
          if (mounted)
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const Dashboard()),
              (_) => false,
            );
        }
      }
    } catch (e) {
      if (!mounted) return;
      AppToast.dismiss(); // dismiss loading toast
      String msg = "Invalid mobile number or password";
      try {
        final dynamic err = (e as dynamic).response?.data;
        if (err is Map && err["detail"] != null) msg = err["detail"].toString();
      } catch (_) {}
      UIUtils.showSnackBar(context, msg, isError: true);
    } finally {
      if (mounted) setState(() => _loginLoading = false);
    }
  }

  // ── FP STEP 1 — Master password ──────────────────────────────────────────
  Future<void> _handleMaster() async {
    if (!(_step1FormKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _fpLoading = true);
    try {
      await _api.forgotPasswordVerifyMaster(mp);
      if (mounted) setState(() => _fpStep = 2);
    } catch (e) {
      if (!mounted) return;
      String msg = "Invalid password";
      try {
        final dynamic err = (e as dynamic).response?.data;
        if (err is Map && err["detail"] != null) msg = err["detail"].toString();
      } catch (_) {}
      UIUtils.showSnackBar(context, msg, isError: true);
    } finally {
      if (mounted) setState(() => _fpLoading = false);
    }
  }

  // ── FP STEP 2 — Validate + send OTP ─────────────────────────────────────
  Future<void> _handleSendOtp() async {
    if (!(_step2FormKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _fpLoading = true);
    UIUtils.showProcessingSnackbar(
      context,
      message: "Sending verification code…",
    );
    try {
      await _api.forgotPasswordSendOtp(mobile: mobile, email: email);
      if (!mounted) return;
      AppToast.dismiss(); // dismiss loading toast
      _fpMobile = mobile;
      UIUtils.showSnackBar(context, "Code sent! Check your inbox.");
      if (mounted) setState(() => _fpStep = 3);
    } catch (e) {
      if (!mounted) return;
      AppToast.dismiss(); // dismiss loading toast
      String msg = "Couldn't send verification code. Please try again.";
      try {
        final dynamic err = (e as dynamic).response?.data;
        if (err is Map && err["detail"] != null) {
          final String detail = err["detail"].toString().toLowerCase();
          // Map internal error codes/keywords to friendly messages
          if (detail.contains("mobile number not found")) {
            msg = "Mobile number not registered. Please check and try again.";
          } else if (detail.contains("contact support") ||
              detail.contains("misconfigured") ||
              detail.contains("not verified") ||
              detail.contains("authentication failed")) {
            msg = "Unable to send code right now. Please contact support.";
          } else if (detail.contains("try again")) {
            msg = "Couldn't send verification code. Please try again in a few minutes.";
          } else if (detail.contains("invalid") || detail.contains("not found")) {
            msg = err["detail"].toString(); // safe to show these
          }
          // All other internal errors stay as the generic friendly message
        }
      } catch (_) {}
      UIUtils.showSnackBar(context, msg, isError: true);
    } finally {
      if (mounted) setState(() => _fpLoading = false);
    }
  }

  // ── FP STEP 3 — Verify OTP + reset ──────────────────────────────────────
  Future<void> _handleReset() async {
    if (!(_step3FormKey.currentState?.validate() ?? false)) return;
    final newPass = _newPassCtrl.text.trim();
    final confPass = _confPassCtrl.text.trim();
    // Cross-field password match check after form passes
    if (newPass != confPass) {
      UIUtils.showSnackBar(context, "Passwords do not match", isError: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _fpLoading = true);
    UIUtils.showProcessingSnackbar(context, message: "Resetting password...");
    try {
      await _api.forgotPasswordReset(
        mobile: _fpMobile,
        otp: otp,
        newPassword: newPass,
      );
      if (!mounted) return;
      AppToast.dismiss(); // dismiss loading toast
      if (mounted) setState(() => _fpStep = 4);
    } catch (e) {
      if (!mounted) return;
      AppToast.dismiss(); // dismiss loading toast
      String msg = "Invalid or expired verification code";
      try {
        final dynamic err = (e as dynamic).response?.data;
        if (err is Map && err["detail"] != null) msg = err["detail"].toString();
      } catch (_) {}
      UIUtils.showSnackBar(context, msg, isError: true);
    } finally {
      if (mounted) setState(() => _fpLoading = false);
    }
  }

  // ── Input Decoration ─────────────────────────────────────────────────────
  InputDecoration _dec({
    required String hint,
    required IconData icon,
    Widget? suffix,
    String? errorText,
  }) => InputDecoration(
    hintText: hint,
    hintStyle: AppTypography.caption.copyWith(color: AppColors.textMuted),
    errorText: errorText,
    errorStyle: const TextStyle(fontSize: 11),
    filled: true,
    fillColor: AppColors.background,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
      borderSide: const BorderSide(color: AppColors.danger, width: 1),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
      borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
    ),
    prefixIcon: Icon(icon, color: AppColors.textMuted, size: 20),
    suffixIcon: suffix,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );

  Widget _primaryBtn(String label, VoidCallback? onTap) => SizedBox(
    width: double.infinity,
    height: 48,
    child: ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        shadowColor: AppColors.primary.withOpacity(0.35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
        ),
      ),
      child: _fpLoading || _loginLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : Text(label, style: AppTypography.button),
    ),
  );

  // ── Progress bar ─────────────────────────────────────────────────────────
  Widget _progress() {
    const labels = ["Enter\nKey", "Verify\nUser", "Reset\nPassword"];
    final active = _fpStep == 4 ? 3 : _fpStep;
    return Row(
      children: List.generate(labels.length * 2 - 1, (i) {
        if (i.isOdd) {
          final done = active > (i ~/ 2) + 1;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 2,
              color: done ? AppColors.primary : AppColors.borderColor,
            ),
          );
        }
        final n = i ~/ 2 + 1;
        final done = active > n || _fpStep == 4;
        final current = active == n && _fpStep != 4;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done
                    ? AppColors.primary
                    : current
                    ? AppColors.primary
                    : AppColors.borderColor,
              ),
              child: Center(
                child: done
                    ? const Icon(Icons.check, color: Colors.white, size: 14)
                    : Text(
                        "$n",
                        style: TextStyle(
                          color: current ? Colors.white : AppColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              labels[n - 1],
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                fontWeight: current ? FontWeight.w700 : FontWeight.w400,
                color: current ? AppColors.primary : AppColors.textMuted,
              ),
            ),
          ],
        );
      }),
    );
  }

  // ── FP Step widgets ───────────────────────────────────────────────────────
  Widget _step1() => Form(
    key: _step1FormKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Admin Key", style: AppTypography.label),
        const SizedBox(height: 6),
        TextFormField(
          controller: _masterCtrl,
          obscureText: _obscureMaster,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: _dec(
            hint: "Enter password",
            icon: Icons.admin_panel_settings_outlined,
            suffix: _visBtn(
              _obscureMaster,
              () => setState(() => _obscureMaster = !_obscureMaster),
            ),
          ),
          validator: (val) {
            if (val == null || val.trim().isEmpty) return "Admin key is required";
            return null;
          },
        ),
        const SizedBox(height: 20),
        _primaryBtn("VERIFY & CONTINUE", _fpLoading ? null : _handleMaster),
      ],
    ),
  );

  Widget _step2() => Form(
    key: _step2FormKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.infoLight,
            borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
            border: Border.all(color: AppColors.info.withOpacity(0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, color: AppColors.info, size: 15),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  "A one-time code will be sent to the email you enter below.",
                  style: TextStyle(fontSize: 11, color: AppColors.textDark),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text("Mobile Number", style: AppTypography.label),
        const SizedBox(height: 6),
        TextFormField(
          controller: _fpMobileCtrl,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: _dec(
            hint: "10-digit mobile number",
            icon: Icons.phone_android,
          ).copyWith(counterText: ""),
          validator: (val) {
            final v = val?.trim() ?? "";
            if (v.isEmpty) return "Mobile number is required";
            if (!RegExp(r'^\d{10}\$').hasMatch(v)) return "Enter a valid 10-digit number";
            return null;
          },
        ),
        const SizedBox(height: 12),
        const Text("Email Address", style: AppTypography.label),
        const SizedBox(height: 6),
        TextFormField(
          controller: _fpEmailCtrl,
          keyboardType: TextInputType.emailAddress,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: _dec(
            hint: "Email to receive OTP",
            icon: Icons.email_outlined,
          ),
          validator: (val) {
            final v = val?.trim() ?? "";
            if (v.isEmpty) return "Email is required";
            if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+\$').hasMatch(v)) {
              return "Enter a valid email address";
            }
            return null;
          },
        ),
        const SizedBox(height: 20),
        _primaryBtn("SEND CODE", _fpLoading ? null : _handleSendOtp),
      ],
    ),
  );

  Widget _step3() => Form(
    key: _step3FormKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Verification Code", style: AppTypography.label),
        const SizedBox(height: 6),
        TextFormField(
          controller: _otpCtrl,
          keyboardType: TextInputType.number,
          maxLength: 6,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: const TextStyle(
            letterSpacing: 6,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          decoration: _dec(
            hint: "••••••",
            icon: Icons.lock_clock_outlined,
          ).copyWith(counterText: ""),
          validator: (val) {
            final v = val?.trim() ?? "";
            if (v.isEmpty) return "Verification code is required";
            if (v.length < 4) return "Code is too short";
            return null;
          },
        ),
        const SizedBox(height: 12),
        const Text("New Password", style: AppTypography.label),
        const SizedBox(height: 6),
        TextFormField(
          controller: _newPassCtrl,
          obscureText: _obscureNew,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: _dec(
            hint: "Min. 6 characters",
            icon: Icons.lock_outline,
            suffix: _visBtn(
              _obscureNew,
              () => setState(() => _obscureNew = !_obscureNew),
            ),
          ),
          validator: (val) {
            final v = val?.trim() ?? "";
            if (v.isEmpty) return "New password is required";
            if (v.length < 6) return "Password must be at least 6 characters";
            return null;
          },
        ),
        const SizedBox(height: 12),
        const Text("Confirm Password", style: AppTypography.label),
        const SizedBox(height: 6),
        TextFormField(
          controller: _confPassCtrl,
          obscureText: _obscureConf,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: _dec(
            hint: "Re-enter password",
            icon: Icons.lock_outline,
            suffix: _visBtn(
              _obscureConf,
              () => setState(() => _obscureConf = !_obscureConf),
            ),
          ),
          validator: (val) {
            final v = val?.trim() ?? "";
            if (v.isEmpty) return "Please confirm your password";
            return null;
          },
        ),
        const SizedBox(height: 20),
        _primaryBtn("RESET PASSWORD", _fpLoading ? null : _handleReset),
      ],
    ),
  );

  Widget _step4() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.successLight,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.check_circle_outline,
          color: AppColors.success,
          size: 36,
        ),
      ),
      const SizedBox(height: 14),
      const Text("Password Changed", style: AppTypography.subheading),
      const SizedBox(height: 6),
      Text(
        "Your password was updated successfully.",
        textAlign: TextAlign.center,
        style: AppTypography.body.copyWith(color: AppColors.textMuted),
      ),
      const SizedBox(height: 24),
      _primaryBtn("BACK TO LOGIN", _flipToLogin),
    ],
  );

  Widget _visBtn(bool obscure, VoidCallback onTap) => IconButton(
    icon: Icon(
      obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
      color: AppColors.textMuted,
      size: 20,
    ),
    onPressed: onTap,
  );

  // ── Login card ─────────────────────────────────────────────────────────
  Widget _loginCard() => Form(
    key: _loginFormKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Mobile Number", style: AppTypography.label),
        const SizedBox(height: 6),
        TextFormField(
          controller: _mobileCtrl,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: _dec(
            hint: "Enter 10-digit mobile number",
            icon: Icons.phone_android_outlined,
          ).copyWith(counterText: ""),
          validator: (val) {
            final v = val?.trim() ?? "";
            if (v.isEmpty) return "Mobile number is required";
            if (!RegExp(r'^\d{10}$').hasMatch(v)) {
              return "Enter a valid 10-digit mobile number";
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        const Text("Password", style: AppTypography.label),
        const SizedBox(height: 6),
        TextFormField(
          controller: _passCtrl,
          obscureText: _obscurePass,
          onFieldSubmitted: (_) => _handleLogin(),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: _dec(
            hint: "Enter password",
            icon: Icons.lock_outline,
            suffix: _visBtn(
              _obscurePass,
              () => setState(() => _obscurePass = !_obscurePass),
            ),
          ),
          validator: (val) {
            final v = val?.trim() ?? "";
            if (v.isEmpty) return "Password is required";
            if (v.length < 4) return "Password is too short";
            return null;
          },
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _isFlipping ? null : _flipToFP,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              "Forgot Password?",
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _primaryBtn("LOGIN", _loginLoading ? null : _handleLogin),
      ],
    ),
  );

  // ── FP card ────────────────────────────────────────────────────────────
  Widget _fpCard() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          GestureDetector(
            onTap: _isFlipping ? null : _flipToLogin,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: AppColors.primary,
                size: 14,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              "Forgot Password",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textHeading,
              ),
            ),
          ),
        ],
      ),
      if (_fpStep != 4) ...[
        const SizedBox(height: 18),
        _progress(),
        const SizedBox(height: 20),
      ],
      if (_fpStep == 1) _step1(),
      if (_fpStep == 2) _step2(),
      if (_fpStep == 3) _step3(),
      if (_fpStep == 4) _step4(),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final cardW = w > 500 ? 460.0 : double.infinity;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Subtle background circles
          Positioned(
            top: -80,
            left: -60,
            child: _circle(220, AppColors.primary.withOpacity(0.07)),
          ),
          Positioned(
            bottom: -80,
            right: -60,
            child: _circle(220, AppColors.info.withOpacity(0.07)),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: Column(
                    children: [
                      // Logo
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.inventory_2_outlined,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text("M-Store", style: AppTypography.heading),
                      const SizedBox(height: 4),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Text(
                          _showFP
                              ? "Reset your password"
                              : "Business management platform",
                          key: ValueKey(_showFP),
                          style: AppTypography.body.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Flip card
                      SizedBox(
                        width: cardW,
                        child: AnimatedBuilder(
                          animation: _flipAnim,
                          builder: (ctx, _) {
                            final angle = _flipAnim.value * math.pi;
                            final back = angle > math.pi / 2;
                            final rotate = back ? angle - math.pi : angle;
                            return Transform(
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, 0.001)
                                ..rotateY(rotate),
                              alignment: Alignment.center,
                              child: _cardSurface(
                                back ? _fpCard() : _loginCard(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardSurface(Widget child) => ClipRRect(
    borderRadius: BorderRadius.circular(AppDimensions.borderRadiusXL),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusXL),
          border: Border.all(color: Colors.white.withOpacity(0.6)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.08),
              blurRadius: 24,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: child,
      ),
    ),
  );

  Widget _circle(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
