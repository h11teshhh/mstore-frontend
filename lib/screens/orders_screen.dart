import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../api/api_service.dart';
import '../utils/app_constants.dart';
import '../utils/ui_utils.dart';
import '../utils/skeletal_loader.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final ApiService api = ApiService();

  bool isLoading = false;
  bool isAreaLoading = true;

  List<String> areas = [];
  String? selectedArea;

  // This list holds the "Grouped" data for the UI
  List<Map<String, dynamic>> groupedOrders = [];
  double grandTotal = 0.0;
  int totalOrderCount = 0;

  @override
  void initState() {
    super.initState();
    loadAreas();
  }

  Future<void> loadAreas() async {
    try {
      final res = await api.getCustomers();
      final List customers = res.data ?? [];

      setState(() {
        areas = customers
            .map<String>((c) => c["area"]?.toString() ?? "")
            .where((area) => area.isNotEmpty)
            .toSet()
            .toList();
        areas.sort();
        isAreaLoading = false;
      });
    } catch (e) {
      setState(() => isAreaLoading = false);
      UIUtils.showErrorToast("Failed to load areas");
    }
  }

  Future<void> fetchOrders() async {
    if (selectedArea == null) {
      UIUtils.showErrorToast("Please select an area");
      return;
    }

    setState(() {
      isLoading = true;
      groupedOrders = [];
      grandTotal = 0;
      totalOrderCount = 0;
    });

    try {
      // API call: {{baseUrl}}/reports/bills/today?area=Kadodara
      final res = await api.getTodayBillsByArea(selectedArea!);

      if (!mounted) return;

      final rawData = res.data;
      final List rawOrders = rawData["orders"] ?? [];

      // 1. Calculate Grand Total
      grandTotal = rawOrders.fold(
        0.0,
        (sum, order) =>
            sum + (double.tryParse(order["bill_amount"].toString()) ?? 0),
      );
      totalOrderCount = rawData["total_orders"] ?? 0;

      // 2. GROUP ORDERS BY CUSTOMER ID
      Map<String, Map<String, dynamic>> tempMap = {};

      for (var order in rawOrders) {
        final custId = order["customer_id"].toString();
        final custName = order["customer_name"] ?? "Unknown";
        final billAmount =
            double.tryParse(order["bill_amount"].toString()) ?? 0.0;

        if (!tempMap.containsKey(custId)) {
          // Initialize customer entry
          tempMap[custId] = {
            "customer_name": custName,
            "total_customer_bill": 0.0,
            "order_count": 0,
            "orders": [], // List of individual orders
          };
        }

        // Add to customer totals
        tempMap[custId]!["total_customer_bill"] += billAmount;
        tempMap[custId]!["order_count"] += 1;
        tempMap[custId]!["orders"].add(order);
      }

      setState(() {
        groupedOrders = tempMap.values.toList(); // Convert Map back to List
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      String msg = "Failed to fetch orders";
      if (e is DioException) {
        msg = e.response?.data["detail"]?.toString() ?? msg;
      }
      UIUtils.showErrorToast(msg);
    }
  }

  // --- HELPER: Currency Formatter ---
  String _formatCurrency(dynamic amount) {
    double val = double.tryParse(amount?.toString() ?? "0") ?? 0.0;
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(val);
  }

  // --- MAIN BUILD ---
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // 20-25% visual upside offset
    final double topOffset = size.height * 0.08;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Today's Orders", style: AppTypography.heading),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textHeading),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: selectedArea != null ? fetchOrders : null,
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(height: topOffset * 0.5),

          // 1. AREA SELECTOR (High Position)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.cardPadding,
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "SELECT AREA",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            filled: true,
                            fillColor: AppColors.background,
                            prefixIcon: const Icon(
                              Icons.location_on,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          initialValue: selectedArea,
                          hint: isAreaLoading
                              ? const Text("Loading...")
                              : const Text("Choose Area"),
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
                              groupedOrders = []; // Clear old data
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: (isLoading || selectedArea == null)
                            ? null
                            : fetchOrders,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          elevation: 2,
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.arrow_forward,
                                color: Colors.white,
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 2. GROUPED ORDER LIST
          Expanded(
            child: isLoading
                ? _buildSkeletonList()
                : groupedOrders.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.cardPadding,
                      vertical: 10,
                    ),
                    physics: const BouncingScrollPhysics(),
                    itemCount: groupedOrders.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _buildGroupedCustomerCard(groupedOrders[index]);
                    },
                  ),
          ),
        ],
      ),

      // 3. BOTTOM GRAND TOTAL
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "TOTAL REVENUE",
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _formatCurrency(grandTotal),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "$totalOrderCount Orders",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGETS ---

  // ✅ Grouped Customer Card
  Widget _buildGroupedCustomerCard(Map<String, dynamic> customerData) {
    final customerName = customerData["customer_name"];
    final totalBill = _formatCurrency(customerData["total_customer_bill"]);
    final count = customerData["order_count"];
    final List individualOrders = customerData["orders"];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 5),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: Border.all(color: Colors.transparent),
        collapsedShape: Border.all(color: Colors.transparent),
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.1),
          child: Text(
            customerName.substring(0, 1).toUpperCase(),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
        title: Text(
          customerName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textHeading,
          ),
        ),
        subtitle: Text(
          "$count Order(s)",
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              totalBill,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.success,
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey),
          ],
        ),

        // Expanded List of Individual Orders
        children: [
          Container(
            color: const Color(0xFFF9FAFB),
            child: Column(
              children: [
                const Divider(height: 1),
                ...individualOrders.map((order) {
                  return _buildInnerOrderRow(order);
                }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Inner Row: Shows full Order ID & NO Time
  Widget _buildInnerOrderRow(Map<String, dynamic> order) {
    final bill = _formatCurrency(order["bill_amount"]);
    final items = order["items"] as List? ?? [];

    // UPDATED: Use the FULL Actual Order ID
    final orderId = order["order_id"].toString();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Header (No Time)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "Order #$orderId", // Full ID
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                bill,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.textHeading,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Items List
          ...items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  Text("• ", style: TextStyle(color: Colors.grey[400])),
                  Expanded(
                    child: Text(
                      "${item["item_name"]} (${item["quantity"]} x ${item["price"]})",
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                  ),
                  Text(
                    _formatCurrency(item["total"]),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }),
          const Divider(height: 20),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            selectedArea == null ? "Select an area" : "No orders found",
            style: TextStyle(color: Colors.grey[400], fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.cardPadding,
        vertical: 10,
      ),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) =>
          const SkeletalLoader(height: 80, borderRadius: 12),
    );
  }
}
