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
  @override State<CustomerDetailScreen> createState() => _CustomerDetailState();
}

class _CustomerDetailState extends State<CustomerDetailScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabs;

  bool    loading  = true;
  bool    _isInit  = true;
  String? _error;

  Map<String, dynamic>? customer;
  List<dynamic> orders   = [];
  List<dynamic> payments = [];
  late String   customerId;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      _isInit = false;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args == null) {
        setState(() => loading = false);
        UIUtils.showErrorToast('No customer ID provided');
        return;
      }
      customerId = args.toString();
      _loadAll();
    }
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _loadAll() async {
    setState(() { loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _api.getCustomerById(customerId),
        _api.getOrdersByCustomer(customerId),
        _api.getPaymentsByCustomer(customerId),
      ]).timeout(const Duration(seconds: 30));
      if (!mounted) return;
      setState(() {
        customer = Map<String, dynamic>.from(results[0].data ?? {});
        orders   = List<dynamic>.from(results[1].data ?? []);
        payments = List<dynamic>.from(results[2].data ?? []);
        loading  = false;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() { loading = false; _error = 'timeout'; });
    } catch (e) {
      if (!mounted) return;
      setState(() { loading = false; _error = 'error'; });
      if (e is DioException) {
        UIUtils.showErrorToast(
            e.response?.data?['detail']?.toString() ?? 'Failed to load profile');
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  double get _currentDue =>
      double.tryParse(customer?['current_due']?.toString() ?? '0') ?? 0;

  String _fmtCurrency(dynamic v) {
    final val = double.tryParse(v?.toString() ?? '0') ?? 0.0;
    return NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0)
        .format(val);
  }

  String _fmtDate(dynamic d) {
    if (d == null) return 'N/A';
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(d.toString()).toLocal());
    } catch (_) { return d.toString(); }
  }

  // ── Add Payment Dialog ────────────────────────────────────────────────────
  Future<void> _showAddPayment() async {
    final amtCtrl  = TextEditingController();
    final noteCtrl = TextEditingController();
    bool  saving   = false;
    String? amtErr;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final due = _currentDue;
          return Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                // Header
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.payment_rounded,
                        color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Add Payment',
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textHeading)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: AppColors.textMuted),
                    onPressed: () => Navigator.pop(ctx),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(customer?['name'] ?? '',
                    style: AppTypography.body.copyWith(color: AppColors.textMuted)),

                // Due badge
                if (due > 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                        color: AppColors.dueLight,
                        borderRadius:
                            BorderRadius.circular(AppDimensions.borderRadius),
                        border:
                            Border.all(color: AppColors.dueAmount.withOpacity(0.2))),
                    child: Row(children: [
                      const Icon(Icons.info_outline,
                          color: AppColors.dueAmount, size: 15),
                      const SizedBox(width: 6),
                      Text('Outstanding due: ${_fmtCurrency(due)}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.dueAmount)),
                    ]),
                  ),
                ] else ...[
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                        color: AppColors.successLight,
                        borderRadius:
                            BorderRadius.circular(AppDimensions.borderRadius)),
                    child: const Row(children: [
                      Icon(Icons.check_circle_outline,
                          color: AppColors.success, size: 15),
                      SizedBox(width: 6),
                      Text('No outstanding dues',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.success)),
                    ]),
                  ),
                ],

                const SizedBox(height: 18),

                // Amount field
                TextField(
                  controller: amtCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) {
                    if (amtErr != null) setS(() => amtErr = null);
                  },
                  decoration: _fieldDec('Amount (₹)',
                      Icons.currency_rupee, amtErr),
                ),
                const SizedBox(height: 12),

                // Note field
                TextField(
                  controller: noteCtrl,
                  decoration: _fieldDec('Note (optional)', Icons.note_outlined, null),
                ),
                const SizedBox(height: 20),

                // Buttons
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: saving ? null : () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textMuted,
                          side: const BorderSide(color: AppColors.borderColor),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppDimensions.borderRadius)),
                          padding: const EdgeInsets.symmetric(vertical: 13)),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: saving
                          ? null
                          : () async {
                              final raw = amtCtrl.text.trim();
                              if (raw.isEmpty) {
                                setS(() => amtErr = 'Amount is required');
                                return;
                              }
                              final amt = double.tryParse(raw);
                              if (amt == null || amt <= 0) {
                                setS(() => amtErr = 'Enter a valid amount');
                                return;
                              }
                              // Enforce due limit on frontend
                              if (due > 0 && amt > due) {
                                setS(() => amtErr =
                                    'Cannot exceed due ${_fmtCurrency(due)}');
                                return;
                              }
                              if (due <= 0) {
                                setS(() => amtErr = 'No outstanding due to pay');
                                return;
                              }
                              setS(() { saving = true; amtErr = null; });
                              try {
                                await _api.directPayment(
                                  customerId: customerId,
                                  amount: amt,
                                  note: noteCtrl.text.trim(),
                                );
                                if (!ctx.mounted) return;
                                Navigator.pop(ctx);
                                UIUtils.showSuccessToast(
                                    'Payment of ${_fmtCurrency(amt)} recorded');
                                _loadAll();
                              } catch (_) {
                                setS(() => saving = false);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppDimensions.borderRadius)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text('Save Payment',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ]),
              ]),
            ),
          );
        },
      ),
    );
  }

  InputDecoration _fieldDec(String label, IconData icon, String? error) =>
      InputDecoration(
        labelText: label,
        errorText: error,
        errorStyle: const TextStyle(fontSize: 11),
        prefixIcon: Icon(icon, size: 18, color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
            borderSide: const BorderSide(color: AppColors.borderColor)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
            borderSide: const BorderSide(color: AppColors.danger)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
            borderSide: const BorderSide(color: AppColors.danger, width: 1.5)),
      );

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Customer Profile',
            style: TextStyle(
                color: AppColors.textHeading,
                fontWeight: FontWeight.bold,
                fontSize: 17)),
        actions: [
          IconButton(
            onPressed: _loadAll,
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.primary, size: 22),
          ),
        ],
      ),
      body: loading
          ? _skeleton()
          : _error != null
              ? _errorState()
              : customer == null
                  ? _errorState()
                  : _body(),
    );
  }

  Widget _body() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 700;
        if (wide) {
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 300,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  _profileCard(),
                  const SizedBox(height: 12),
                  _addPaymentBtn(),
                ]),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: Column(children: [
              _tabBar(),
              Expanded(child: TabBarView(
                  controller: _tabs,
                  children: [_orderList(), _paymentList()])),
            ])),
          ]);
        }
        return Column(children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(children: [
                _profileCard(),
                const SizedBox(height: 12),
                _addPaymentBtn(),
                const SizedBox(height: 16),
              ]),
            ),
          ),
          _tabBar(),
          Expanded(child: TabBarView(
              controller: _tabs,
              children: [_orderList(), _paymentList()])),
        ]);
      },
    );
  }

  Widget _tabBar() => TabBar(
        controller: _tabs,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textMuted,
        indicatorColor: AppColors.primary,
        indicatorWeight: 2,
        labelStyle:
            const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        tabs: [
          Tab(text: 'ORDERS (${orders.length})'),
          Tab(text: 'PAYMENTS (${payments.length})'),
        ],
      );

  Widget _addPaymentBtn() => SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _showAddPayment,
          icon: const Icon(Icons.add_circle_outline, size: 18),
          label: const Text('Add Payment',
              style: TextStyle(fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 2,
            shadowColor: AppColors.primary.withOpacity(0.3),
            shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppDimensions.borderRadius)),
            padding: const EdgeInsets.symmetric(vertical: 13),
          ),
        ),
      );

  // ── Profile card ──────────────────────────────────────────────────────────
  Widget _profileCard() {
    final due = _currentDue;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
        boxShadow: cardShadow,
      ),
      child: Column(children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: AppColors.primaryLight,
          child: Text(
            (customer?['name'] ?? 'U').toString().substring(0, 1).toUpperCase(),
            style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primary),
          ),
        ),
        const SizedBox(height: 10),
        Text(customer?['name'] ?? 'Unknown',
            style: AppTypography.subheading, textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.location_on_outlined,
              size: 12, color: AppColors.textMuted),
          const SizedBox(width: 3),
          Text(customer?['area'] ?? 'N/A', style: AppTypography.caption),
          const SizedBox(width: 10),
          const Icon(Icons.phone_outlined, size: 12, color: AppColors.textMuted),
          const SizedBox(width: 3),
          Text(customer?['mobile'] ?? 'N/A', style: AppTypography.caption),
        ]),
        const SizedBox(height: 16),
        Divider(color: AppColors.divider),
        const SizedBox(height: 10),
        Text('CURRENT DUE',
            style: AppTypography.caption.copyWith(letterSpacing: 1.2)),
        const SizedBox(height: 4),
        Text(
          _fmtCurrency(due),
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: due > 0 ? AppColors.dueAmount : AppColors.success,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: due > 0 ? AppColors.dueLight : AppColors.successLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            due > 0 ? 'Pending' : 'Cleared',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: due > 0 ? AppColors.dueAmount : AppColors.success),
          ),
        ),
      ]),
    );
  }

  // ── Order list — status derived from order.status field ───────────────────
  Widget _orderList() {
    if (orders.isEmpty) return _empty('No orders found');
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final o = orders[i];
        // Use order status returned by backend — CLOSED = paid
        final rawStatus = (o['status'] ?? 'CREATED').toString().toUpperCase();
        final isPaid    = rawStatus == 'CLOSED';

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2))
            ],
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.receipt_long_rounded,
                  color: AppColors.primary, size: 20),
            ),
            title: Text(
              _fmtCurrency(o['total_amount']),
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.textHeading),
            ),
            subtitle: Text(_fmtDate(o['created_at']),
                style: AppTypography.caption),
            trailing: _statusBadge(
              isPaid ? 'PAID' : 'PENDING',
              isPaid ? AppColors.success : AppColors.warning,
              isPaid ? AppColors.successLight : AppColors.warningLight,
            ),
          ),
        );
      },
    );
  }

  // ── Payment list — premium dark for received, soft red for due ────────────
  Widget _paymentList() {
    if (payments.isEmpty) return _empty('No payments recorded');
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: payments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final p      = payments[i];
        final amt    = _fmtCurrency(p['amount']);
        final rawSt  = (p['payment_status'] ?? 'COMPLETE').toString().toUpperCase();
        final isDone = rawSt == 'COMPLETE';
        final note   = p['note']?.toString() ?? '';
        final isDirect = (p['payment_type'] ?? '').toString() == 'DIRECT_PAYMENT';

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2))
            ],
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                  color: AppColors.paidLight,
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.currency_rupee_rounded,
                  color: AppColors.paidAmount, size: 20),
            ),
            title: Text(
              amt,
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: AppColors.paidAmount),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_fmtDate(p['created_at']), style: AppTypography.caption),
                if (isDirect && note.isNotEmpty)
                  Text('Note: $note',
                      style: AppTypography.caption
                          .copyWith(fontStyle: FontStyle.italic)),
              ],
            ),
            trailing: _statusBadge(
              isDone ? 'RECEIVED' : rawSt,
              isDone ? AppColors.success : AppColors.warning,
              isDone ? AppColors.successLight : AppColors.warningLight,
            ),
          ),
        );
      },
    );
  }

  Widget _statusBadge(String label, Color fg, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.bold, color: fg)),
      );

  Widget _empty(String msg) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.history_toggle_off_rounded,
              size: 48, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text(msg, style: AppTypography.body.copyWith(color: AppColors.textMuted)),
        ]),
      );

  Widget _errorState() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.cloud_off_rounded,
              size: 56, color: AppColors.textMuted),
          const SizedBox(height: 12),
          const Text('Could not load details', style: AppTypography.body),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _loadAll,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white),
          ),
        ]),
      );

  Widget _skeleton() => ShimmerScope(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            const SizedBox(height: 8),
            const SkeletonProfileCard(),
            const SizedBox(height: 12),
            SkeletalLoader(height: 48, borderRadius: AppDimensions.borderRadius),
            const SizedBox(height: 16),
            SkeletalLoader(height: 40, borderRadius: AppDimensions.borderRadius),
            const SizedBox(height: 16),
            ...List.generate(
              4,
              (_) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SkeletalLoader(
                    height: 72,
                    borderRadius: AppDimensions.borderRadius),
              ),
            ),
          ]),
        ),
      );
}
