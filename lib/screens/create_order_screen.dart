import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Status Bar Control
import 'package:dio/dio.dart';
import 'dart:async'; // For UI delay

import '../api/api_service.dart';
import '../utils/app_constants.dart';
import '../utils/skeletal_loader.dart'; // ✅ Reusing your specific loader

class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  // --- EXISTING LOGIC ---
  final ApiService api = ApiService();
  bool isLoading = false;
  List customers = [];
  List inventory = [];
  List<String> areas = [];
  String? selectedArea;
  String? selectedCustomerId;

  Map<String, bool> selectedItems = {};
  Map<String, TextEditingController> quantityControllers = {};
  Map<String, bool> quantityErrors = {};
  double totalBill = 0;

  // UI State
  bool _isInitLoading = true;
  bool _isTimeout = false; // ✅ State for 45s Timeout

  @override
  void initState() {
    super.initState();
    // Simulate a quick UI prep to show off the skeleton effect
    Timer(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _isInitLoading = false);
    });
    loadData();
  }

  // ✅ CODE REUSABILITY: Reusable Timeout Helper
  Future<T> fetchWithTimeout<T>(Future<T> Function() apiCall) async {
    try {
      return await apiCall().timeout(
        const Duration(seconds: 45), // 30-45 sec rule
        onTimeout: () => throw TimeoutException("No data found"),
      );
    } catch (e) {
      rethrow;
    }
  }

  // ✅ CODE REUSABILITY: Toast Helper (For Error/Success)
  // Simulating a Toast using ScaffoldMessenger for 'copy-paste' compatibility
  // without needing external packages like 'fluttertoast'.
  void showToast(String message, {bool isError = false}) {
    // Clear any existing snackbars/toasts first
    ScaffoldMessenger.of(context).clearSnackBars();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: isError ? AppColors.danger : AppColors.success,
        behavior: SnackBarBehavior.floating,
        width: 280, // Fixed width to look like a "Toast"
        elevation: 6,
        duration: const Duration(seconds: 2), // Short duration for Toasts
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
      ),
    );
  }

  // ✅ CODE REUSABILITY: SnackBar Helper (For Wait/Continuous)
  void showLoadingSnackBar(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.fixed, // Bottom fixed for continuous
        duration: const Duration(
          days: 1,
        ), // Keeps showing until manually hidden
      ),
    );
  }

  Future<void> loadData() async {
    if (mounted) setState(() => _isTimeout = false);

    try {
      // ✅ Using the reusable helper
      await fetchWithTimeout(() async {
        final customerRes = await api.getCustomers();
        final inventoryRes = await api.getInventoryStock();

        if (!mounted) return;

        setState(() {
          customers = customerRes.data;
          inventory = inventoryRes.data;
          areas = customers
              .map<String>((c) => c["area"].toString())
              .toSet()
              .toList();
          areas.sort();

          for (var item in inventory) {
            quantityControllers[item["id"]] = TextEditingController();
            selectedItems[item["id"]] = false;
            quantityErrors[item["id"]] = false;
          }
        });
      });
    } on TimeoutException {
      if (mounted) setState(() => _isTimeout = true);
    } catch (e) {
      if (mounted) showToast("Failed to load data", isError: true);
    }
  }

  void calculateTotal() {
    double sum = 0;
    for (var item in inventory) {
      final itemId = item["id"];
      final price = item["price"];
      final stock = item["current_stock"];

      if (selectedItems[itemId] == true) {
        final qty = int.tryParse(quantityControllers[itemId]!.text) ?? 0;

        setState(() {
          if (qty > stock) {
            quantityErrors[itemId] = true;
          } else {
            quantityErrors[itemId] = false;
            sum += qty * price;
          }
        });
      }
    }
    setState(() => totalBill = sum);
  }

  Future<void> submitOrder() async {
    // --- Validation (Uses Toasts) ---
    if (selectedArea == null) {
      showToast("Please select an area", isError: true);
      return;
    }
    if (selectedCustomerId == null) {
      showToast("Please select a customer", isError: true);
      return;
    }

    List<Map<String, dynamic>> items = [];
    for (var item in inventory) {
      final itemId = item["id"];
      final stock = item["current_stock"];
      if (selectedItems[itemId] == true) {
        final qtyText = quantityControllers[itemId]!.text;
        int qty = int.tryParse(qtyText) ?? 0;

        if (qty <= 0) {
          showToast("Invalid quantity for ${item["item_name"]}", isError: true);
          return;
        }
        if (qty > stock) {
          showToast("Not enough stock for ${item["item_name"]}", isError: true);
          return;
        }
        items.add({"item_id": itemId, "quantity": qty});
      }
    }

    if (items.isEmpty) {
      showToast("Please select at least one item", isError: true);
      return;
    }

    // --- Start Continuous Process (Uses SnackBar) ---
    setState(() => isLoading = true);
    showLoadingSnackBar("Processing Order..."); // Show "Wait" SnackBar

    try {
      await api.createOrder(customerId: selectedCustomerId!, items: items);

      if (!mounted) return;

      // Stop Loading and Clear SnackBar
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      setState(() => isLoading = false);

      showToast("Order Created Successfully!"); // Show Success Toast
      _showSuccessDialog();
    } on DioException catch (e) {
      // Clear Loading SnackBar
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      setState(() => isLoading = false);

      String msg = "Order failed";
      if (e.response?.data != null && e.response!.data is Map) {
        msg = e.response!.data["detail"]?.toString() ?? msg;
      }
      showToast(msg, isError: true); // Show Error Toast
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      setState(() => isLoading = false);
      showToast("Unexpected error occurred", isError: true); // Show Error Toast
    }
  }

  // --- UI HELPERS ---

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppColors.success,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Order Placed!",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF566a7f),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Your order has been created successfully.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  child: const Text(
                    "Done",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
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
    // Determine loading state
    final bool isSkeletonVisible =
        _isInitLoading ||
        (customers.isEmpty && !_isTimeout) ||
        (inventory.isEmpty && !_isTimeout);

    final int selectedCount = selectedItems.values.where((e) => e).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F9),
      extendBodyBehindAppBar: true,

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
          "Create Order",
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
            child: Chip(
              backgroundColor: AppColors.primary.withOpacity(0.1),
              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              avatar: const Icon(
                Icons.shopping_bag_outlined,
                size: 16,
                color: AppColors.primary,
              ),
              label: Text(
                "$selectedCount Items",
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),

      body: isSkeletonVisible
          ? _buildSkeletonLoader()
          : _isTimeout
          ? _buildNoDataFound() // ✅ Handle Timeout UI
          : Column(
              children: [
                SizedBox(
                  height:
                      kToolbarHeight + MediaQuery.of(context).padding.top + 20,
                ),

                // 1. CONTROL PANEL
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel("Select Area"),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          decoration: _inputDecoration(Icons.map_outlined),
                          initialValue: selectedArea,
                          isExpanded: true,
                          hint: const Text("Choose Area"),
                          items: areas
                              .map(
                                (area) => DropdownMenuItem(
                                  value: area,
                                  child: Text(area),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedArea = value;
                              selectedCustomerId = null;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildLabel("Select Customer"),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          decoration: _inputDecoration(Icons.person_outline),
                          initialValue: selectedCustomerId,
                          isExpanded: true,
                          hint: const Text("Choose Customer"),
                          items: customers
                              .where((c) => c["area"] == selectedArea)
                              .map<DropdownMenuItem<String>>((c) {
                                return DropdownMenuItem(
                                  value: c["id"].toString(),
                                  child: Text(
                                    "${c["name"]} (${c["mobile"]})",
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              })
                              .toList(),
                          onChanged: (value) =>
                              setState(() => selectedCustomerId = value),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 2. INVENTORY LIST HEADER
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.inventory_2_outlined,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "INVENTORY ITEMS",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // 3. SCROLLABLE LIST
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: inventory.length,
                    itemBuilder: (context, index) {
                      return _buildInventoryCard(inventory[index]);
                    },
                  ),
                ),
              ],
            ),

      // 4. BOTTOM TOTAL BAR
      bottomNavigationBar: (isSkeletonVisible || _isTimeout)
          ? null
          : Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "TOTAL BILL",
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          // ✅ FIXED: FittedBox prevents bill overflow
                          SizedBox(
                            width: double.infinity,
                            child: FittedBox(
                              alignment: Alignment.centerLeft,
                              fit: BoxFit.scaleDown,
                              child: Text(
                                "₹${totalBill.toStringAsFixed(0)}",
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 160,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : submitOrder,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 5,
                          shadowColor: AppColors.primary.withOpacity(0.4),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            // ✅ FIXED: FittedBox prevents "PLACE ORDER" overflow
                            : FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Text(
                                      "PLACE ORDER",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // --- WIDGET COMPONENTS ---

  Widget _buildNoDataFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            "No Data Found",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: loadData,
            icon: const Icon(Icons.refresh),
            label: const Text("Retry"),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryCard(Map<String, dynamic> item) {
    final itemId = item["id"];
    final stock = item["current_stock"];
    final price = item["price"];
    final isSelected = selectedItems[itemId] == true;
    final hasError = quantityErrors[itemId] == true;
    final isOutOfStock = stock <= 0;
    final isLowStock = stock > 0 && stock < 10;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasError
              ? AppColors.danger
              : (isSelected ? AppColors.primary : Colors.transparent),
          width: isSelected || hasError ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isOutOfStock
              ? null
              : () {
                  setState(() {
                    selectedItems[itemId] = !isSelected;
                    if (!selectedItems[itemId]!) {
                      quantityControllers[itemId]!.clear();
                      calculateTotal();
                    }
                  });
                },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Transform.scale(
                  scale: 1.1,
                  child: Checkbox(
                    value: isSelected,
                    activeColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    onChanged: isOutOfStock
                        ? null
                        : (val) {
                            setState(() {
                              selectedItems[itemId] = val!;
                              if (!val) {
                                quantityControllers[itemId]!.clear();
                                calculateTotal();
                              }
                            });
                          },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item["item_name"],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isOutOfStock
                              ? Colors.grey
                              : const Color(0xFF566a7f),
                          decoration: isOutOfStock
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // ✅ FIXED: Wrap handles narrow screens better than Row
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          _buildStockBadge(stock, isOutOfStock, isLowStock),
                          Text(
                            "₹$price",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  SizedBox(
                    width: 90,
                    child: TextField(
                      controller: quantityControllers[itemId],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                      decoration: InputDecoration(
                        hintText: "Qty",
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        isDense: true,
                        filled: true,
                        fillColor: AppColors.primary.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        errorText: hasError ? "Stock!" : null,
                        errorStyle: const TextStyle(fontSize: 10, height: 0.8),
                      ),
                      onChanged: (_) => calculateTotal(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStockBadge(int stock, bool isOut, bool isLow) {
    Color color = AppColors.success;
    String text = "$stock left";
    if (isOut) {
      color = Colors.grey;
      text = "Out of Stock";
    } else if (isLow) {
      color = AppColors.warning;
      text = "Low: $stock";
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Colors.grey[500],
        letterSpacing: 0.5,
      ),
    );
  }

  InputDecoration _inputDecoration(IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(
        icon,
        color: AppColors.primary.withOpacity(0.6),
        size: 20,
      ),
      filled: true,
      fillColor: const Color(0xFFF5F5F9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return Column(
      children: [
        SizedBox(
          height: kToolbarHeight + MediaQuery.of(context).padding.top + 20,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletalLoader(width: 80, height: 12),
                SizedBox(height: 8),
                SkeletalLoader(width: double.infinity, height: 48),
                SizedBox(height: 16),
                SkeletalLoader(width: 80, height: 12),
                SizedBox(height: 8),
                SkeletalLoader(width: double.infinity, height: 48),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, __) =>
                const SkeletalLoader(height: 80, borderRadius: 12),
          ),
        ),
      ],
    );
  }
}
