import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';

import '../api/api_service.dart';
import '../utils/app_constants.dart';
import '../utils/ui_utils.dart';
import '../utils/skeletal_loader.dart';

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final ApiService api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController itemController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  bool loading = false;
  bool _isInitLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
    UIUtils.showProcessingSnackbar(context, message: "Adding item...");

    try {
      final response = await api.addInventoryItem(
        itemController.text.trim(),
        double.parse(priceController.text.trim()),
      );

      if (!mounted) return;
      AppToast.dismiss(); // dismiss loading toast
      setState(() => loading = false);

      UIUtils.showSuccessDialog(
        context,
        title: "Item Added!",
        message: response.data["message"] ?? "Item added successfully.",
        icon: Icons.check_circle_rounded,
        onContinue: _resetForm,
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.dismiss(); // dismiss loading toast
      setState(() => loading = false);
      String msg = "Unexpected error occurred";
      if (e is DioException) {
        msg = e.response?.data.toString() ?? "Failed to add item";
      }
      UIUtils.showSnackBar(context, msg, isError: true);
    }
  }

  void _resetForm() {
    itemController.clear();
    priceController.clear();
    setState(() {});
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
          "New Inventory Item",
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
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.15 + kToolbarHeight,
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _isInitLoading ? _buildSkeletonLoader() : _buildActualForm(),
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
          child: const Icon(Icons.add_shopping_cart_rounded, size: 40, color: AppColors.primary),
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
                UIUtils.buildLabel("Item Details"),
                const SizedBox(height: 16),

                TextFormField(
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  controller: itemController,
                  decoration: UIUtils.inputDecoration("Item Name", Icons.inventory_2_outlined),
                  validator: (value) =>
                      (value == null || value.isEmpty) ? "Item name is required" : null,
                ),
                const SizedBox(height: 20),

                TextFormField(
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  controller: priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: UIUtils.inputDecoration("Price (₹)", Icons.currency_rupee_rounded),
                  validator: (value) {
                    if (value == null || value.isEmpty) return "Price is required";
                    if (double.tryParse(value) == null) return "Enter valid number";
                    return null;
                  },
                ),
                const SizedBox(height: 30),

                UIUtils.buildSubmitButton(
                  label: "ADD TO INVENTORY",
                  loading: loading,
                  onPressed: addItem,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 50),
      ],
    );
  }

  Widget _buildSkeletonLoader() {
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
              SkeletalLoader(width: 100, height: 14),
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
