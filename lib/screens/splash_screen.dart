import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ For Status Bar Control
import 'dart:async'; // For timer
import '../storage/token_storage.dart';
import '../auth/login_page.dart';
import 'dashboard.dart';
import '../utils/app_constants.dart';
import '../utils/ui_utils.dart'; // ✅ Using UIUtils
import '../utils/skeletal_loader.dart'; // ✅ Using Skeleton Loader

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  final TokenStorage storage = TokenStorage();
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // 1. Initialize Animation
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    // Start Animation
    _controller.forward();

    // 2. Trigger Logic
    _initializeApp();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    // Add a minimum delay so the animation can play (UI Polish)
    final minDelay = Future.delayed(const Duration(milliseconds: 2000));

    // Check Session Logic
    final sessionCheck = _checkSession();

    // Wait for both to finish
    await Future.wait([minDelay, sessionCheck]);
  }

  Future<void> _checkSession() async {
    try {
      final isValid = await storage.isTokenValid();
      if (!mounted) return;

      if (isValid) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, _, _) => const Dashboard(),
            transitionsBuilder: (_, a, _, c) =>
                FadeTransition(opacity: a, child: c),
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      } else {
        await storage.clearAll(); // Safety clear
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, _, _) => const LoginPage(),
            transitionsBuilder: (_, a, _, c) =>
                FadeTransition(opacity: a, child: c),
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    } catch (e) {
      // ✅ Using UIUtils for fallback error
      UIUtils.showErrorToast("Session check failed. Redirecting to login.");

      // Fallback in case of error
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F9), // Sneat Background
      extendBodyBehindAppBar: true, // ✅ Content behind AppBar
      // ✅ 1. PRODUCTIVE SNEAT APP BAR (Minimal for Splash)
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // ✅ Status Bar Visibility: Dark Icons for Light Background
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        // No title/actions needed for splash, but AppBar is here for SystemUI control
      ),

      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated Logo
            ScaleTransition(
              scale: _scaleAnimation,
              child: FadeTransition(
                opacity: _opacityAnimation,
                child: Container(
                  height: 100,
                  width: 100,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.space_dashboard_rounded,
                      size: 50,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Animated App Name
            FadeTransition(
              opacity: _opacityAnimation,
              child: const Column(
                children: [
                  Text(
                    "M-Store",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF566a7f),
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Inventory Management",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 60),

            // ✅ 2. SKELETON LOADER (Replaces CircularProgressIndicator)
            // A subtle pulse bar to indicate loading
            const SizedBox(
              width: 120,
              height: 6,
              child: SkeletalLoader(width: 120, height: 6, borderRadius: 3),
            ),
          ],
        ),
      ),

      // Footer Version Text
      bottomNavigationBar: const Padding(
        padding: EdgeInsets.all(20.0),
        child: Text(
          "v1.0.0",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ),
    );
  }
}
