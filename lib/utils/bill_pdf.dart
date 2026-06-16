import 'dart:math';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

class BillPdf {
  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC: build a ready-to-add pw.Page from bill data.
  // Used by both single-bill and bulk-PDF flows.
  // ─────────────────────────────────────────────────────────────────────────
  static pw.Page buildPage({
    required String area,
    required String customerName,
    required String customerId,
    required String orderId,
    required String phone,
    required DateTime billDate,
    required List<Map<String, dynamic>> items,
    required double todayBill,
    required double previousDue,
  }) {
    final dateStr = DateFormat('dd-MM-yyyy').format(billDate);
    final grandTotal = todayBill + previousDue;

    final rand = Random();
    final prefix = rand.nextInt(9000) + 1000;
    final maskedCust = '$prefix-$customerId-C';
    final maskedOrder = '$prefix-$orderId-O';

    const colSl = 35.0;
    const colQty = 45.0;
    const colRate = 60.0;
    const colAmount = 80.0;

    final baseFont = items.length > 25 ? 7.0 : 8.5;
    final headerFont = items.length > 25 ? 10.0 : 12.0;

    return pw.Page(
      pageFormat: PdfPageFormat.a5.landscape,
      margin: const pw.EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      build: (pw.Context ctx) => pw.Container(
        decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
        padding: const pw.EdgeInsets.all(8),
        child: pw.Column(
          children: [
            pw.Center(
              child: pw.Text(
                'DELIVERY CHALLAN',
                style: pw.TextStyle(
                  fontSize: headerFont,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 5),

            // ── Header info ──────────────────────────────────────────────────
            pw.Container(
              padding: const pw.EdgeInsets.all(5),
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.8)),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    flex: 3,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _hRow('C/Name', customerName, baseFont + 1, bold: true),
                        _hRow('Ph. No', phone, baseFont),
                        _hRow('Area', area, baseFont),
                      ],
                    ),
                  ),
                  pw.Container(
                    width: 0.8,
                    height: 35,
                    color: PdfColors.black,
                    margin: const pw.EdgeInsets.symmetric(horizontal: 10),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _hRow('Date', dateStr, baseFont),
                        _hRow('C/ID', maskedCust, baseFont, bold: true),
                        _hRow('O/ID', maskedOrder, baseFont, bold: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 5),

            // ── Table ────────────────────────────────────────────────────────
            pw.Expanded(
              child: pw.Stack(
                children: [
                  // Background vertical dividers
                  pw.Positioned.fill(
                    child: pw.Row(
                      children: [
                        pw.SizedBox(width: colSl),
                        pw.VerticalDivider(
                          width: 0.8,
                          thickness: 0.8,
                          color: PdfColors.black,
                        ),
                        pw.Expanded(child: pw.SizedBox()),
                        pw.VerticalDivider(
                          width: 0.8,
                          thickness: 0.8,
                          color: PdfColors.black,
                        ),
                        pw.SizedBox(width: colQty),
                        pw.VerticalDivider(
                          width: 0.8,
                          thickness: 0.8,
                          color: PdfColors.black,
                        ),
                        pw.SizedBox(width: colRate),
                        pw.VerticalDivider(
                          width: 0.8,
                          thickness: 0.8,
                          color: PdfColors.black,
                        ),
                        pw.SizedBox(width: colAmount),
                      ],
                    ),
                  ),
                  // Table content
                  pw.Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(width: 0.8),
                    ),
                    child: pw.Column(
                      mainAxisSize: pw.MainAxisSize.max,
                      children: [
                        // Header row
                        pw.Container(
                          color: PdfColors.grey200,
                          child: pw.Row(
                            children: [
                              _cell(
                                'Sl.',
                                colSl,
                                baseFont,
                                bold: true,
                                center: true,
                              ),
                              pw.Expanded(
                                child: _cell(
                                  'Item',
                                  0,
                                  baseFont,
                                  bold: true,
                                  center: true,
                                ),
                              ),
                              _cell(
                                'Qty',
                                colQty,
                                baseFont,
                                bold: true,
                                center: true,
                              ),
                              _cell(
                                'Rate',
                                colRate,
                                baseFont,
                                bold: true,
                                center: true,
                              ),
                              _cell(
                                'Amount',
                                colAmount,
                                baseFont,
                                bold: true,
                                center: true,
                              ),
                            ],
                          ),
                        ),
                        pw.Divider(height: 0.8, thickness: 0.8),
                        // Data rows
                        ...items.asMap().entries.map(
                          (e) => pw.Row(
                            children: [
                              _cell(
                                '${e.key + 1}',
                                colSl,
                                baseFont,
                                center: true,
                              ),
                              pw.Expanded(
                                child: _cell(
                                  e.value['item_name'] ?? '',
                                  0,
                                  baseFont,
                                ),
                              ),
                              _cell(
                                e.value['quantity'].toString(),
                                colQty,
                                baseFont,
                                right: true,
                              ),
                              _cell(
                                _fmt(e.value['price'] ?? 0),
                                colRate,
                                baseFont,
                                right: true,
                              ),
                              _cell(
                                _fmt(e.value['total'] ?? 0),
                                colAmount,
                                baseFont,
                                right: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 15),

            // ── Footer ───────────────────────────────────────────────────────
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        _sigLine("Receiver's Signature", baseFont),
                        pw.SizedBox(width: 20),
                        _sigLine("Delivery Signature", baseFont),
                      ],
                    ),
                    pw.SizedBox(height: 10),
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 10),
                      child: pw.Text(
                        'THANK YOU',
                        style: pw.TextStyle(
                          fontSize: baseFont + 2,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                pw.Container(
                  width: 180,
                  padding: const pw.EdgeInsets.all(5),
                  decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
                  child: pw.Column(
                    children: [
                      _totRow(
                        'Bill Total',
                        _fmt(todayBill),
                        baseFont,
                        bold: true,
                      ),
                      _totRow('Prev. Due', _fmt(previousDue), baseFont),
                      pw.Divider(thickness: 1),
                      _totRow(
                        'GRAND TOTAL',
                        _fmt(grandTotal),
                        baseFont + 1,
                        bold: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC: generate a single-bill Document (backward compatible).
  // ─────────────────────────────────────────────────────────────────────────
  static pw.Document generate({
    required String area,
    required String customerName,
    required String customerId,
    required String orderId,
    required String phone,
    required DateTime billDate,
    required List<Map<String, dynamic>> items,
    required double todayBill,
    required double previousDue,
  }) {
    final doc = pw.Document();
    doc.addPage(
      buildPage(
        area: area,
        customerName: customerName,
        customerId: customerId,
        orderId: orderId,
        phone: phone,
        billDate: billDate,
        items: items,
        todayBill: todayBill,
        previousDue: previousDue,
      ),
    );
    return doc;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC: generate a multi-page bulk Document from a list of bill specs.
  // Each bill = one A5-landscape page. One document, one save(), one Uint8List.
  // ─────────────────────────────────────────────────────────────────────────
  static pw.Document generateBulk(List<BillSpec> specs) {
    final doc = pw.Document();
    for (final s in specs) {
      doc.addPage(
        buildPage(
          area: s.area,
          customerName: s.customerName,
          customerId: s.customerId,
          orderId: s.orderId,
          phone: s.phone,
          billDate: s.billDate,
          items: s.items,
          todayBill: s.todayBill,
          previousDue: s.previousDue,
        ),
      );
    }
    return doc;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE helpers
  // ─────────────────────────────────────────────────────────────────────────

  static pw.Widget _hRow(
    String label,
    String value,
    double size, {
    bool bold = false,
  }) => pw.Row(
    children: [
      pw.SizedBox(
        width: 45,
        child: pw.Text(label, style: pw.TextStyle(fontSize: size)),
      ),
      pw.Text(': ', style: pw.TextStyle(fontSize: size)),
      pw.Expanded(
        child: pw.Text(
          value,
          overflow: pw.TextOverflow.clip,
          style: pw.TextStyle(
            fontSize: size,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ),
    ],
  );

  static pw.Widget _cell(
    String t,
    double w,
    double s, {
    bool bold = false,
    bool center = false,
    bool right = false,
  }) => pw.Container(
    width: w > 0 ? w : null,
    padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
    child: pw.Text(
      t,
      textAlign: center
          ? pw.TextAlign.center
          : (right ? pw.TextAlign.right : pw.TextAlign.left),
      style: pw.TextStyle(
        fontSize: s,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );

  static pw.Widget _totRow(String l, String v, double s, {bool bold = false}) =>
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(l, style: pw.TextStyle(fontSize: s)),
          pw.Text(
            v,
            style: pw.TextStyle(
              fontSize: s,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      );

  static pw.Widget _sigLine(String label, double size) => pw.Column(
    children: [
      pw.Container(
        width: 100,
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(width: 0.5, style: pw.BorderStyle.dashed),
          ),
        ),
      ),
      pw.SizedBox(height: 2),
      pw.Text(label, style: pw.TextStyle(fontSize: size - 1)),
    ],
  );

  static String _fmt(num v) => NumberFormat('#,##0').format(v);
}

// ─────────────────────────────────────────────────────────────────────────────
// Data class: one bill's worth of data for bulk generation
// ─────────────────────────────────────────────────────────────────────────────
class BillSpec {
  const BillSpec({
    required this.area,
    required this.customerName,
    required this.customerId,
    required this.orderId,
    required this.phone,
    required this.billDate,
    required this.items,
    required this.todayBill,
    required this.previousDue,
  });

  final String area;
  final String customerName;
  final String customerId;
  final String orderId;
  final String phone;
  final DateTime billDate;
  final List<Map<String, dynamic>> items;
  final double todayBill;
  final double previousDue;
}
