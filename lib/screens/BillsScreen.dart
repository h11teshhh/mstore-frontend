import 'dart:io';
import 'dart:math'; // For random if needed
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Status Bar
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../api/api_service.dart';
import '../utils/bill_pdf.dart';
import '../utils/app_constants.dart';
import '../utils/skeletal_loader.dart'; // ✅ Imported Skeleton

class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  final ApiService api = ApiService();

  // State Variables
  bool isLoading = false;
  List customers = [];
  List<String> areas = [];
  String? selectedArea;

  // Data Maps
  final Map<String, Map<String, dynamic>> customerMap = {};
  final Map<String, List<Map<String, dynamic>>> billsByCustomer = {};
  final Map<String, int> selectedBillIndex = {};

  @override
  void initState() {
    super.initState();
    loadCustomers();
  }

  // 1. Load Customers & Areas (UNTOUCHED LOGIC)
  Future<void> loadCustomers() async {
    try {
      final res = await api.getCustomers();
      if (!mounted) return;

      setState(() {
        customers = res.data ?? [];
        areas.clear();
        for (final c in customers) {
          customerMap[c["id"].toString()] = c;
          if (c["area"] != null && !areas.contains(c["area"])) {
            areas.add(c["area"].toString());
          }
        }
        areas.sort();
      });
    } catch (e) {
      showSnack("Failed to load customers: $e", isError: true);
    }
  }

  // 2. Fetch Bills (UNTOUCHED LOGIC)
  Future<void> fetchBills() async {
    if (selectedArea == null || selectedArea!.isEmpty) {
      showSnack("Please select an area first", isError: true);
      return;
    }

    setState(() {
      isLoading = true;
      billsByCustomer.clear();
      selectedBillIndex.clear();
    });

    try {
      final res = await api.getTodayBillsByArea(selectedArea!);
      final orders = List<Map<String, dynamic>>.from(res.data["orders"] ?? []);

      for (final o in orders) {
        final cid = o["customer_id"]?.toString();
        if (cid == null) continue;

        if (!billsByCustomer.containsKey(cid)) {
          billsByCustomer[cid] = [];
        }
        billsByCustomer[cid]!.add(o);
      }

      for (final cid in billsByCustomer.keys) {
        billsByCustomer[cid]!.sort((a, b) {
          return DateTime.parse(
            b["created_at"] ?? "2000-01-01",
          ).compareTo(DateTime.parse(a["created_at"] ?? "2000-01-01"));
        });
        selectedBillIndex[cid] = 0;
      }
    } catch (e) {
      showSnack("Failed to fetch bills: $e", isError: true);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // 3. Handle PDF Actions (UNTOUCHED LOGIC)
  Future<void> _handlePdfAction(String cid, String action) async {
    final index = selectedBillIndex[cid] ?? 0;
    final orders = billsByCustomer[cid];
    if (orders == null || orders.isEmpty) return;

    final order = orders[index];
    final customer = customerMap[cid];
    if (customer == null) return;

    final isLatest = index == 0;
    final prevDue = isLatest
        ? (double.tryParse(customer["current_due"]?.toString() ?? "0") ?? 0.0) -
              (double.tryParse(order["remaining_due"]?.toString() ?? "0") ??
                  0.0)
        : 0.0;

    final pdf = BillPdf.generate(
      area: customer["area"]?.toString() ?? "N/A",
      customerName: customer["name"]?.toString() ?? "Unknown",
      customerId: customer["id"]?.toString() ?? "",
      orderId: order["order_id"]?.toString() ?? "",
      phone: customer["mobile"]?.toString() ?? "-",
      billDate: DateTime.tryParse(order["created_at"] ?? "") ?? DateTime.now(),
      items: List<Map<String, dynamic>>.from(order["items"] ?? []),
      todayBill:
          (double.tryParse(order["bill_amount"]?.toString() ?? "0") ?? 0.0),
      previousDue: prevDue,
    );

    if (action == 'preview') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfPreview(
            build: (format) async => pdf.save(),
            canChangeOrientation: false,
            canChangePageFormat: false,
          ),
        ),
      );
    } else if (action == 'print') {
      await Printing.layoutPdf(onLayout: (_) async => pdf.save());
    } else if (action == 'download') {
      try {
        final bytes = await pdf.save();
        final name = (customer["name"] ?? "Customer").toString().replaceAll(
          RegExp(r'[^\w\s]+'),
          '',
        );
        final date = DateFormat('ddMMyy').format(DateTime.now());
        final fileName = "Bill_${name}_${customer["id"]}_$date.pdf";

        Directory dir;
        if (Platform.isAndroid) {
          dir = (await getExternalStorageDirectory())!;
        } else {
          dir = await getApplicationDocumentsDirectory();
        }

        final savePath = "${dir.path}/$fileName";
        final file = File(savePath);
        await file.writeAsBytes(bytes);

        showSnack("Saved to Downloads: $fileName");
      } catch (e) {
        showSnack("Save Failed: $e", isError: true);
      }
    }
  }

  void showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: isError ? AppColors.danger : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
      ),
    );
  }

  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double topOffset = size.height * 0.08; // 20-25% visual upside

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F9), // Sneat Background
      extendBodyBehindAppBar: true,

      // ✅ 1. SNEAT APP BAR
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
          "Bills & Reports",
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
              icon: const Icon(Icons.print_outlined, color: AppColors.primary),
              onPressed: () {
                // Bulk print action (future scope)
              },
            ),
          ),
        ],
      ),

      body: Column(
        children: [
          SizedBox(height: topOffset + kToolbarHeight),

          // 2. CONTROL CARD (Area Selector)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: "Select Area",
                      labelStyle: TextStyle(color: Colors.grey[600]),
                      prefixIcon: const Icon(
                        Icons.map_outlined,
                        color: AppColors.primary,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF5F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                    ),
                    initialValue: selectedArea,
                    isExpanded: true,
                    items: areas
                        .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        selectedArea = val;
                        billsByCustomer.clear();
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 4,
                        shadowColor: AppColors.primary.withOpacity(0.4),
                      ),
                      icon: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.search_rounded,
                              color: Colors.white,
                            ),
                      label: Text(
                        isLoading ? "Fetching..." : "GET BILLS",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          color: Colors.white,
                        ),
                      ),
                      onPressed: isLoading ? null : fetchBills,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 3. BILL LIST
          Expanded(
            child: isLoading
                ? _buildSkeletonList() // ✅ USING SKELETON LOADER
                : billsByCustomer.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    physics: const BouncingScrollPhysics(),
                    itemCount: billsByCustomer.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final cid = billsByCustomer.keys.elementAt(index);
                      return _buildCustomerBillCard(cid);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS (UNTOUCHED LOGIC, RESTYLED) ---

  Widget _buildCustomerBillCard(String cid) {
    final customer = customerMap[cid]!;
    final orders = billsByCustomer[cid]!;
    final selectedIndex = selectedBillIndex[cid] ?? 0;
    final safeIndex = (selectedIndex < orders.length) ? selectedIndex : 0;
    final activeOrder = orders[safeIndex];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Text(
                    customer["name"].toString().substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer["name"] ?? "Unknown",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF566a7f),
                        ),
                      ),
                      Text(
                        "${customer["area"]} • ${customer["mobile"]}",
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),

          // Body
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFFAFAFA),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (orders.length > 1)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.3),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: safeIndex,
                        isExpanded: true,
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.primary,
                        ),
                        items: List.generate(orders.length, (i) {
                          final o = orders[i];
                          final date = DateFormat(
                            "dd MMM yyyy",
                          ).format(DateTime.parse(o["created_at"]));
                          final amt =
                              (double.tryParse(o["bill_amount"].toString()) ??
                                      0)
                                  .toStringAsFixed(0);
                          return DropdownMenuItem(
                            value: i,
                            child: Text(
                              "Order #${o["order_id"].toString().substring(max(0, o["order_id"].toString().length - 4))} ($date) - ₹$amt",
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF566a7f),
                              ),
                            ),
                          );
                        }),
                        onChanged: (val) {
                          if (val != null)
                            setState(() => selectedBillIndex[cid] = val);
                        },
                      ),
                    ),
                  ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Bill Amount",
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "₹${(double.tryParse(activeOrder["bill_amount"].toString()) ?? 0).toStringAsFixed(0)}",
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "Order ID",
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "#${activeOrder["order_id"]}",
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF566a7f),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        Icons.visibility_outlined,
                        "Preview",
                        () => _handlePdfAction(cid, 'preview'),
                        const Color(0xFF03C3EC),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildActionButton(
                        Icons.print_outlined,
                        "Print",
                        () => _handlePdfAction(cid, 'print'),
                        const Color(0xFF696CFF),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildActionButton(
                        Icons.download_rounded,
                        "Download",
                        () => _handlePdfAction(cid, 'download'),
                        const Color(0xFF71DD37),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String label,
    VoidCallback onTap,
    Color color,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        splashColor: color.withOpacity(0.2),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "No bills found",
            style: TextStyle(fontSize: 18, color: Colors.grey[500]),
          ),
          Text(
            "Select an area to fetch data",
            style: TextStyle(fontSize: 14, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  // ✅ Skeleton Loader Implementation
  Widget _buildSkeletonList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: 3,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (_, _) =>
          const SkeletalLoader(height: 200, borderRadius: 16),
    );
  }
}
