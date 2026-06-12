import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ For Status Bar Control
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../api/api_service.dart';
import '../utils/app_constants.dart';
import '../utils/ui_utils.dart'; // ✅ Using UIUtils
import '../utils/skeletal_loader.dart'; // ✅ Using Skeleton Loader

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> with WidgetsBindingObserver {
  final ApiService api = ApiService();

  bool isLoading = false;
  bool isAreaLoading = true;

  List<String> areas = [];
  String? selectedArea;

  // Data Maps
  final Map<String, Map<String, dynamic>> customerMap = {};
  final Map<String, List<Map<String, dynamic>>> billsByCustomer = {};

  // Payment State
  final Map<String, TextEditingController> amountControllers = {};
  final Map<String, String> paymentMode = {}; // 'FULL' or 'PARTIAL'

  // IST date tracking for midnight auto-reset
  String _currentIstDate = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentIstDate = _todayIstStr();
    loadAreas();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (var controller in amountControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }


  String _todayIstStr() {
    final ist = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    return '${ist.year}-${ist.month.toString().padLeft(2, '0')}-${ist.day.toString().padLeft(2, '0')}';
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final today = _todayIstStr();
      if (today != _currentIstDate) {
        // IST calendar day changed — clear today's data so stale data is not shown
        setState(() {
          _currentIstDate = today;
          billsByCustomer.clear();
          selectedArea = null;
        });
      }
    }
  }

  // 1. Fetch Areas
  Future<void> loadAreas() async {
    try {
      final res = await api.getCustomers();
      final List customers = res.data ?? [];

      setState(() {
        areas = customers
            .map<String>((c) => c["area"]?.toString() ?? "")
            .where((a) => a.isNotEmpty)
            .toSet()
            .toList();
        areas.sort();

        // Populate customer map for quick lookup
        for (var c in customers) {
          customerMap[c["id"]]?.addAll(c); // Update if exists
          customerMap.putIfAbsent(c["id"], () => c);
        }
        isAreaLoading = false;
      });
    } catch (e) {
      setState(() => isAreaLoading = false);
      // ✅ Using UIUtils
      UIUtils.showErrorToast("Failed to load areas");
    }
  }

  // 2. Fetch Bills for Area
  Future<void> fetchBills() async {
    if (selectedArea == null) {
      UIUtils.showErrorToast("Please select an area");
      return;
    }

    setState(() {
      isLoading = true;
      billsByCustomer.clear();
      amountControllers.clear();
    });

    try {
      final res = await api.getTodayBillsByArea(selectedArea!);
      final orders = List<Map<String, dynamic>>.from(res.data["orders"] ?? []);

      for (var o in orders) {
        final cid = o["customer_id"].toString();
        if (!billsByCustomer.containsKey(cid)) {
          billsByCustomer[cid] = [];
        }
        billsByCustomer[cid]!.add(o);

        // Initialize controllers and mode
        if (!amountControllers.containsKey(cid)) {
          amountControllers[cid] = TextEditingController();
          paymentMode[cid] = 'PARTIAL'; // Default to Partial so they can edit
        }
      }

      setState(() => isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      String msg = "Failed to fetch bills";
      if (e is DioException) {
        msg = e.response?.data["detail"]?.toString() ?? msg;
      }
      // ✅ Using UIUtils
      UIUtils.showErrorToast(msg);
    }
  }

  // 3. Process Payment
  Future<void> processPayment(String cid) async {
    final customer = customerMap[cid];
    final currentDue =
        double.tryParse(customer?["current_due"]?.toString() ?? "0") ?? 0;

    double amountToPay = 0;
    final mode = paymentMode[cid];

    if (mode == 'FULL') {
      amountToPay = currentDue;
    } else {
      // PARTIAL Logic
      final text = amountControllers[cid]?.text.trim() ?? "0";
      amountToPay = double.tryParse(text) ?? 0;
    }

    if (amountToPay <= 0) {
      UIUtils.showErrorToast("Please enter a valid payment amount");
      return;
    }

    // Confirmation Dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm Payment"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Customer: ${customer?["name"]}"),
            const SizedBox(height: 8),
            Text(
              "Amount: ${_formatCurrency(amountToPay)}",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppColors.primary,
              ),
            ),
            if (amountToPay == 0)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  "(Recording a zero payment)",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Confirm", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // API Call
    setState(() => isLoading = true);
    // ✅ Using UIUtils for Processing
    UIUtils.showProcessingSnackbar(context, message: "Processing payment...");

    try {
      await api.customerPayment(customerId: cid, amount: amountToPay);

      // ✅ Using UIUtils for Success
      UIUtils.showSuccessToast("Payment Recorded Successfully");

      // Clear input
      amountControllers[cid]?.clear();

      // Refresh Data
      await fetchBills();
      // Also refresh customer map to get new due amount
      final res = await api.getCustomers();
      setState(() {
        final list = res.data ?? [];
        for (var c in list) {
          customerMap[c["id"]] = c;
        }
      });
    } catch (e) {
      String msg = "Payment failed";
      if (e is DioException) {
        msg = e.response?.data["detail"]?.toString() ?? msg;
      }
      // ✅ Using UIUtils for Error
      UIUtils.showErrorToast(msg);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- HELPER: Formatting ---
  String _formatCurrency(dynamic amount) {
    double val = double.tryParse(amount?.toString() ?? "0") ?? 0.0;
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(val);
  }

  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // Positioning: 8% from top to be "20-25% upside from center"
    final double topOffset = size.height * 0.08;

    return Scaffold(
      backgroundColor: AppColors.background, // Sneat Background
      extendBodyBehindAppBar: true, // ✅ Content goes behind AppBar
      // ✅ 1. PRODUCTIVE SNEAT APP BAR
      appBar: AppBar(
        backgroundColor: AppColors.background.withOpacity(0.95),
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
          "Collect Payment",
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
              onPressed: selectedArea != null
                  ? () {
                      fetchBills();
                    }
                  : null,
              tooltip: "Refresh Bills",
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: selectedArea != null ? Colors.white : Colors.grey[200],
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.refresh_rounded,
                  size: 20,
                  color: selectedArea != null ? AppColors.primary : Colors.grey,
                ),
              ),
            ),
          ),
        ],
      ),

      body: Column(
        children: [
          // Spacer for AppBar + TopOffset
          SizedBox(
            height:
                kToolbarHeight +
                MediaQuery.of(context).padding.top +
                (topOffset * 0.5),
          ),

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
                              billsByCustomer.clear(); // Clear data
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: (isLoading || selectedArea == null)
                            ? null
                            : fetchBills,
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

          // 2. LIST OF CUSTOMERS WITH DUES
          Expanded(
            child: isLoading
                ? _buildSkeletonList() // ✅ Using SkeletalLoader
                : billsByCustomer.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.cardPadding,
                      vertical: 10,
                    ),
                    itemCount: billsByCustomer.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final cid = billsByCustomer.keys.elementAt(index);
                      return _buildPaymentCard(cid);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildPaymentCard(String cid) {
    final customer = customerMap[cid];
    final bills = billsByCustomer[cid] ?? [];
    final currentDue =
        double.tryParse(customer?["current_due"]?.toString() ?? "0") ?? 0;

    // Determine input mode
    final mode = paymentMode[cid] ?? 'PARTIAL';
    final isFull = mode == 'FULL';

    // If full, update controller text automatically for display
    if (isFull) {
      amountControllers[cid]?.text = currentDue.toStringAsFixed(0);
    }

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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer?["name"] ?? "Unknown",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textHeading,
                      ),
                    ),
                    Text(
                      "${bills.length} Bill(s) Today",
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.dueLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "TOTAL DUE",
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppColors.dueAmount.withOpacity(0.7),
                        ),
                      ),
                      Text(
                        _formatCurrency(currentDue),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Payment Input Section
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFFFAFAFA),
            child: Column(
              children: [
                // Toggle: Full vs Partial
                Row(
                  children: [
                    Expanded(child: _buildModeButton(cid, 'FULL', "Full Pay")),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildModeButton(cid, 'PARTIAL', "Partial"),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Input Field & Action Button
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: amountControllers[cid],
                        enabled:
                            !isFull, // Disable typing if Full Payment is selected
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: AppColors.textHeading,
                        ),
                        decoration: InputDecoration(
                          prefixText: "₹ ",
                          filled: true,
                          fillColor: isFull ? Colors.grey[200] : Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
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
                          labelText: isFull ? "Full Amount" : "Enter Amount",
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () => processPayment(cid),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 2,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
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

  Widget _buildModeButton(String cid, String mode, String label) {
    final isActive = (paymentMode[cid] ?? 'PARTIAL') == mode;

    return GestureDetector(
      onTap: () {
        setState(() {
          paymentMode[cid] = mode;
          if (mode == 'PARTIAL') {
            // Clear field if switching to partial to let user type
            amountControllers[cid]?.clear();
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? AppColors.primary : Colors.grey[300]!,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isActive ? Colors.white : Colors.grey[600],
            fontSize: 13,
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
          Icon(Icons.payments_outlined, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            selectedArea == null ? "Select an area" : "No pending bills found",
            style: TextStyle(color: Colors.grey[400], fontSize: 16),
          ),
        ],
      ),
    );
  }

  // ✅ Skeleton Loader Logic
  Widget _buildSkeletonList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.cardPadding,
        vertical: 10,
      ),
      itemCount: 3,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (_, _) => const SkeletalLoader(
        height: 220,
        width: double.infinity,
        borderRadius: 16,
      ),
    );
  }
}
