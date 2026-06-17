import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';

import '../api/api_service.dart';
import '../storage/token_storage.dart';
import '../utils/app_constants.dart';
import '../utils/ui_utils.dart';
import '../utils/skeletal_loader.dart';

class CreateUserScreen extends StatefulWidget {
  const CreateUserScreen({super.key});

  @override
  State<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends State<CreateUserScreen> {
  final ApiService api = ApiService();
  final TokenStorage storage = TokenStorage();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController roleController = TextEditingController(
    text: "ADMIN",
  );

  String selectedRole = "ADMIN";
  bool loading = false;
  bool _obscurePassword = true;
  bool _isInitLoading = true;

  final List<String> roles = ["SUPERADMIN", "ADMIN", "DELIVERY"];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _isInitLoading = false);
    });
  }

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

    FocusScope.of(context).unfocus();
    setState(() => loading = true);
    UIUtils.showProcessingSnackbar(context, message: "Creating User...");

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
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      setState(() => loading = false);

      UIUtils.showSuccessDialog(
        context,
        title: "User Created!",
        message: response.data["message"] ?? "User created successfully.",
        icon: Icons.person_add_alt_1_rounded,
        onContinue: _resetForm,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      setState(() => loading = false);
      String msg = "Failed to create user";
      if (e is DioException) {
        msg = e.response?.data["detail"]?.toString() ?? msg;
      }
      UIUtils.showSnackBar(context, msg, isError: true);
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

  void _openRoleDrawer() {
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
                padding: EdgeInsets.only(bottom: 20.0),
                child: Text(
                  "Assign Role",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textHeading,
                  ),
                ),
              ),
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
                          : AppColors.textHeading,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: AppColors.background.withOpacity(0.95),
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
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
          "Create User",
          style: TextStyle(
            color: AppColors.textHeading,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            fontFamily: 'PublicSans',
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: IconButton(
              onPressed: _resetForm,
              tooltip: "Reset Form",
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.refresh_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isInitLoading
          ? _buildSkeletonLoader()
          : SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(
                    height:
                        kToolbarHeight +
                        MediaQuery.of(context).padding.top +
                        20,
                  ),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
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
                                    UIUtils.buildLabel("Account Details"),
                                    const SizedBox(height: 16),

                                    TextFormField(
                                      controller: nameController,
                                      decoration: UIUtils.inputDecoration(
                                        "Full Name",
                                        Icons.person_outline,
                                      ),
                                      validator: (val) =>
                                          (val == null || val.isEmpty)
                                          ? "Name is required"
                                          : null,
                                    ),
                                    const SizedBox(height: 16),

                                    TextFormField(
                                      controller: mobileController,
                                      keyboardType: TextInputType.phone,
                                      maxLength: 10,
                                      decoration: UIUtils.inputDecoration(
                                        "Mobile Number",
                                        Icons.phone_android_rounded,
                                        counterText: "",
                                      ),
                                      validator: (val) {
                                        if (val == null || val.isEmpty)
                                          return "Mobile is required";
                                        if (val.length != 10)
                                          return "Enter valid 10-digit number";
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),

                                    GestureDetector(
                                      onTap: _openRoleDrawer,
                                      child: AbsorbPointer(
                                        child: TextFormField(
                                          controller: roleController,
                                          readOnly: true,
                                          decoration: UIUtils.inputDecoration(
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

                                    TextFormField(
                                      controller: passwordController,
                                      obscureText: _obscurePassword,
                                      decoration: UIUtils.inputDecoration(
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
                                            () => _obscurePassword =
                                                !_obscurePassword,
                                          ),
                                        ),
                                      ),
                                      validator: (val) =>
                                          (val == null || val.length < 6)
                                          ? "Min 6 chars required"
                                          : null,
                                    ),
                                    const SizedBox(height: 16),

                                    TextFormField(
                                      controller: addressController,
                                      decoration: UIUtils.inputDecoration(
                                        "Address",
                                        Icons.home_outlined,
                                      ),
                                      maxLines: 2,
                                    ),
                                    const SizedBox(height: 24),

                                    UIUtils.buildSubmitButton(
                                      label: "CREATE ACCOUNT",
                                      loading: loading,
                                      onPressed: createUser,
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

  Widget _buildSkeletonLoader() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        children: [
          SizedBox(
            height: kToolbarHeight + MediaQuery.of(context).padding.top + 20,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const Center(
                  child: SkeletalLoader(
                    width: 70,
                    height: 70,
                    borderRadius: 35,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletalLoader(width: 100, height: 12),
                      SizedBox(height: 16),
                      SkeletalLoader(width: double.infinity, height: 50),
                      SizedBox(height: 16),
                      SkeletalLoader(width: double.infinity, height: 50),
                      SizedBox(height: 16),
                      SkeletalLoader(width: double.infinity, height: 50),
                      SizedBox(height: 16),
                      SkeletalLoader(width: double.infinity, height: 50),
                      SizedBox(height: 16),
                      SkeletalLoader(width: double.infinity, height: 80),
                      SizedBox(height: 24),
                      SkeletalLoader(width: double.infinity, height: 50),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
