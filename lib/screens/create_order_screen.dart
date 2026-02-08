import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../api/api_service.dart';
import '../utils/app_constants.dart'; // Ensuring standard colors

class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  // --- EXISTING LOGIC (UNTOUCHED) ---
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

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    try {
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
    } catch (e) {
      showCustomSnackBar("Failed to load data", isError: true);
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
    // Validation
    if (selectedArea == null) {
      showCustomSnackBar("Please select an area", isError: true);
      return;
    }
    if (selectedCustomerId == null) {
      showCustomSnackBar("Please select a customer", isError: true);
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
          showCustomSnackBar(
            "Invalid quantity for ${item["item_name"]}",
            isError: true,
          );
          return;
        }
        if (qty > stock) {
          showCustomSnackBar(
            "Not enough stock for ${item["item_name"]}",
            isError: true,
          );
          return;
        }
        items.add({"item_id": itemId, "quantity": qty});
      }
    }

    if (items.isEmpty) {
      showCustomSnackBar("Please select at least one item", isError: true);
      return;
    }

    // Submit
    setState(() => isLoading = true);
    try {
      await api.createOrder(customerId: selectedCustomerId!, items: items);

      if (!mounted) return;
      setState(() => isLoading = false);

      _showSuccessDialog(); // New Interactive Dialog
    } on DioException catch (e) {
      setState(() => isLoading = false);
      String msg = "Order failed";
      if (e.response?.data != null && e.response!.data is Map) {
        msg = e.response!.data["detail"]?.toString() ?? msg;
      }
      showCustomSnackBar(msg, isError: true);
    } catch (e) {
      setState(() => isLoading = false);
      showCustomSnackBar("Unexpected error occurred", isError: true);
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
              // Animated-style Icon Container
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
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Go back to dashboard
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
    // Calculate visual offset for the "Control Card"
    final topOffset = MediaQuery.of(context).size.height * 0.02;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F9),
      appBar: AppBar(
        title: const Text(
          "Create Order",
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
      body: customers.isEmpty || inventory.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : Column(
              children: [
                SizedBox(height: topOffset),

                // 1. CONTROL PANEL (Area & Customer)
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
                              selectedCustomerId = null; // Reset customer
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
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      100,
                    ), // Extra padding at bottom for floating bar
                    itemCount: inventory.length,
                    itemBuilder: (context, index) {
                      return _buildInventoryCard(inventory[index]);
                    },
                  ),
                ),
              ],
            ),

      // 4. BOTTOM TOTAL BAR
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                    Text(
                      "₹${totalBill.toStringAsFixed(0)}",
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
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
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
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
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET COMPONENTS ---

  Widget _buildInventoryCard(Map<String, dynamic> item) {
    final itemId = item["id"];
    final stock = item["current_stock"];
    final price = item["price"];
    final isSelected = selectedItems[itemId] == true;
    final hasError = quantityErrors[itemId] == true;
    final isOutOfStock = stock <= 0;
    final isLowStock = stock > 0 && stock < 10; // Assuming 10 is low

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
                      quantityControllers[itemId]!
                          .clear(); // Clear if unchecked
                      calculateTotal();
                    }
                  });
                },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Checkbox
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

                // Item Details
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
                      Row(
                        children: [
                          _buildStockBadge(stock, isOutOfStock, isLowStock),
                          const SizedBox(width: 8),
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

                // Quantity Input (Only show if selected)
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
}
