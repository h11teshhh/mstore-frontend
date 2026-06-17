import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';

import '../api/api_service.dart';
import '../utils/app_constants.dart';
import '../utils/ui_utils.dart';
import '../utils/skeletal_loader.dart';

class CreateCustomerScreen extends StatefulWidget {
  const CreateCustomerScreen({super.key});

  @override
  State<CreateCustomerScreen> createState() => _CreateCustomerScreenState();
}

class _CreateCustomerScreenState extends State<CreateCustomerScreen> {
  final ApiService api = ApiService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController manualAreaController = TextEditingController();
  final TextEditingController dropdownDisplayController = TextEditingController();

  bool loading = false;
  bool _isOtherSelected = false;
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
    UIUtils.showProcessingSnackbar(context, message: "Creating customer...");

    try {
      final String finalArea = _isOtherSelected
          ? manualAreaController.text.trim()
          : dropdownDisplayController.text.trim();

      final response = await api.createCustomer(
        name: nameController.text.trim(),
        mobile: mobileController.text.trim(),
        area: finalArea,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      setState(() => loading = false);

      UIUtils.showSuccessDialog(
        context,
        title: "Customer Created!",
        message: response.data["message"] ?? "New customer added successfully.",
        icon: Icons.person_add_alt_1_rounded,
        onContinue: _resetForm,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      setState(() => loading = false);
      String msg = "Failed to create customer";
      if (e is DioException) {
        msg = e.response?.data["detail"]?.toString() ?? msg;
      }
      UIUtils.showSnackBar(context, msg, isError: true);
    }
  }

  void _resetForm() {
    nameController.clear();
    mobileController.clear();
    manualAreaController.clear();
    dropdownDisplayController.clear();
    setState(() => _isOtherSelected = false);
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
                    color: AppColors.textHeading,
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                      leading: Icon(
                        Icons.location_on_outlined,
                        color: isSelected ? AppColors.primary : Colors.grey,
                      ),
                      title: Text(
                        item,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isSelected ? AppColors.primary : AppColors.textHeading,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: AppColors.primary)
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: AppColors.background.withOpacity(0.9),
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
            color: AppColors.textHeading,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            fontFamily: 'PublicSans',
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.08 + kToolbarHeight),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _isInitLoading ? _buildSkeletonForm() : _buildActualForm(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActualForm() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.person_add_alt_1_rounded, size: 40, color: AppColors.primary),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10)),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UIUtils.buildLabel("Customer Details"),
                const SizedBox(height: 16),

                TextFormField(
                  controller: nameController,
                  decoration: UIUtils.inputDecoration("Customer Name", Icons.person_outline),
                  validator: (value) =>
                      (value == null || value.isEmpty) ? "Name is required" : null,
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
                  validator: (value) {
                    if (value == null || value.isEmpty) return "Mobile is required";
                    if (value.length != 10) return "Enter valid 10-digit mobile";
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                GestureDetector(
                  onTap: _openAreaDrawer,
                  child: AbsorbPointer(
                    child: TextFormField(
                      controller: dropdownDisplayController,
                      decoration: UIUtils.inputDecoration(
                        "Select Area",
                        Icons.location_on_outlined,
                        suffixIcon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      validator: (value) =>
                          (value == null || value.isEmpty) ? "Please select an area" : null,
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
                      decoration: UIUtils.inputDecoration(
                        "Enter Manual Location",
                        Icons.edit_location_alt_outlined,
                      ),
                      validator: (value) {
                        if (_isOtherSelected && (value == null || value.isEmpty)) {
                          return "Please enter the location";
                        }
                        return null;
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 30),

                UIUtils.buildSubmitButton(
                  label: "CREATE CUSTOMER",
                  loading: loading,
                  onPressed: createCustomer,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 50),
      ],
    );
  }

  Widget _buildSkeletonForm() {
    return Column(
      children: [
        const SkeletalLoader(width: 70, height: 70, borderRadius: 35),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletalLoader(width: 120, height: 14),
              SizedBox(height: 20),
              SkeletalLoader(height: 55),
              SizedBox(height: 20),
              SkeletalLoader(height: 55),
              SizedBox(height: 20),
              SkeletalLoader(height: 55),
              SizedBox(height: 30),
              SkeletalLoader(height: 50),
            ],
          ),
        ),
      ],
    );
  }
}
