import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Status Bar
import 'package:dio/dio.dart';
import 'dart:async'; // For UI delay

import '../api/api_service.dart';
import '../utils/app_constants.dart';
import '../utils/skeletal_loader.dart'; // ✅ Imported Skeleton

class CreateCustomerScreen extends StatefulWidget {
  const CreateCustomerScreen({super.key});

  @override
  State<CreateCustomerScreen> createState() => _CreateCustomerScreenState();
}

class _CreateCustomerScreenState extends State<CreateCustomerScreen> {
  // --- LOGIC (UNTOUCHED) ---
  final ApiService api = ApiService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController manualAreaController = TextEditingController();
  final TextEditingController dropdownDisplayController =
      TextEditingController();

  bool loading = false;
  bool _isOtherSelected = false;

  // UI State for Skeleton
  bool _isInitLoading = true;

  final List<String> areaOptions = [
    "Kadodara",
    "Chalthan",
    "Vareli",
    "Jolva",
    "Palsana",
    "Haldharu",
    "Tantithaiya",
    "Other",
  ];

  @override
  void initState() {
    super.initState();
    // Simulate a quick UI prep to show off the skeleton effect
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _isInitLoading = false);
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    mobileController.dispose();
    manualAreaController.dispose();
    dropdownDisplayController.dispose();
    super.dispose();
  }

  Future<void> createCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => loading = true);

    try {
      String finalArea = _isOtherSelected
          ? manualAreaController.text.trim()
          : dropdownDisplayController.text.trim();

      final response = await api.createCustomer(
        name: nameController.text.trim(),
        mobile: mobileController.text.trim(),
        area: finalArea,
      );

      if (!mounted) return;
      _showSuccessDialog(
        response.data["message"] ?? "New customer added successfully.",
      );
      _resetForm();
    } catch (e) {
      String msg = "Failed to create customer";
      if (e is DioException) {
        msg = e.response?.data["detail"]?.toString() ?? msg;
      }
      showCustomSnackBar(msg, isError: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _resetForm() {
    nameController.clear();
    mobileController.clear();
    manualAreaController.clear();
    dropdownDisplayController.clear();
    setState(() {
      _isOtherSelected = false;
    });
  }

  void _openAreaDrawer() {
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.only(bottom: 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 16.0),
                child: Text(
                  "Select Area / Location",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF566a7f),
                  ),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: areaOptions.length,
                  itemBuilder: (context, index) {
                    final item = areaOptions[index];
                    final isSelected = dropdownDisplayController.text == item;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 0,
                      ),
                      leading: Icon(
                        Icons.location_on_outlined,
                        color: isSelected ? AppColors.primary : Colors.grey,
                      ),
                      title: Text(
                        item,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? AppColors.primary
                              : const Color(0xFF566a7f),
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(
                              Icons.check_circle,
                              color: AppColors.primary,
                            )
                          : null,
                      onTap: () {
                        setState(() {
                          dropdownDisplayController.text = item;
                          _isOtherSelected = (item == "Other");
                          if (!_isOtherSelected) manualAreaController.clear();
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
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

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                  Icons.person_add_alt_1_rounded,
                  color: AppColors.success,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Customer Created!",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF566a7f),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
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
                  onPressed: () => Navigator.pop(context),
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
  }

  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double topOffset = size.height * 0.08;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F9), // Sneat Background
      extendBodyBehindAppBar: true,

      // ✅ SNEAT APP BAR
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F9).withOpacity(0.9),
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
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
          "New Customer",
          style: TextStyle(
            color: Color(0xFF566a7f),
            fontWeight: FontWeight.bold,
            fontSize: 20,
            fontFamily: 'PublicSans',
          ),
        ),
      ),

      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: topOffset + kToolbarHeight),

            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _isInitLoading
                      ? _buildSkeletonForm() // ✅ SKELETON
                      : _buildActualForm(), // ✅ ACTUAL FORM
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Actual Form Widget
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
            Icons.person_add_alt_1_rounded,
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
                _buildLabel("Customer Details"),
                const SizedBox(height: 16),

                TextFormField(
                  controller: nameController,
                  decoration: _inputDecoration(
                    "Customer Name",
                    Icons.person_outline,
                  ),
                  validator: (value) => (value == null || value.isEmpty)
                      ? "Name is required"
                      : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: mobileController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  decoration: _inputDecoration(
                    "Mobile Number",
                    Icons.phone_android_rounded,
                    counterText: "",
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Mobile is required";
                    }
                    if (value.length != 10) {
                      return "Enter valid 10-digit mobile";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                GestureDetector(
                  onTap: _openAreaDrawer,
                  child: AbsorbPointer(
                    child: TextFormField(
                      controller: dropdownDisplayController,
                      decoration: _inputDecoration(
                        "Select Area",
                        Icons.location_on_outlined,
                        suffixIcon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      validator: (value) => (value == null || value.isEmpty)
                          ? "Please select an area"
                          : null,
                    ),
                  ),
                ),

                if (_isOtherSelected) ...[
                  const SizedBox(height: 16),
                  AnimatedOpacity(
                    opacity: _isOtherSelected ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: TextFormField(
                      controller: manualAreaController,
                      decoration: _inputDecoration(
                        "Enter Manual Location",
                        Icons.edit_location_alt_outlined,
                      ),
                      validator: (value) {
                        if (_isOtherSelected &&
                            (value == null || value.isEmpty)) {
                          return "Please enter the location";
                        }
                        return null;
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: loading ? null : createCustomer,
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
                            "CREATE CUSTOMER",
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

  // ✅ Skeleton Loader
  Widget _buildSkeletonForm() {
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
              SkeletalLoader(width: 120, height: 14),
              SizedBox(height: 20),
              SkeletalLoader(width: double.infinity, height: 55),
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

  // --- UI HELPER METHODS ---

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

  InputDecoration _inputDecoration(
    String label,
    IconData icon, {
    String? counterText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey[600]),
      prefixIcon: Icon(
        icon,
        color: AppColors.primary.withOpacity(0.7),
        size: 22,
      ),
      suffixIcon: suffixIcon,
      counterText: counterText,
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
