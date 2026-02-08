import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../api/api_service.dart';
import '../storage/token_storage.dart';
import '../utils/app_constants.dart'; // Ensure standard colors are here

class CreateUserScreen extends StatefulWidget {
  const CreateUserScreen({super.key});

  @override
  State<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends State<CreateUserScreen> {
  // --- LOGIC ---
  final ApiService api = ApiService();
  final TokenStorage storage = TokenStorage();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController addressController = TextEditingController();

  // Controller for Role (Text is updated when drawer selection is made)
  final TextEditingController roleController = TextEditingController(
    text: "ADMIN",
  );

  String selectedRole = "ADMIN";
  bool loading = false;
  bool _obscurePassword = true;

  // The 4 Specific Roles
  final List<String> roles = ["SUPERADMIN", "ADMIN", "DELIVERY", "CUSTOMER"];

  @override
  void dispose() {
    nameController.dispose();
    mobileController.dispose();
    passwordController.dispose();
    addressController.dispose();
    roleController.dispose();
    super.dispose();
  }

  Future<void> createUser() async {
    if (!_formKey.currentState!.validate()) return;

    // Hide Keyboard & Show Loading
    FocusScope.of(context).unfocus();
    setState(() => loading = true);

    try {
      final data = {
        "name": nameController.text.trim(),
        "mobile": mobileController.text.trim(),
        "password": passwordController.text.trim(),
        "role": selectedRole.toUpperCase(),
        "address": addressController.text.trim(),
      };

      final response = await api.createUser(data);

      if (!mounted) return;
      _showSuccessDialog(
        response.data["message"] ?? "User created successfully",
      );
      _resetForm();
    } catch (e) {
      String msg = "Failed to create user";
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
    passwordController.clear();
    addressController.clear();
    setState(() {
      selectedRole = "ADMIN";
      roleController.text = "ADMIN";
    });
  }

  // --- DRAWER (MODAL SHEET) FOR ROLES ---
  void _openRoleDrawer() {
    // Dismiss keyboard if open
    FocusScope.of(context).unfocus();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true, // Allows sheet to be taller if needed
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
              // Handle Bar
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
                padding: EdgeInsets.only(bottom: 20.0),
                child: Text(
                  "Assign Role",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF566a7f),
                  ),
                ),
              ),
              // Role List
              ...roles.map((role) {
                final isSelected = selectedRole == role;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 4,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withOpacity(0.1)
                          : Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getRoleIcon(role),
                      color: isSelected ? AppColors.primary : Colors.grey,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    role,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.primary
                          : const Color(0xFF566a7f),
                      fontSize: 16,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primary,
                        )
                      : const Icon(Icons.circle_outlined, color: Colors.grey),
                  onTap: () {
                    setState(() {
                      selectedRole = role;
                      roleController.text = role;
                    });
                    Navigator.pop(context);
                  },
                );
              }),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case "SUPERADMIN":
        return Icons.shield_rounded;
      case "ADMIN":
        return Icons.admin_panel_settings_rounded;
      case "DELIVERY":
        return Icons.local_shipping_rounded;
      case "CUSTOMER":
        return Icons.person_rounded;
      default:
        return Icons.account_circle_rounded;
    }
  }

  // --- UI HELPERS ---
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
                  Icons.check_rounded,
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

  // --- MAIN BUILD ---
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // POSITIONING LOGIC:
    // To be "20-25% above upside of the center", the top margin needs to be small.
    // Center is 0.5. Upside of center is < 0.5.
    // We use 0.08 (8%) top margin. This pulls the whole container very high up.
    final double topOffset = size.height * 0.08;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F9), // Sneat Background
      appBar: AppBar(
        title: const Text(
          "Create User",
          style: TextStyle(
            color: Color(0xFF566a7f),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF566a7f)),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              height: topOffset,
            ), // Responsive Top Spacer (Very small to keep it high)

            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
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
                              _buildLabel("Account Details"),
                              const SizedBox(height: 16),

                              // Name
                              TextFormField(
                                controller: nameController,
                                decoration: _inputDecoration(
                                  "Full Name",
                                  Icons.person_outline,
                                ),
                                validator: (val) => (val == null || val.isEmpty)
                                    ? "Name is required"
                                    : null,
                              ),
                              const SizedBox(height: 16),

                              // Mobile
                              TextFormField(
                                controller: mobileController,
                                keyboardType: TextInputType.phone,
                                maxLength: 10,
                                decoration: _inputDecoration(
                                  "Mobile Number",
                                  Icons.phone_android_rounded,
                                  counterText: "",
                                ),
                                validator: (val) {
                                  if (val == null || val.isEmpty) {
                                    return "Mobile is required";
                                  }
                                  if (val.length != 10) {
                                    return "Enter valid 10-digit number";
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // ROLE SELECTOR (Trigger for Drawer)
                              GestureDetector(
                                onTap: _openRoleDrawer,
                                child: AbsorbPointer(
                                  child: TextFormField(
                                    controller: roleController,
                                    readOnly: true,
                                    decoration: _inputDecoration(
                                      "Role",
                                      _getRoleIcon(selectedRole),
                                      suffixIcon: const Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Password
                              TextFormField(
                                controller: passwordController,
                                obscureText: _obscurePassword,
                                decoration: _inputDecoration(
                                  "Password",
                                  Icons.lock_outline,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: Colors.grey,
                                      size: 20,
                                    ),
                                    onPressed: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                  ),
                                ),
                                validator: (val) =>
                                    (val == null || val.length < 6)
                                    ? "Min 6 chars required"
                                    : null,
                              ),
                              const SizedBox(height: 16),

                              // Address
                              TextFormField(
                                controller: addressController,
                                decoration: _inputDecoration(
                                  "Address",
                                  Icons.home_outlined,
                                ),
                                maxLines: 2,
                              ),

                              const SizedBox(height: 24),

                              // Submit Button
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: loading ? null : createUser,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    disabledBackgroundColor: AppColors.primary
                                        .withOpacity(0.6),
                                    elevation: 4,
                                    shadowColor: AppColors.primary.withOpacity(
                                      0.3,
                                    ),
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
                                          "CREATE ACCOUNT",
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
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
