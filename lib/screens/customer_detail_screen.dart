import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../api/api_service.dart';
import '../utils/app_constants.dart';
import '../utils/ui_utils.dart';

class CustomerDetailScreen extends StatefulWidget {
  const CustomerDetailScreen({super.key});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen>
    with SingleTickerProviderStateMixin {
  final ApiService api = ApiService();
  late TabController _tabController;

  bool loading = true;
  String? errorMessage;

  Map<String, dynamic>? customer;
  List<dynamic> orders = [];
  List<dynamic> payments = [];
  late String customerId;

  bool _isInit = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args == null) {
        setState(() => loading = false);
        UIUtils.showErrorToast("No Customer ID provided");
        return;
      }
      customerId = args.toString();
      fetchCustomerDetails();
      _isInit = false;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> fetchCustomerDetails() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final results = await Future.wait([
        api.getCustomerById(customerId),
        api.getOrdersByCustomer(customerId),
        api.getPaymentsByCustomer(customerId),
      ]);

      if (!mounted) return;

      setState(() {
        customer = results[0].data;
        orders = results[1].data ?? [];
        payments = results[2].data ?? [];
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMessage = "Failed to load profile.";
      });
      String msg = "Unexpected error";
      if (e is DioException) {
        msg = e.response?.data["detail"]?.toString() ?? e.message ?? msg;
      }
      UIUtils.showErrorToast(msg);
    }
  }

  // -----------------------------
  // DATE FORMAT (DEVICE LOCAL - DATE ONLY)
  // -----------------------------
  String _formatDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return "N/A";
    try {
      final date = DateTime.parse(isoDate).toLocal();
      // Device timezone automatically applied
      return DateFormat('dd MMM yyyy').format(date);
      // Example: 08 Feb 2026
    } catch (e) {
      return isoDate;
    }
  }

  String _formatCurrency(dynamic amount) {
    double val = double.tryParse(amount?.toString() ?? "0") ?? 0.0;
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(val);
  }

  @override
  Widget build(BuildContext context) {
    final double topOffset = MediaQuery.of(context).size.height * 0.12;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Customer Profile", style: AppTypography.heading),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textHeading),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchCustomerDetails,
          ),
        ],
      ),
      body: loading
          ? _buildSkeletonLoader(topOffset)
          : customer == null
          ? _buildErrorState()
          : Column(
              children: [
                SizedBox(height: topOffset * 0.5),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.cardPadding,
                  ),
                  child: _buildProfileCard(),
                ),
                const SizedBox(height: 20),
                TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textMuted,
                  indicatorColor: AppColors.primary,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                  tabs: [
                    Tab(text: "ORDERS (${orders.length})"),
                    Tab(text: "PAYMENTS (${payments.length})"),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [_buildOrderList(), _buildPaymentList()],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildProfileCard() {
    final due =
        double.tryParse(customer?["current_due"]?.toString() ?? "0") ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Text(
              (customer?["name"] ?? "U")
                  .toString()
                  .substring(0, 1)
                  .toUpperCase(),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            customer?["name"] ?? "Unknown",
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textHeading,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.location_on,
                size: 14,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 4),
              Text(customer?["area"] ?? "N/A", style: AppTypography.label),
              const SizedBox(width: 12),
              const Icon(Icons.phone, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(customer?["mobile"] ?? "N/A", style: AppTypography.label),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 10),
          Column(
            children: [
              Text(
                "CURRENT DUE",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[500],
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _formatCurrency(due),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: due > 0 ? AppColors.danger : AppColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderList() {
    if (orders.isEmpty) return _buildEmptyState("No orders found");

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final order = orders[index];
        final total = _formatCurrency(order["total_amount"]);

        final status = (order["status"] ?? "").toString().toUpperCase();
        final isPaid = status == "CLOSED";

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
              vertical: 8,
            ),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                color: AppColors.primary,
              ),
            ),
            title: Text(
              total,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              _formatDate(order["created_at"]),
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (isPaid ? AppColors.success : AppColors.warning)
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isPaid ? "PAID" : "PENDING",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isPaid ? AppColors.success : AppColors.warning,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentList() {
    if (payments.isEmpty) return _buildEmptyState("No payments recorded");

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: payments.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final payment = payments[index];
        final amount = _formatCurrency(payment["amount"]);

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
              vertical: 8,
            ),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.attach_money_rounded,
                color: AppColors.success,
              ),
            ),
            title: Text(
              amount,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.success,
              ),
            ),
            subtitle: Text(
              _formatDate(payment["created_at"]),
              style: const TextStyle(fontSize: 12),
            ),
            trailing: const Icon(
              Icons.check_circle_outline,
              color: AppColors.success,
              size: 18,
            ),
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
          Icon(
            Icons.history_toggle_off_rounded,
            size: 48,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 12),
          Text(msg, style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
          const SizedBox(height: 12),
          const Text(
            "Could not load details",
            style: TextStyle(color: AppColors.textDark),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Go Back"),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoader(double topOffset) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          SizedBox(height: topOffset * 0.5),
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.primary.withOpacity(0.3),
              ),
            ),
          ),
          const SizedBox(height: 30),
          Expanded(
            child: ListView.separated(
              itemCount: 4,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, _) => Container(
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
