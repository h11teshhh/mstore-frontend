import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

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

  bool isLoading  = false;
  bool bulkLoading= false;
  List customers  = [];
  List<String> areas = [];
  String? selectedArea;

  final Map<String, Map<String, dynamic>>       customerMap     = {};
  final Map<String, List<Map<String, dynamic>>> billsByCustomer = {};
  final Map<String, int>                        selectedBillIdx = {};

  @override void initState() { super.initState(); _loadCustomers(); }

  Future<void> _loadCustomers() async {
    try {
      final res = await api.getCustomers();
      if (!mounted) return;
      setState(() {
        customers = res.data ?? [];
        areas.clear();
        for (final c in customers) {
          customerMap[c["id"].toString()] = c;
          final a = c["area"]?.toString();
          if (a != null && !areas.contains(a)) areas.add(a);
        }
        areas.sort();
      });
    } catch (_) {}
  }

  Future<void> fetchBills() async {
    if (selectedArea == null) { UIUtils.showErrorToast("Please select an area first"); return; }
    setState(() { isLoading = true; billsByCustomer.clear(); selectedBillIdx.clear(); });
    try {
      final res    = await api.getTodayBillsByArea(selectedArea!);
      final orders = List<Map<String, dynamic>>.from(res.data["orders"] ?? []);
      for (final o in orders) {
        final cid = o["customer_id"]?.toString();
        if (cid == null) continue;
        billsByCustomer.putIfAbsent(cid, () => []).add(o);
      }
      for (final cid in billsByCustomer.keys) {
        billsByCustomer[cid]!.sort((a, b) =>
            DateTime.parse(b["created_at"] ?? "2000-01-01")
                .compareTo(DateTime.parse(a["created_at"] ?? "2000-01-01")));
        selectedBillIdx[cid] = 0;
      }
    } catch (_) {
    } finally { if (mounted) setState(() => isLoading = false); }
  }

  // ── Single bill PDF ───────────────────────────────────────────────────
  pw.Document _buildSinglePdf(String cid, int index) {
    final customer = customerMap[cid]!;
    final order    = billsByCustomer[cid]![index];
    final isLatest = index == 0;
    final prevDue  = isLatest
        ? (double.tryParse(customer["current_due"]?.toString() ?? "0") ?? 0.0) -
          (double.tryParse(order["remaining_due"]?.toString() ?? "0") ?? 0.0)
        : 0.0;
    return BillPdf.generate(
      area: customer["area"]?.toString() ?? "",
      customerName: customer["name"]?.toString() ?? "",
      customerId: customer["id"]?.toString() ?? "",
      orderId: order["order_id"]?.toString() ?? "",
      phone: customer["mobile"]?.toString() ?? "",
      billDate: DateTime.tryParse(order["created_at"] ?? "") ?? DateTime.now(),
      items: List<Map<String, dynamic>>.from(order["items"] ?? []),
      todayBill: double.tryParse(order["bill_amount"]?.toString() ?? "0") ?? 0,
      previousDue: prevDue,
    );
  }

  Future<void> _handleAction(String cid, String action) async {
    final idx = selectedBillIdx[cid] ?? 0;
    final pdf = _buildSinglePdf(cid, idx);
    final customer = customerMap[cid]!;
    switch (action) {
      case 'preview':
        await Navigator.push(context, MaterialPageRoute(builder: (_) =>
            PdfPreview(build: (f) async => pdf.save(),
                canChangeOrientation: false, canChangePageFormat: false)));
        break;
      case 'print':
        await Printing.layoutPdf(onLayout: (_) async => pdf.save());
        break;
      case 'download':
        await _savePdf(await pdf.save(),
            customer["name"]?.toString() ?? "Customer",
            customer["id"]?.toString() ?? "0");
        break;
    }
  }

  // ── BULK: combine all today's bills into one multi-page PDF ──────────
  Future<void> _bulkPrintAll() async {
    if (billsByCustomer.isEmpty) {
      UIUtils.showErrorToast("No bills loaded. Select an area first.");
      return;
    }
    setState(() => bulkLoading = true);
    UIUtils.showProcessingSnackbar(context, message: "Combining ${billsByCustomer.length} bills…");
    try {
      final combined = pw.Document();
      for (final cid in billsByCustomer.keys) {
        final customer = customerMap[cid];
        if (customer == null) continue;
        final orders   = billsByCustomer[cid]!;
        for (int i = 0; i < orders.length; i++) {
          final order    = orders[i];
          final isLatest = i == 0;
          final prevDue  = isLatest
              ? (double.tryParse(customer["current_due"]?.toString() ?? "0") ?? 0.0) -
                (double.tryParse(order["remaining_due"]?.toString() ?? "0") ?? 0.0)
              : 0.0;
          // Build a single-page document and copy its page
          final singleDoc = BillPdf.generate(
            area: customer["area"]?.toString() ?? "",
            customerName: customer["name"]?.toString() ?? "",
            customerId: customer["id"]?.toString() ?? "",
            orderId: order["order_id"]?.toString() ?? "",
            phone: customer["mobile"]?.toString() ?? "",
            billDate: DateTime.tryParse(order["created_at"] ?? "") ?? DateTime.now(),
            items: List<Map<String, dynamic>>.from(order["items"] ?? []),
            todayBill: double.tryParse(order["bill_amount"]?.toString() ?? "0") ?? 0,
            previousDue: prevDue,
          );
          // Extract first page from single doc and add to combined
          final singleBytes = await singleDoc.save();
          final imported    = await combined.loadDocument(data: singleBytes);
          final page        = imported.page(0);
          combined.addPage(pw.Page(
            pageFormat: PdfPageFormat.a5.landscape,
            build: (_) => pw.FullPage(ignoreMargins: true,
                child: pw.PdfObjectProxy(page)),
          ));
        }
      }
      final bytes   = await combined.save();
      final dateStr = DateFormat('ddMMMyyyy').format(DateTime.now());
      if (kIsWeb) {
        // Web: use Printing to trigger download
        await Printing.layoutPdf(onLayout: (_) async => bytes);
      } else {
        await _savePdf(bytes, "AllBills_$dateStr", "bulk");
      }
    } catch (e) {
      UIUtils.showErrorToast("Could not generate bulk PDF. Try individual downloads.");
    } finally {
      if (mounted) setState(() => bulkLoading = false);
    }
  }

  Future<void> _bulkPrintPreview() async {
    if (billsByCustomer.isEmpty) {
      UIUtils.showErrorToast("No bills loaded.");
      return;
    }
    setState(() => bulkLoading = true);
    try {
      // Collect all bill bytes; build multi-page by printing all via Printing
      final combined = pw.Document();
      for (final cid in billsByCustomer.keys) {
        final customer = customerMap[cid];
        if (customer == null) continue;
        final orders   = billsByCustomer[cid]!;
        for (int i = 0; i < orders.length; i++) {
          final order   = orders[i];
          final prevDue = i == 0
              ? (double.tryParse(customer["current_due"]?.toString() ?? "0") ?? 0.0) -
                (double.tryParse(order["remaining_due"]?.toString() ?? "0") ?? 0.0)
              : 0.0;
          final doc = BillPdf.generate(
            area: customer["area"]?.toString() ?? "",
            customerName: customer["name"]?.toString() ?? "",
            customerId: customer["id"]?.toString() ?? "",
            orderId: order["order_id"]?.toString() ?? "",
            phone: customer["mobile"]?.toString() ?? "",
            billDate: DateTime.tryParse(order["created_at"] ?? "") ?? DateTime.now(),
            items: List<Map<String, dynamic>>.from(order["items"] ?? []),
            todayBill: double.tryParse(order["bill_amount"]?.toString() ?? "0") ?? 0,
            previousDue: prevDue,
          );
          final bytes    = await doc.save();
          final imported = await combined.loadDocument(data: bytes);
          final page     = imported.page(0);
          combined.addPage(pw.Page(
            pageFormat: PdfPageFormat.a5.landscape,
            build: (_) => pw.FullPage(ignoreMargins: true,
                child: pw.PdfObjectProxy(page)),
          ));
        }
      }
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) =>
          PdfPreview(build: (f) async => combined.save(),
              canChangeOrientation: false, canChangePageFormat: false)));
    } catch (_) {
      UIUtils.showErrorToast("Preview failed. Try individual previews.");
    } finally {
      if (mounted) setState(() => bulkLoading = false);
    }
  }

  Future<void> _savePdf(List<int> bytes, String name, String id) async {
    try {
      bool granted = false;
      if (kIsWeb) {
        await Printing.layoutPdf(onLayout: (_) async => bytes);
        return;
      }
      if (Platform.isAndroid) {
        final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
        if (sdk >= 29) { granted = true; }
        else {
          final s = await Permission.storage.request();
          granted = s.isGranted;
        }
      } else { granted = true; }
      if (!granted) { UIUtils.showErrorToast("Storage permission denied"); return; }
      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download');
        if (!await dir.exists()) dir = await getExternalStorageDirectory();
      } else { dir = await getApplicationDocumentsDirectory(); }
      final date    = DateFormat('ddMMyy').format(DateTime.now());
      final clean   = name.replaceAll(RegExp(r'[^\w\s]+'), '');
      final path    = "${dir!.path}/Bill_${clean}_${id}_$date.pdf";
      await File(path).writeAsBytes(bytes);
      UIUtils.showSuccessToast("Saved: Bill_${clean}_$date.pdf");
    } catch (e) {
      UIUtils.showErrorToast("Save failed. Please try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = AppDimensions.isTablet(context) || AppDimensions.isDesktop(context);
    final hPad   = AppDimensions.horizontalPadding(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: AppColors.background.withOpacity(0.95),
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark),
        leading: Padding(padding: const EdgeInsets.only(left: 8), child: IconButton(
          icon: Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6)]),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppColors.textDark)),
          onPressed: () => Navigator.pop(context))),
        title: const Text("Bills & Reports",
          style: TextStyle(color: AppColors.textHeading, fontWeight: FontWeight.bold,
              fontSize: 18, fontFamily: 'PublicSans')),
        actions: [
          if (billsByCustomer.isNotEmpty) ...[
            // Bulk Print
            Tooltip(message: "Print All Bills",
              child: IconButton(
                onPressed: bulkLoading ? null : _bulkPrintPreview,
                icon: Container(padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6)]),
                  child: bulkLoading
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                      : const Icon(Icons.print_rounded, size: 18, color: AppColors.primary)),
              )),
            // Bulk Download
            Tooltip(message: "Download All Bills (1 PDF)",
              child: IconButton(
                onPressed: bulkLoading ? null : _bulkPrintAll,
                icon: Container(padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6)]),
                  child: const Icon(Icons.download_rounded, size: 18, color: AppColors.success)),
              )),
          ],
          const SizedBox(width: 4),
        ],
      ),
      body: Column(children: [
        SizedBox(height: kToolbarHeight + MediaQuery.of(context).padding.top + 16),
        // Filter card
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
                    SizedBox(width: 140, child: _fetchBtn()),
                  ])
                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    _areaDropdown(),
                    const SizedBox(height: 12),
                    _fetchBtn(),
                  ]),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Bill list
        Expanded(
          child: isLoading
              ? SkeletonCardList(count: 3, itemHeight: 200, padding: EdgeInsets.symmetric(horizontal: hPad))
              : billsByCustomer.isEmpty
                ? _empty()
                : ListView.separated(
                    padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 4),
                    itemCount: billsByCustomer.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (_, i) => Center(child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: AppDimensions.cardMaxWidth(context)),
                      child: _billCard(billsByCustomer.keys.elementAt(i)),
                    )),
                  ),
        ),
      ]),
    );
  }

  Widget _areaDropdown() => DropdownButtonFormField<String>(
    decoration: InputDecoration(
      labelText: "Select Area",
      labelStyle: AppTypography.label,
      prefixIcon: const Icon(Icons.map_outlined, color: AppColors.primary, size: 20),
      filled: true, fillColor: AppColors.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
          borderSide: const BorderSide(color: AppColors.borderColor)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    ),
    value: selectedArea,
    isExpanded: true,
    items: areas.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
    onChanged: (v) => setState(() { selectedArea = v; billsByCustomer.clear(); }),
  );

  Widget _fetchBtn() => SizedBox(height: 48, child: ElevatedButton.icon(
    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.borderRadius)),
        elevation: 2, shadowColor: AppColors.primary.withOpacity(0.3)),
    icon: isLoading
        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
        : const Icon(Icons.search_rounded, size: 18),
    label: Text(isLoading ? "Loading…" : "GET BILLS", style: AppTypography.button),
    onPressed: isLoading ? null : fetchBills,
  ));

  Widget _billCard(String cid) {
    final customer   = customerMap[cid]!;
    final orders     = billsByCustomer[cid]!;
    final safeIdx    = (selectedBillIdx[cid] ?? 0).clamp(0, orders.length - 1);
    final activeOrder= orders[safeIdx];

    return Container(
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
          boxShadow: cardShadow),
      child: Column(children: [
        // Header
        Padding(padding: const EdgeInsets.all(16), child: Row(children: [
          CircleAvatar(
            backgroundColor: AppColors.primaryLight,
            child: Text(customer["name"].toString().substring(0,1).toUpperCase(),
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(customer["name"] ?? "Unknown",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textHeading)),
            Text("${customer["area"]} · ${customer["mobile"]}",
                style: AppTypography.caption),
          ])),
          // Bill count badge
          if (orders.length > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(12)),
              child: Text("${orders.length} bills",
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.warning)),
            ),
        ])),
        Divider(height: 1, color: AppColors.divider),
        // Body
        Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Order selector
          if (orders.length > 1)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
                  border: Border.all(color: AppColors.primary.withOpacity(0.25))),
              child: DropdownButtonHideUnderline(child: DropdownButton<int>(
                value: safeIdx, isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
                items: List.generate(orders.length, (i) {
                  final o    = orders[i];
                  final date = DateFormat("dd MMM").format(DateTime.parse(o["created_at"]));
                  final amt  = (double.tryParse(o["bill_amount"].toString()) ?? 0).toStringAsFixed(0);
                  return DropdownMenuItem(value: i,
                      child: Text("Order #${o["order_id"].toString().substring(max(0, o["order_id"].toString().length-4))} · $date · ₹$amt",
                          style: const TextStyle(fontSize: 13, color: AppColors.textHeading)));
                }),
                onChanged: (v) { if (v != null) setState(() => selectedBillIdx[cid] = v); },
              )),
            ),
          // Bill amount + order id
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Bill Amount", style: AppTypography.caption),
              const SizedBox(height: 3),
              Text("₹${(double.tryParse(activeOrder["bill_amount"].toString()) ?? 0).toStringAsFixed(0)}",
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primary)),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text("Order ID", style: AppTypography.caption),
              const SizedBox(height: 3),
              Text("#${activeOrder["order_id"]}",
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
            ]),
          ]),
          const SizedBox(height: 14),
          // Action buttons
          Row(children: [
            Expanded(child: _actionBtn(Icons.visibility_outlined, "Preview",
                () => _handleAction(cid, 'preview'), AppColors.info)),
            const SizedBox(width: 8),
            Expanded(child: _actionBtn(Icons.print_outlined, "Print",
                () => _handleAction(cid, 'print'), AppColors.primary)),
            const SizedBox(width: 8),
            Expanded(child: _actionBtn(Icons.download_rounded, "Download",
                () => _handleAction(cid, 'download'), AppColors.success)),
          ]),
        ])),
      ]),
    );
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap, Color color) =>
      Material(color: Colors.transparent, child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
              border: Border.all(color: color.withOpacity(0.4))),
          child: Column(children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
          ]),
        ),
      ));

  Widget _empty() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.receipt_long_outlined, size: 72, color: Colors.grey[200]),
    const SizedBox(height: 14),
    Text("No bills found", style: AppTypography.subheading.copyWith(color: AppColors.textMuted)),
    Text("Select an area and tap GET BILLS", style: AppTypography.caption),
  ]));
}
