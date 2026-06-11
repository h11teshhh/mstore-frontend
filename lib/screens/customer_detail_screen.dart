import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'dart:async';

import '../api/api_service.dart';
import '../utils/app_constants.dart';
import '../utils/ui_utils.dart';
import '../utils/skeletal_loader.dart';

class CustomerDetailScreen extends StatefulWidget {
  const CustomerDetailScreen({super.key});
  @override State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen>
    with SingleTickerProviderStateMixin {
  final ApiService api = ApiService();
  late TabController _tabController;

  bool loading  = true;
  bool _isInit  = true;
  String? errorMessage;

  Map<String, dynamic>? customer;
  List<dynamic> orders   = [];
  List<dynamic> payments = [];
  late String customerId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      _isInit = false;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args == null) { setState(() => loading = false); UIUtils.showErrorToast("No customer ID"); return; }
      customerId = args.toString();
      _loadAll();
    }
  }

  @override void dispose() { _tabController.dispose(); super.dispose(); }

  Future<void> _loadAll() async {
    setState(() { loading = true; errorMessage = null; });
    try {
      final results = await Future.wait([
        api.getCustomerById(customerId),
        api.getOrdersByCustomer(customerId),
        api.getPaymentsByCustomer(customerId),
      ]).timeout(const Duration(seconds: 30));
      if (!mounted) return;
      setState(() {
        customer = results[0].data;
        orders   = results[1].data ?? [];
        payments = results[2].data ?? [];
        loading  = false;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() { loading = false; errorMessage = "timeout"; });
    } catch (e) {
      if (!mounted) return;
      setState(() { loading = false; errorMessage = "error"; });
      if (e is DioException) {
        UIUtils.showErrorToast(e.response?.data["detail"]?.toString() ?? "Failed to load profile");
      }
    }
  }

  // ── Add Payment Dialog ────────────────────────────────────────────────
  Future<void> _showAddPaymentDialog() async {
    final amtCtrl  = TextEditingController();
    final noteCtrl = TextEditingController();
    bool  saving   = false;
    String? amtError;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final due = double.tryParse(customer?["current_due"]?.toString() ?? "0") ?? 0;
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Header
                Row(children: [
                  Container(padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.payment_rounded, color: AppColors.primary, size: 20)),
                  const SizedBox(width: 12),
                  const Expanded(child: Text("Add Payment",
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textHeading))),
                  IconButton(icon: const Icon(Icons.close, size: 20, color: AppColors.textMuted),
                      onPressed: () => Navigator.pop(ctx)),
                ]),
                const SizedBox(height: 4),
                Text("${customer?["name"] ?? ""}", style: AppTypography.body.copyWith(color: AppColors.textMuted)),
                if (due > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: AppColors.dueLight,
                        borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
                        border: Border.all(color: AppColors.dueAmount.withOpacity(0.2))),
                    child: Row(children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.dueAmount, size: 16),
                      const SizedBox(width: 6),
                      Text("Current due: ${_currency(due)}",
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.dueAmount)),
                    ]),
                  ),
                ],
                const SizedBox(height: 16),
                // Amount field
                TextField(
                  controller: amtCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) { if (amtError != null) setS(() => amtError = null); },
                  decoration: InputDecoration(
                    labelText: "Amount (₹)",
                    prefixIcon: const Icon(Icons.currency_rupee, size: 18, color: AppColors.textMuted),
                    errorText: amtError,
                    filled: true, fillColor: AppColors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
                        borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
                        borderSide: const BorderSide(color: AppColors.borderColor)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
                        borderSide: const BorderSide(color: AppColors.danger)),
                  ),
                ),
                const SizedBox(height: 12),
                // Note field
                TextField(
                  controller: noteCtrl,
                  decoration: InputDecoration(
                    labelText: "Note (optional)",
                    prefixIcon: const Icon(Icons.note_outlined, size: 18, color: AppColors.textMuted),
                    filled: true, fillColor: AppColors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
                        borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
                        borderSide: const BorderSide(color: AppColors.borderColor)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                  ),
                ),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: OutlinedButton(
                    onPressed: saving ? null : () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.textMuted,
                        side: const BorderSide(color: AppColors.borderColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.borderRadius)),
                        padding: const EdgeInsets.symmetric(vertical: 13)),
                    child: const Text("Cancel"),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: ElevatedButton(
                    onPressed: saving ? null : () async {
                      final rawAmt = amtCtrl.text.trim();
                      if (rawAmt.isEmpty) { setS(() => amtError = "Amount is required"); return; }
                      final amt = double.tryParse(rawAmt);
                      if (amt == null || amt <= 0) { setS(() => amtError = "Enter a valid amount"); return; }
                      setS(() { saving = true; amtError = null; });
                      try {
                        await api.directPayment(
                          customerId: customerId,
                          amount: amt,
                          note: noteCtrl.text.trim(),
                        );
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        UIUtils.showSuccessToast("Payment of ${_currency(amt)} recorded");
                        _loadAll();  // refresh profile
                      } catch (_) {
                        setS(() => saving = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.borderRadius)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("Save Payment", style: TextStyle(fontWeight: FontWeight.bold)),
                  )),
                ]),
              ]),
            ),
          );
        },
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────
  String _date(String? d) {
    if (d == null || d.isEmpty) return "N/A";
    try { return DateFormat('dd MMM yyyy').format(DateTime.parse(d).toLocal()); }
    catch (_) { return d; }
  }
  String _currency(dynamic v) {
    final val = double.tryParse(v?.toString() ?? "0") ?? 0.0;
    return NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(val);
  }

  @override
  Widget build(BuildContext context) {
    final isWide = AppDimensions.isTablet(context) || AppDimensions.isDesktop(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: AppColors.background.withOpacity(0.95),
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark),
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: IconButton(
            icon: Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6)]),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppColors.textDark)),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: const Text("Customer Profile",
            style: TextStyle(color: AppColors.textHeading, fontWeight: FontWeight.bold,
                fontSize: 18, fontFamily: 'PublicSans')),
        actions: [
          IconButton(
            onPressed: _loadAll,
            icon: Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6)]),
              child: const Icon(Icons.refresh_rounded, size: 18, color: AppColors.primary)),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: loading
          ? _skeleton()
          : errorMessage != null
          ? _errorState()
          : customer == null
          ? _errorState()
          : isWide
            ? _wideLayout()
            : _narrowLayout(),
    );
  }

  // ── Wide layout: profile left, tabs right ─────────────────────────────
  Widget _wideLayout() => SafeArea(
    child: Padding(
      padding: EdgeInsets.symmetric(
          horizontal: AppDimensions.horizontalPadding(context), vertical: 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 300, child: SingleChildScrollView(child: Column(children: [
          _profileCard(),
          const SizedBox(height: 16),
          _addPaymentBtn(),
        ]))),
        const SizedBox(width: 20),
        Expanded(child: Column(children: [
          _tabBar(),
          Expanded(child: TabBarView(controller: _tabController,
              children: [_orderList(), _paymentList()])),
        ])),
      ]),
    ),
  );

  // ── Narrow layout: stacked ────────────────────────────────────────────
  Widget _narrowLayout() => Column(children: [
    SizedBox(height: kToolbarHeight + MediaQuery.of(context).padding.top + 8),
    Expanded(child: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        _profileCard(),
        const SizedBox(height: 12),
        _addPaymentBtn(),
        const SizedBox(height: 16),
      ]),
    )),
    _tabBar(),
    Expanded(child: TabBarView(controller: _tabController,
        children: [_orderList(), _paymentList()])),
  ]);

  Widget _tabBar() => TabBar(
    controller: _tabController,
    labelColor: AppColors.primary,
    unselectedLabelColor: AppColors.textMuted,
    indicatorColor: AppColors.primary,
    indicatorWeight: 2,
    labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
    tabs: [Tab(text: "ORDERS (${orders.length})"), Tab(text: "PAYMENTS (${payments.length})")],
  );

  Widget _addPaymentBtn() => SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(
      onPressed: customer == null ? null : _showAddPaymentDialog,
      icon: const Icon(Icons.add_circle_outline, size: 18),
      label: const Text("Add Payment", style: TextStyle(fontWeight: FontWeight.w700)),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary, foregroundColor: Colors.white,
        elevation: 2, shadowColor: AppColors.primary.withOpacity(0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.borderRadius)),
        padding: const EdgeInsets.symmetric(vertical: 13),
      ),
    ),
  );

  // ── Profile card ──────────────────────────────────────────────────────
  Widget _profileCard() {
    final due = double.tryParse(customer?["current_due"]?.toString() ?? "0") ?? 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
        boxShadow: cardShadow,
      ),
      child: Column(children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(
            (customer?["name"] ?? "U").toString().substring(0, 1).toUpperCase(),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
        ),
        const SizedBox(height: 12),
        Text(customer?["name"] ?? "Unknown",
            style: AppTypography.subheading, textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.location_on_outlined, size: 13, color: AppColors.textMuted),
          const SizedBox(width: 3),
          Text(customer?["area"] ?? "N/A", style: AppTypography.caption),
          const SizedBox(width: 10),
          const Icon(Icons.phone_outlined, size: 13, color: AppColors.textMuted),
          const SizedBox(width: 3),
          Text(customer?["mobile"] ?? "N/A", style: AppTypography.caption),
        ]),
        const SizedBox(height: 18),
        Divider(color: AppColors.divider),
        const SizedBox(height: 12),
        Text("CURRENT DUE", style: AppTypography.caption.copyWith(letterSpacing: 1.2)),
        const SizedBox(height: 4),
        Text(_currency(due),
          style: TextStyle(
            fontSize: 28, fontWeight: FontWeight.w800,
            color: due > 0 ? AppColors.dueAmount : AppColors.success,
          ),
        ),
        if (due > 0) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.dueLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text("Pending", style: TextStyle(fontSize: 10,
                fontWeight: FontWeight.w600, color: AppColors.dueAmount)),
          ),
        ] else ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.successLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text("Cleared", style: TextStyle(fontSize: 10,
                fontWeight: FontWeight.w600, color: AppColors.success)),
          ),
        ],
      ]),
    );
  }

  // ── Order list ────────────────────────────────────────────────────────
  Widget _orderList() {
    if (orders.isEmpty) return _empty("No orders found");
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final o      = orders[i];
        final total  = _currency(o["total_amount"]);
        final isPaid = (o["status"] ?? "").toString().toUpperCase() == "CLOSED";
        return Container(
          decoration: BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 20),
            ),
            title: Text(total, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textHeading)),
            subtitle: Text(_date(o["created_at"]), style: AppTypography.caption),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: (isPaid ? AppColors.successLight : AppColors.warningLight),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(isPaid ? "PAID" : "PENDING",
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                      color: isPaid ? AppColors.success : AppColors.warning)),
            ),
          ),
        );
      },
    );
  }

  // ── Payment list — premium dark for paid, elegant red for due ─────────
  Widget _paymentList() {
    if (payments.isEmpty) return _empty("No payments recorded");
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: payments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final p      = payments[i];
        final amt    = _currency(p["amount"]);
        final status = (p["payment_status"] ?? "COMPLETE").toString().toUpperCase();
        final isDirect = (p["payment_type"] ?? "").toString() == "DIRECT_PAYMENT";
        final note   = p["note"] ?? "";
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: AppColors.paidLight, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.currency_rupee_rounded, color: AppColors.paidAmount, size: 20),
            ),
            title: Text(amt,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.paidAmount)),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_date(p["created_at"]), style: AppTypography.caption),
              if (isDirect && note.isNotEmpty)
                Text("Note: $note", style: AppTypography.caption.copyWith(fontStyle: FontStyle.italic)),
            ]),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.successLight, borderRadius: BorderRadius.circular(20)),
              child: Text(status == "COMPLETE" ? "RECEIVED" : status,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.success)),
            ),
          ),
        );
      },
    );
  }

  Widget _empty(String msg) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.history_toggle_off_rounded, size: 48, color: Colors.grey[300]),
    const SizedBox(height: 10),
    Text(msg, style: AppTypography.body.copyWith(color: AppColors.textMuted)),
  ]));

  Widget _errorState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.cloud_off_rounded, size: 56, color: AppColors.textMuted),
    const SizedBox(height: 12),
    const Text("Could not load details", style: AppTypography.body),
    const SizedBox(height: 12),
    ElevatedButton.icon(
      onPressed: _loadAll,
      icon: const Icon(Icons.refresh, size: 16),
      label: const Text("Retry"),
      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
    ),
  ]));

  Widget _skeleton() => SafeArea(child: ShimmerScope(child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(children: [
      const SizedBox(height: 8),
      const SkeletonProfileCard(),
      const SizedBox(height: 12),
      SkeletalLoader(height: 48, borderRadius: AppDimensions.borderRadius),
      const SizedBox(height: 16),
      SkeletalLoader(height: 40, borderRadius: AppDimensions.borderRadius),
      const SizedBox(height: 16),
      ...List.generate(4, (_) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: SkeletalLoader(height: 72, borderRadius: AppDimensions.borderRadius),
      )),
    ]),
  )));
}
