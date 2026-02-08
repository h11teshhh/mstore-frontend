import 'dart:math';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

class BillPdf {
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
    final pdf = pw.Document();
    final dateStr = DateFormat('dd-MM-yyyy').format(billDate);
    final grandTotal = todayBill + previousDue;

    final random = Random();
    final randPrefix = random.nextInt(9000) + 1000;
    final maskedCustomer = '$randPrefix-$customerId-C';
    final maskedOrder = '$randPrefix-$orderId-O';

    const colSl = 35.0;
    const colQty = 45.0;
    const colRate = 60.0;
    const colAmount = 80.0;

    double baseFont = items.length > 25 ? 7.0 : 8.5;
    double headerFont = items.length > 25 ? 10.0 : 12.0;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5.landscape,
        margin: const pw.EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        build: (pw.Context context) {
          return pw.Container(
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

                // Updated Header Information with Alignment
                pw.Container(
                  padding: const pw.EdgeInsets.all(5),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 0.8),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        flex: 3,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _headerRow(
                              'C/Name',
                              customerName,
                              baseFont + 1,
                              isBold: true,
                            ),
                            _headerRow('Ph. No', phone, baseFont),
                            _headerRow('Area', area, baseFont),
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
                            _headerRow('Date', dateStr, baseFont),
                            _headerRow(
                              'C/ID',
                              maskedCustomer,
                              baseFont,
                              isBold: true,
                            ),
                            _headerRow(
                              'O/ID',
                              maskedOrder,
                              baseFont,
                              isBold: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 5),

                // Table Section
                // Table Section
                pw.Expanded(
                  child: pw.Stack(
                    children: [
                      // BACKGROUND VERTICAL LINES (Stretches to fill)
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

                      // OUTER BORDER AND CONTENT
                      pw.Container(
                        width: double.infinity,
                        height: double
                            .infinity, // Forces container to fill Expanded space
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(width: 0.8),
                        ),
                        child: pw.Column(
                          mainAxisSize: pw
                              .MainAxisSize
                              .max, // Forces column to use full height
                          children: [
                            // Header Row
                            pw.Container(
                              color: PdfColors.grey200,
                              child: pw.Row(
                                children: [
                                  _box(
                                    'Sl.',
                                    colSl,
                                    baseFont,
                                    bold: true,
                                    center: true,
                                  ),
                                  pw.Expanded(
                                    child: _box(
                                      'Item',
                                      0,
                                      baseFont,
                                      bold: true,
                                      center: true,
                                    ),
                                  ),
                                  _box(
                                    'Qty',
                                    colQty,
                                    baseFont,
                                    bold: true,
                                    center: true,
                                  ),
                                  _box(
                                    'Rate',
                                    colRate,
                                    baseFont,
                                    bold: true,
                                    center: true,
                                  ),
                                  _box(
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

                            // Item Rows
                            ...items.asMap().entries.map(
                              (e) => pw.Row(
                                children: [
                                  _box(
                                    '${e.key + 1}',
                                    colSl,
                                    baseFont,
                                    center: true,
                                  ),
                                  pw.Expanded(
                                    child: _box(
                                      e.value['item_name'] ?? '',
                                      0,
                                      baseFont,
                                    ),
                                  ),
                                  _box(
                                    e.value['quantity'].toString(),
                                    colQty,
                                    baseFont,
                                    right: true,
                                  ),
                                  _box(
                                    _format(e.value['price'] ?? 0),
                                    colRate,
                                    baseFont,
                                    right: true,
                                  ),
                                  _box(
                                    _format(e.value['total'] ?? 0),
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

                pw.SizedBox(height: 5),

                // Footer Section
                pw.SizedBox(height: 15),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    // Signatures and Thank You on the left
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          children: [
                            pw.Column(
                              children: [
                                pw.Container(
                                  width: 100,
                                  // FIXED: Use decoration instead of border
                                  decoration: const pw.BoxDecoration(
                                    border: pw.Border(
                                      bottom: pw.BorderSide(
                                        width: 0.5,
                                        style: pw.BorderStyle.dashed,
                                      ),
                                    ),
                                  ),
                                ),
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  "Receiver's Signature",
                                  style: pw.TextStyle(fontSize: baseFont - 1),
                                ),
                              ],
                            ),
                            pw.SizedBox(width: 20),
                            pw.Column(
                              children: [
                                pw.Container(
                                  width: 100,
                                  // FIXED: Use decoration instead of border
                                  decoration: const pw.BoxDecoration(
                                    border: pw.Border(
                                      bottom: pw.BorderSide(
                                        width: 0.5,
                                        style: pw.BorderStyle.dashed,
                                      ),
                                    ),
                                  ),
                                ),
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  "Delivery Signature",
                                  style: pw.TextStyle(fontSize: baseFont - 1),
                                ),
                              ],
                            ),
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

                    // Totals on the right
                    pw.Container(
                      width: 180,
                      padding: const pw.EdgeInsets.all(5),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(width: 1),
                      ),
                      child: pw.Column(
                        children: [
                          _totalRow(
                            'Bill Total',
                            _format(todayBill),
                            baseFont,
                            bold: true,
                          ),
                          _totalRow(
                            'Prev. Due',
                            _format(previousDue),
                            baseFont,
                          ),
                          pw.Divider(thickness: 1),
                          _totalRow(
                            'GRAND TOTAL',
                            _format(grandTotal),
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
          );
        },
      ),
    );
    return pdf;
  }

  // Helper for aligned header rows
  static pw.Widget _headerRow(
    String label,
    String value,
    double size, {
    bool isBold = false,
  }) {
    return pw.Row(
      children: [
        pw.SizedBox(
          width: 45,
          child: pw.Text(label, style: pw.TextStyle(fontSize: size)),
        ),
        pw.Text(': ', style: pw.TextStyle(fontSize: size)),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: size,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
            overflow: pw.TextOverflow.clip,
          ),
        ),
      ],
    );
  }

  static pw.Widget _box(
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

  static pw.Widget _totalRow(
    String l,
    String v,
    double s, {
    bool bold = false,
  }) => pw.Row(
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

  static String _format(num v) => NumberFormat('#,##0').format(v);
}
