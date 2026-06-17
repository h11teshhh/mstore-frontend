import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ For Status Bar Control
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../api/api_service.dart';
import '../utils/app_constants.dart';
import '../utils/ui_utils.dart'; // ✅ Using UIUtils
import '../utils/skeletal_loader.dart'; // ✅ Using Skeleton Loader

class EndOfDayReportScreen extends StatefulWidget {
  const EndOfDayReportScreen({super.key});

  @override
  State<EndOfDayReportScreen> createState() => _EndOfDayReportScreenState();
}

class _EndOfDayReportScreenState extends State<EndOfDayReportScreen>
    with SingleTickerProviderStateMixin {
  final ApiService api = ApiService();
  late TabController _tabController;

  bool isLoading = true;
  Map<String, dynamic>? report;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    loadReport();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> loadReport() async {
    setState(() => isLoading = true);
    try {
      // Optional: Delay for skeleton effect
      // await Future.delayed(const Duration(milliseconds: 1200));

      final res = await api.getEndOfDaySummary();
      if (!mounted) return;

      AppToast.dismiss(); // clear refresh loading toast
      setState(() {
        report = res.data;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);

      String msg = "Failed to load report";
      if (e is DioException) {
        msg = e.response?.data["detail"]?.toString() ?? msg;
      }
      // ✅ Using UIUtils
      UIUtils.showSnackBar(context, msg, isError: true);
    }
  }

  // --- UI HELPERS ---
  String _formatCurrency(dynamic amount) {
    double val = double.tryParse(amount?.toString() ?? "0") ?? 0.0;
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(val);
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return "Today";
    try {
      // Assuming API returns YYYY-MM-DD
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  // --- MAIN BUILD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
                color: AppColors.textHeading,
              ),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: const Text(
          "End of Day Report",
          style: TextStyle(
            color: AppColors.textHeading,
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
              onPressed: () {
                UIUtils.showProcessingSnackbar(
                  context,
                  message: "Refreshing report...",
                );
                loadReport();
              },
              tooltip: "Refresh Report",
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

      body: isLoading
          ? _buildSkeletonLoader() // ✅ Using SkeletalLoader
          : report == null
          ? _buildErrorState()
          : Column(
              children: [
                // Spacer for AppBar
                SizedBox(
                  height:
                      kToolbarHeight + MediaQuery.of(context).padding.top + 20,
                ),

                // 1. FINANCIAL HIGHLIGHTS CARD
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.cardPadding,
                  ),
                  child: _buildFinancialCard(),
                ),

                const SizedBox(height: 20),

                // 2. TABS
                TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textMuted,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  tabs: const [
                    Tab(text: "STOCK SOLD"),
                    Tab(text: "PAYMENTS"),
                  ],
                ),

                // 3. TAB CONTENT
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [_buildStockList(), _buildCustomerList()],
                  ),
                ),
              ],
            ),
    );
  }

  // --- WIDGETS ---

  Widget _buildFinancialCard() {
    final received =
        double.tryParse(report!["cash_received_today"]?.toString() ?? "0") ?? 0;
    final expected =
        double.tryParse(report!["delivery_cash_expected"]?.toString() ?? "0") ??
        0;
    // Simple logic: If we got less than expected, show warning color
    final isShort = received < expected;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            "REPORT DATE",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey[400],
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatDate(report!["date"]),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textHeading,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      "COLLECTED",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatCurrency(received),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textHeading,
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 40, color: Colors.grey[200]),
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      "EXPECTED",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.info,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatCurrency(expected),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textHeading,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isShort) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: AppColors.danger,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "Short by ${_formatCurrency(expected - received)}",
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.danger,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStockList() {
    final stockList = report!["stock_sold"] as List? ?? [];

    if (stockList.isEmpty) return _buildEmptyState("No stock sold today");

    return ListView.separated(
      padding: const EdgeInsets.all(AppDimensions.cardPadding),
      itemCount: stockList.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = stockList[index];
        final qty = item["quantity_sold"] ?? 0;
        final name = item["item_name"] ?? "Unknown";

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 5),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withOpacity(0.1),
              child: Text(
                name.toString().substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
            title: Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.textHeading,
              ),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                "$qty Sold",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomerList() {
    final customerList = report!["customers"] as List? ?? [];

    if (customerList.isEmpty) return _buildEmptyState("No payments recorded");

    return ListView.separated(
      padding: const EdgeInsets.all(AppDimensions.cardPadding),
      itemCount: customerList.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final c = customerList[index];
        final paid = _formatCurrency(c["paid_today"]);
        final remaining =
            double.tryParse(c["remaining_due"]?.toString() ?? "0") ?? 0;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 5),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    c["customer_name"] ?? "Unknown",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.textHeading,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "Paid: $paid",
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Previous Due: ${_formatCurrency(c["previous_due"])}",
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Row(
                    children: [
                      Text(
                        "Remaining: ",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        _formatCurrency(remaining),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: remaining > 0
                              ? AppColors.danger
                              : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_outlined, size: 50, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(msg, style: TextStyle(color: Colors.grey[400], fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return const Center(child: Text("No data available for today"));
  }

  // --- SKELETON LOADER ---
  Widget _buildSkeletonLoader() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.cardPadding,
      ),
      child: Column(
        children: [
          SizedBox(
            height: kToolbarHeight + MediaQuery.of(context).padding.top + 20,
          ),
          // Financial Card Skeleton
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: const [
                SkeletalLoader(width: 80, height: 10),
                SizedBox(height: 10),
                SkeletalLoader(width: 120, height: 20),
                SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: SkeletalLoader(height: 40),
                    ),
                    SizedBox(width: 20),
                    Expanded(
                      child: SkeletalLoader(height: 40),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Tabs Skeleton
          Row(
            children: const [
              Expanded(
                child: SkeletalLoader(height: 40),
              ),
              SizedBox(width: 16),
              Expanded(
                child: SkeletalLoader(height: 40),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // List Skeletons
          Expanded(
            child: ListView.separated(
              itemCount: 4,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, _) => const SkeletalLoader(
                height: 80,
                width: double.infinity,
                borderRadius: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
