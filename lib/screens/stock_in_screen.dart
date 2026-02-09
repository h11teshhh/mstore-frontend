import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ For Status Bar Control
import 'package:dio/dio.dart';
import '../api/api_service.dart';
import '../utils/app_constants.dart';
import '../utils/ui_utils.dart'; // ✅ Using UIUtils
import '../utils/skeletal_loader.dart'; // ✅ Using Skeleton Loader

class StockInScreen extends StatefulWidget {
  const StockInScreen({super.key});

  @override
  State<StockInScreen> createState() => _StockInScreenState();
}

class _StockInScreenState extends State<StockInScreen> {
  final ApiService api = ApiService();
  final _formKey = GlobalKey<FormState>();

  List<dynamic> items = [];
  String? selectedItemId;

  bool loading = false; // For submission
  bool fetching = true; // For initial data load

  final TextEditingController quantityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchItems();
  }

  @override
  void dispose() {
    quantityController.dispose();
    super.dispose();
  }

  Future<void> fetchItems() async {
    setState(() => fetching = true);
    try {
      // Optional delay for visual smoothness
      // await Future.delayed(const Duration(milliseconds: 800));

      final response = await api.getInventoryStock();
      if (!mounted) return;

      setState(() {
        items = response.data ?? [];
        fetching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => fetching = false);
      // ✅ Using UIUtils
      UIUtils.showErrorToast("Failed to load inventory items");
    }
  }

  Future<void> submitStockIn() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedItemId == null) {
      UIUtils.showErrorToast("Please select an item");
      return;
    }

    FocusScope.of(context).unfocus();

    // ✅ UIUtils: Notify user processing started
    UIUtils.showProcessingSnackbar(context, message: "Updating stock...");
    setState(() => loading = true);

    try {
      final response = await api.addInventoryMovement(
        itemId: selectedItemId!,
        quantity: int.parse(quantityController.text.trim()),
      );

      if (!mounted) return;

      // Hide the processing snackbar
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      _showSuccessDialog(
        response.data["message"] ?? "Stock added successfully",
      );

      // Reset Form
      quantityController.clear();
      setState(() {
        selectedItemId = null;
      });
      // Refresh list
      fetchItems();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar(); // Hide loading

      String msg = "Failed to add stock";
      if (e is DioException) {
        msg = e.response?.data["detail"]?.toString() ?? msg;
      }
      // ✅ Using UIUtils
      UIUtils.showErrorToast(msg);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // --- UI HELPERS ---

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
                "Stock Updated!",
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
    // Position: 10% from top puts the card in the upper-middle "sweet spot"
    final double topOffset = size.height * 0.10;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F9), // Sneat Background
      extendBodyBehindAppBar: true, // ✅ Content goes behind AppBar
      // ✅ 1. PRODUCTIVE SNEAT APP BAR
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F9).withOpacity(0.95),
        elevation: 0,
        centerTitle: true,
        // ✅ Status Bar Visibility
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
                color: Color(0xFF566a7f),
              ),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: const Text(
          "Add Stock",
          style: TextStyle(
            color: Color(0xFF566a7f),
            fontWeight: FontWeight.bold,
            fontSize: 20,
            fontFamily: 'PublicSans',
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          // Refresh Button
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: IconButton(
              onPressed: fetchItems,
              tooltip: "Refresh Items",
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

      body: SingleChildScrollView(
        child: Column(
          children: [
            // Spacer for AppBar + TopOffset
            SizedBox(
              height:
                  kToolbarHeight +
                  MediaQuery.of(context).padding.top +
                  topOffset,
            ),

            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: fetching
                    ? _buildSkeletonForm() // ✅ Uses SkeletalLoader
                    : Padding(
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
                                Icons.move_to_inbox_rounded,
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
                                    _buildLabel("Stock Details"),
                                    const SizedBox(height: 16),

                                    // Item Selector
                                    DropdownButtonFormField<String>(
                                      initialValue: selectedItemId,
                                      decoration: _inputDecoration(
                                        "Select Item",
                                        Icons.inventory_2_outlined,
                                      ),
                                      hint: const Text(
                                        "Choose item to stock in",
                                      ),
                                      items: items.map((item) {
                                        return DropdownMenuItem<String>(
                                          value: item["id"].toString(),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                item["item_name"],
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              Text(
                                                " (Qty: ${item["current_stock"]})",
                                                style: TextStyle(
                                                  color: Colors.grey[500],
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          selectedItemId = value;
                                        });
                                      },
                                      validator: (value) => value == null
                                          ? "Please select an item"
                                          : null,
                                    ),

                                    const SizedBox(height: 20),

                                    // Quantity Input
                                    TextFormField(
                                      controller: quantityController,
                                      keyboardType: TextInputType.number,
                                      decoration: _inputDecoration(
                                        "Quantity to Add",
                                        Icons.add_circle_outline,
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return "Quantity is required";
                                        }
                                        if (int.tryParse(value) == null ||
                                            int.parse(value) <= 0) {
                                          return "Enter valid quantity (>0)";
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
                                        onPressed: loading
                                            ? null
                                            : submitStockIn,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          disabledBackgroundColor: AppColors
                                              .primary
                                              .withOpacity(0.6),
                                          elevation: 4,
                                          shadowColor: AppColors.primary
                                              .withOpacity(0.3),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                        child: loading
                                            ? const SizedBox(
                                                height: 24,
                                                width: 24,
                                                child:
                                                    CircularProgressIndicator(
                                                      color: Colors.white,
                                                      strokeWidth: 2.5,
                                                    ),
                                              )
                                            : const Text(
                                                "ADD TO STOCK",
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

  // --- WIDGET HELPER METHODS ---

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

  // --- SKELETON FORM ---
  Widget _buildSkeletonForm() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Skeleton Icon
          const SkeletalLoader(width: 70, height: 70, borderRadius: 35),
          const SizedBox(height: 24),
          // Skeleton Form Card
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
                SizedBox(height: 16),
                SkeletalLoader(width: double.infinity, height: 55),
                SizedBox(height: 20),
                SkeletalLoader(width: double.infinity, height: 55),
                SizedBox(height: 30),
                SkeletalLoader(width: double.infinity, height: 50),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
