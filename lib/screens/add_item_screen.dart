import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Status Bar Control
import 'package:dio/dio.dart';
import 'dart:async'; // For UI delay

import '../api/api_service.dart';
import '../utils/app_constants.dart';
import '../utils/skeletal_loader.dart'; // ✅ Imported Skeleton

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  // --- LOGIC (UNTOUCHED) ---
  final ApiService api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController itemController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  bool loading = false;

  // UI State for Skeleton
  bool _isInitLoading = true;

  @override
  void initState() {
    super.initState();
    // Simulate a quick UI prep to show off the skeleton effect
    Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _isInitLoading = false);
    });
  }

  @override
  void dispose() {
    itemController.dispose();
    priceController.dispose();
    super.dispose();
  }

  Future<void> addItem() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => loading = true);

    try {
      final response = await api.addInventoryItem(
        itemController.text.trim(),
        double.parse(priceController.text.trim()),
      );

      if (!mounted) return;

      // ✅ Pro Success Dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.success,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Success!",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF566a7f),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  response.data["message"] ?? "Item added successfully",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context); // Close dialog
                      _resetForm();
                    },
                    child: const Text(
                      "Continue",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      String msg = "Unexpected error occurred";
      if (e is DioException) {
        msg = e.response?.data.toString() ?? "Failed to add item";
      }
      showCustomSnackBar(msg, isError: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _resetForm() {
    itemController.clear();
    priceController.clear();
    setState(() {});
  }

  void showCustomSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? AppColors.danger : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double topOffset = size.height * 0.15;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F9), // Sneat Background
      extendBodyBehindAppBar: true, // Allows content to flow behind if needed
      appBar: AppBar(
        backgroundColor: const Color(
          0xFFF5F5F9,
        ).withOpacity(0.9), // Glassy effect
        elevation: 0,
        centerTitle: true,
        // ✅ Status Bar Control: Ensures icons are dark and readable
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light, // For iOS
        ),
        leading: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: AppColors.textHeading,
              ),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: const Text(
          "New Inventory Item",
          style: TextStyle(
            color: Color(0xFF566a7f),
            fontWeight: FontWeight.bold,
            fontSize: 20,
            fontFamily: 'PublicSans',
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: IconButton(
              icon: const Icon(
                Icons.info_outline_rounded,
                color: AppColors.textMuted,
              ),
              onPressed: () {
                // Info action
              },
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              height: topOffset + kToolbarHeight,
            ), // Offset + AppBar height

            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _isInitLoading
                      ? _buildSkeletonLoader() // ✅ Visual Skeleton State
                      : _buildActualForm(), // ✅ Actual Form
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ The Real Form (Extracted for cleanliness)
  Widget _buildActualForm() {
    return Column(
      children: [
        // Header Icon
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.add_shopping_cart_rounded,
            size: 40,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 24),

        // The Form Card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel("Item Details"),
                const SizedBox(height: 16),

                // Item Name Input
                TextFormField(
                  controller: itemController,
                  decoration: _inputDecoration(
                    "Item Name",
                    Icons.inventory_2_outlined,
                  ),
                  validator: (value) => (value == null || value.isEmpty)
                      ? "Item name is required"
                      : null,
                ),
                const SizedBox(height: 20),

                // Price Input
                TextFormField(
                  controller: priceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _inputDecoration(
                    "Price (₹)",
                    Icons.currency_rupee_rounded,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Price is required";
                    }
                    if (double.tryParse(value) == null) {
                      return "Enter valid number";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 30),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: loading ? null : addItem,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: AppColors.primary.withOpacity(
                        0.6,
                      ),
                      elevation: 4,
                      shadowColor: AppColors.primary.withOpacity(0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: loading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            "ADD TO INVENTORY",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 50),
      ],
    );
  }

  // ✅ Skeleton Loader Implementation
  Widget _buildSkeletonLoader() {
    return Column(
      children: [
        const SkeletalLoader(width: 70, height: 70, borderRadius: 35),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              SkeletalLoader(width: 100, height: 14),
              SizedBox(height: 20),
              SkeletalLoader(width: double.infinity, height: 55),
              SizedBox(height: 20),
              SkeletalLoader(width: double.infinity, height: 55),
              SizedBox(height: 30),
              SkeletalLoader(width: double.infinity, height: 50),
            ],
          ),
        ),
      ],
    );
  }

  // --- UI HELPERS ---

  Widget _buildLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Colors.grey[500],
        letterSpacing: 1.0,
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey[600]),
      prefixIcon: Icon(
        icon,
        color: AppColors.primary.withOpacity(0.7),
        size: 22,
      ),
      filled: true,
      fillColor: const Color(0xFFF5F5F9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    );
  }
}
