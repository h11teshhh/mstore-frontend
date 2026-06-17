import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw show Document;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../api/api_service.dart';
import '../utils/bill_pdf.dart';
import '../utils/app_constants.dart';
import '../utils/ui_utils.dart';
import '../utils/skeletal_loader.dart';

class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});
  @override State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  final ApiService api = ApiService();

  bool isLoading   = false;
  bool bulkLoading = false;

  List       customers = [];
  List<String> areas   = [];
  String?  selectedArea;

  final Map<String, Map<String, dynamic>>       customerMap     = {};
  final Map<String, List<Map<String, dynamic>>> billsByCustomer = {};
  final Map<String, int>                        selectedBillIdx = {};

  @override void initState() { super.initState(); _loadCustomers(); }

  // ── Load customers & build area list ─────────────────────────────────────
  Future<void> _loadCustomers() async {
    try {
      final res = await api.getCustomers();
      if (!mounted) return;
      setState(() {
        customers = res.data ?? [];
        areas.clear();
        for (final c in customers) {
          customerMap[c['id'].toString()] = Map<String, dynamic>.from(c);
          final a = c['area']?.toString();
          if (a != null && a.isNotEmpty && !areas.contains(a)) areas.add(a);
        }
        areas.sort();
      });
    } catch (_) {}
  }

  // ── Fetch bills for selected area ─────────────────────────────────────────
  Future<void> fetchBills() async {
    if (selectedArea == null) {
      UIUtils.showSnackBar(context, 'Please select an area first', isError: true);
      return;
    }
    setState(() {
      isLoading = true;
      billsByCustomer.clear();
      selectedBillIdx.clear();
    });
    try {
      final res    = await api.getTodayBillsByArea(selectedArea!);
      final orders = List<Map<String, dynamic>>.from(res.data['orders'] ?? []);
      for (final o in orders) {
        final cid = o['customer_id']?.toString();
        if (cid == null) continue;
        billsByCustomer.putIfAbsent(cid, () => []).add(o);
      }
      for (final cid in billsByCustomer.keys) {
        billsByCustomer[cid]!.sort((a, b) =>
            DateTime.parse(b['created_at'] ?? '2000-01-01')
                .compareTo(DateTime.parse(a['created_at'] ?? '2000-01-01')));
        selectedBillIdx[cid] = 0;
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ── Build BillSpec from map data ──────────────────────────────────────────
  BillSpec _specFor(String cid, int idx) {
    final c      = customerMap[cid]!;
    final order  = billsByCustomer[cid]![idx];
    final isLatest = idx == 0;
    final prevDue  = isLatest
        ? (double.tryParse(c['current_due']?.toString() ?? '0') ?? 0.0) -
          (double.tryParse(order['remaining_due']?.toString() ?? '0') ?? 0.0)
        : 0.0;
    return BillSpec(
      area:         c['area']?.toString()     ?? '',
      customerName: c['name']?.toString()     ?? '',
      customerId:   c['id']?.toString()       ?? '',
      orderId:      order['order_id']?.toString() ?? '',
      phone:        c['mobile']?.toString()   ?? '',
      billDate:     DateTime.tryParse(order['created_at'] ?? '') ?? DateTime.now(),
      items:        List<Map<String, dynamic>>.from(order['items'] ?? []),
      todayBill:    double.tryParse(order['bill_amount']?.toString() ?? '0') ?? 0,
      previousDue:  prevDue,
    );
  }

  // ── Single bill action ────────────────────────────────────────────────────
  Future<void> _handleAction(String cid, String action) async {
    final idx  = selectedBillIdx[cid] ?? 0;
    final spec = _specFor(cid, idx);
    final doc  = BillPdf.generate(
      area: spec.area, customerName: spec.customerName,
      customerId: spec.customerId, orderId: spec.orderId,
      phone: spec.phone, billDate: spec.billDate,
      items: spec.items, todayBill: spec.todayBill,
      previousDue: spec.previousDue,
    );

    switch (action) {
      case 'preview':
        await Navigator.push(context, MaterialPageRoute(
          builder: (_) => PdfPreview(
            build: (format) => doc.save(),
            canChangeOrientation: false,
            canChangePageFormat: false,
          ),
        ));
        break;

      case 'print':
        // LayoutCallback = FutureOr<Uint8List> Function(PdfPageFormat)
        // doc.save() returns Future<Uint8List> — correct type
        await Printing.layoutPdf(
          onLayout: (_) => doc.save(),
          name: 'Bill - ${spec.customerName}',
        );
        break;

      case 'download':
        final bytes = await doc.save(); // Uint8List
        await _saveToDevice(bytes, spec.customerName, spec.customerId);
        break;
    }
  }

  // ── BULK: all bills → one multi-page Document ─────────────────────────────
  // Correct approach for pdf 3.11.3:
  //   • Build one pw.Document, call addPage() for every bill page.
  //   • No cross-document page copying; no loadDocument(); no PdfObjectProxy.
  //   • save() returns Future<Uint8List> — matches LayoutCallback exactly.
  Future<pw.Document?> _buildBulkDoc() async {
    if (billsByCustomer.isEmpty) {
      UIUtils.showSnackBar(context, 'No bills loaded. Select an area first.', isError: true);
      return null;
    }

    // Collect all specs in order
    final specs = <BillSpec>[];
    for (final cid in billsByCustomer.keys) {
      final orders = billsByCustomer[cid]!;
      for (int i = 0; i < orders.length; i++) {
        specs.add(_specFor(cid, i));
      }
    }

    // generateBulk() creates one pw.Document with one addPage() call per bill
    return BillPdf.generateBulk(specs);
  }

  Future<void> _bulkPrint() async {
    setState(() => bulkLoading = true);
    try {
      final doc = await _buildBulkDoc();
      if (doc == null) return;
      // LayoutCallback: FutureOr<Uint8List> Function(PdfPageFormat)
      await Printing.layoutPdf(
        onLayout: (_) => doc.save(),
        name: 'All Bills - ${selectedArea ?? ""}',
      );
    } catch (_) {
      UIUtils.showSnackBar(context, 'Could not generate bulk print. Try individual prints.', isError: true);
    } finally {
      if (mounted) setState(() => bulkLoading = false);
    }
  }

  Future<void> _bulkPreview() async {
    setState(() => bulkLoading = true);
    try {
      final doc = await _buildBulkDoc();
      if (doc == null) return;
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(
        builder: (_) => PdfPreview(
          build: (format) => doc.save(),          // Future<Uint8List> ✅
          canChangeOrientation: false,
          canChangePageFormat: false,
        ),
      ));
    } catch (_) {
      UIUtils.showSnackBar(context, 'Preview failed. Try individual previews.', isError: true);
    } finally {
      if (mounted) setState(() => bulkLoading = false);
    }
  }

  Future<void> _bulkDownload() async {
    setState(() => bulkLoading = true);
    UIUtils.showProcessingSnackbar(context,
        message: 'Generating ${_totalBillCount()} bills…');
    try {
      final doc = await _buildBulkDoc();
      if (doc == null) return;
      final bytes   = await doc.save();          // Uint8List ✅
      final dateStr = DateFormat('ddMMMyyyy').format(DateTime.now());
      final name    = 'AllBills_${selectedArea ?? "Area"}_$dateStr';
      if (kIsWeb) {
        // Web: open print dialog for download
        await Printing.layoutPdf(
          onLayout: (_) async => bytes,
          name: name,
        );
      } else {
        await _saveToDevice(bytes, name, 'bulk');
      }
      AppToast.dismiss(); // clear generating toast on success
    } catch (_) {
      UIUtils.showSnackBar(context, 'Download failed. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => bulkLoading = false);
    }
  }

  int _totalBillCount() =>
      billsByCustomer.values.fold(0, (sum, list) => sum + list.length);

  // ── Save Uint8List to device Downloads ───────────────────────────────────
  Future<void> _saveToDevice(
      Uint8List bytes, String name, String id) async {
    try {
      if (kIsWeb) {
        await Printing.layoutPdf(
          onLayout: (_) async => bytes,
          name: name,
        );
        return;
      }

      bool granted = false;
      if (Platform.isAndroid) {
        final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
        granted = sdk >= 29 || (await Permission.storage.request()).isGranted;
      } else {
        granted = true;
      }

      if (!granted) {
        UIUtils.showSnackBar(context, 'Storage permission denied.', isError: true);
        return;
      }

      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download');
        if (!await dir.exists()) dir = await getExternalStorageDirectory();
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      final clean    = name.replaceAll(RegExp(r'[^\w\s]+'), '').trim();
      final date     = DateFormat('ddMMyy').format(DateTime.now());
      final fileName = 'Bill_${clean}_$date.pdf';
      await File('${dir!.path}/$fileName').writeAsBytes(bytes);
      UIUtils.showSnackBar(context, 'Saved: $fileName');
    } catch (_) {
      UIUtils.showSnackBar(context, 'Save failed. Please try again.', isError: true);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final hasBills = billsByCustomer.isNotEmpty;
    final isWide   = AppDimensions.isTablet(context) || AppDimensions.isDesktop(context);
    final hPad     = AppDimensions.horizontalPadding(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: AppColors.background.withOpacity(0.95),
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark),
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6)]),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 16, color: AppColors.textDark)),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: const Text('Bills & Reports',
            style: TextStyle(color: AppColors.textHeading, fontWeight: FontWeight.bold,
                fontSize: 18, fontFamily: 'PublicSans')),
        actions: [
          if (hasBills) ...[
            // Preview all
            Tooltip(
              message: 'Preview All Bills',
              child: IconButton(
                onPressed: bulkLoading ? null : _bulkPreview,
                icon: _appBarIconBox(
                  bulkLoading
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primary))
                      : const Icon(Icons.pageview_rounded, size: 18,
                          color: AppColors.primary),
                ),
              ),
            ),
            // Print all
            Tooltip(
              message: 'Print All Bills',
              child: IconButton(
                onPressed: bulkLoading ? null : _bulkPrint,
                icon: _appBarIconBox(
                  const Icon(Icons.print_rounded, size: 18, color: AppColors.info)),
              ),
            ),
            // Download all
            Tooltip(
              message: 'Download All Bills (1 PDF)',
              child: IconButton(
                onPressed: bulkLoading ? null : _bulkDownload,
                icon: _appBarIconBox(
                  const Icon(Icons.download_rounded, size: 18,
                      color: AppColors.success)),
              ),
            ),
          ],
          const SizedBox(width: 4),
        ],
      ),

      body: Column(children: [
        SizedBox(height: kToolbarHeight + MediaQuery.of(context).padding.top + 16),

        // ── Filter card ───────────────────────────────────────────────────
        Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: AppDimensions.cardMaxWidth(context)),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: Colors.white,
                  borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
                  boxShadow: cardShadow),
              child: isWide
                  ? Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Expanded(child: _areaDropdown()),
                      const SizedBox(width: 14),
                      SizedBox(width: 140, child: _fetchButton()),
                    ])
                  : Column(crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [_areaDropdown(), const SizedBox(height: 12), _fetchButton()]),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Bill list ─────────────────────────────────────────────────────
        Expanded(
          child: isLoading
              ? SkeletonCardList(count: 3, itemHeight: 200,
                  padding: EdgeInsets.symmetric(horizontal: hPad))
              : !hasBills
                  ? _emptyState()
                  : ListView.separated(
                      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 4),
                      itemCount: billsByCustomer.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (_, i) {
                        final cid = billsByCustomer.keys.elementAt(i);
                        return Center(child: ConstrainedBox(
                          constraints: BoxConstraints(
                              maxWidth: AppDimensions.cardMaxWidth(context)),
                          child: _billCard(cid),
                        ));
                      },
                    ),
        ),
      ]),
    );
  }

  Widget _appBarIconBox(Widget icon) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6)]),
    child: icon,
  );

  Widget _areaDropdown() => DropdownButtonFormField<String>(
    value: selectedArea,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: 'Select Area',
      labelStyle: AppTypography.label,
      prefixIcon: const Icon(Icons.map_outlined, color: AppColors.primary, size: 20),
      filled: true, fillColor: AppColors.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
          borderSide: const BorderSide(color: AppColors.borderColor)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    ),
    items: areas.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
    onChanged: (v) => setState(() { selectedArea = v; billsByCustomer.clear(); }),
  );

  Widget _fetchButton() => SizedBox(
    height: 48,
    child: ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary, foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadius)),
        elevation: 2, shadowColor: AppColors.primary.withOpacity(0.3)),
      icon: isLoading
          ? const SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : const Icon(Icons.search_rounded, size: 18),
      label: Text(isLoading ? 'Loading…' : 'GET BILLS', style: AppTypography.button),
      onPressed: isLoading ? null : fetchBills,
    ),
  );

  Widget _billCard(String cid) {
    final customer    = customerMap[cid]!;
    final orders      = billsByCustomer[cid]!;
    final safeIdx     = (selectedBillIdx[cid] ?? 0).clamp(0, orders.length - 1);
    final activeOrder = orders[safeIdx];

    return Container(
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
          boxShadow: cardShadow),
      child: Column(children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            CircleAvatar(
              backgroundColor: AppColors.primaryLight,
              child: Text(customer['name'].toString().substring(0, 1).toUpperCase(),
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(customer['name'] ?? 'Unknown',
                  style: const TextStyle(fontWeight: FontWeight.bold,
                      fontSize: 15, color: AppColors.textHeading)),
              Text('${customer['area']} · ${customer['mobile']}',
                  style: AppTypography.caption),
            ])),
            if (orders.length > 1)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.warningLight,
                    borderRadius: BorderRadius.circular(12)),
                child: Text('${orders.length} bills',
                    style: const TextStyle(fontSize: 10,
                        fontWeight: FontWeight.bold, color: AppColors.warning)),
              ),
          ]),
        ),
        Divider(height: 1, color: AppColors.divider),

        // Body
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Order selector (multi-bill customers only)
            if (orders.length > 1)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
                    border: Border.all(color: AppColors.primary.withOpacity(0.25))),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: safeIdx,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppColors.primary),
                    items: List.generate(orders.length, (i) {
                      final o    = orders[i];
                      final date = DateFormat('dd MMM')
                          .format(DateTime.parse(o['created_at']));
                      final amt  = (double.tryParse(
                              o['bill_amount'].toString()) ?? 0)
                          .toStringAsFixed(0);
                      final oid  = o['order_id'].toString();
                      final shortId = oid.substring(max(0, oid.length - 4));
                      return DropdownMenuItem(
                        value: i,
                        child: Text('Order #$shortId · $date · ₹$amt',
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.textHeading)),
                      );
                    }),
                    onChanged: (v) {
                      if (v != null) setState(() => selectedBillIdx[cid] = v);
                    },
                  ),
                ),
              ),

            // Bill amount + order id row
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Bill Amount', style: AppTypography.caption),
                const SizedBox(height: 3),
                Text(
                  '₹${(double.tryParse(activeOrder['bill_amount'].toString()) ?? 0).toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 22,
                      fontWeight: FontWeight.w800, color: AppColors.primary),
                ),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('Order ID', style: AppTypography.caption),
                const SizedBox(height: 3),
                Text('#${activeOrder['order_id']}',
                    style: const TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w600, color: AppColors.textDark)),
              ]),
            ]),
            const SizedBox(height: 14),

            // Action buttons
            Row(children: [
              Expanded(child: _actionBtn(Icons.visibility_outlined, 'Preview',
                  () => _handleAction(cid, 'preview'), AppColors.info)),
              const SizedBox(width: 8),
              Expanded(child: _actionBtn(Icons.print_outlined, 'Print',
                  () => _handleAction(cid, 'print'), AppColors.primary)),
              const SizedBox(width: 8),
              Expanded(child: _actionBtn(Icons.download_rounded, 'Download',
                  () => _handleAction(cid, 'download'), AppColors.success)),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap, Color color) =>
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: Colors.white,
                borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
                border: Border.all(color: color.withOpacity(0.4))),
            child: Column(children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 3),
              Text(label, style: TextStyle(fontSize: 11,
                  fontWeight: FontWeight.bold, color: color)),
            ]),
          ),
        ),
      );

  Widget _emptyState() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.receipt_long_outlined, size: 72, color: Colors.grey[200]),
      const SizedBox(height: 14),
      Text('No bills found',
          style: AppTypography.subheading.copyWith(color: AppColors.textMuted)),
      Text('Select an area and tap GET BILLS', style: AppTypography.caption),
    ],
  ));
}
