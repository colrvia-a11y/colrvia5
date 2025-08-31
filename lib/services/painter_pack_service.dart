import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/color_plan.dart';

class PainterPackService {
  Future<Uint8List> buildPdf(
      ColorPlan plan, Map<String, Map<String, String>> skuMap) async {
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      build: (ctx) => [
        pw.Header(level: 0, child: pw.Text(plan.name)),
        pw.Paragraph(text: plan.vibe),
        pw.Header(level: 1, child: pw.Text('SKUs & Sheens')),
        _skuTable(plan, skuMap),
        pw.Header(level: 1, child: pw.Text('Placement Map')),
        _placement(plan),
        pw.Header(level: 1, child: pw.Text('Do / Don\'t')),
        _doDont(plan),
        pw.Header(level: 1, child: pw.Text('Swatch Cards')),
        _swatches(plan),
      ],
    ));
    return doc.save();
  }

  pw.Widget _skuTable(
      ColorPlan plan, Map<String, Map<String, String>> skuMap) {
    final rows = <pw.TableRow>[
      pw.TableRow(children: [
        pw.Padding(
            padding: const pw.EdgeInsets.all(4), child: pw.Text('Color ID')),
        pw.Padding(
            padding: const pw.EdgeInsets.all(4), child: pw.Text('Surface')),
        pw.Padding(
            padding: const pw.EdgeInsets.all(4), child: pw.Text('Sheen')),
        pw.Padding(
            padding: const pw.EdgeInsets.all(4), child: pw.Text('Brand SKU')),
      ])
    ];
    for (final p in plan.placementMap) {
      final sku = skuMap[p.colorId]?[p.sheen] ?? '—';
      rows.add(pw.TableRow(children: [
        pw.Padding(
            padding: const pw.EdgeInsets.all(4), child: pw.Text(p.colorId)),
        pw.Padding(
            padding: const pw.EdgeInsets.all(4), child: pw.Text(p.area)),
        pw.Padding(
            padding: const pw.EdgeInsets.all(4), child: pw.Text(p.sheen)),
        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(sku)),
      ]));
    }
    return pw.Table(border: pw.TableBorder.all(width: 0.5), children: rows);
  }

  pw.Widget _placement(ColorPlan plan) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: plan.placementMap
          .map((p) =>
              pw.Text('• ${p.area}: ${p.colorId} (${p.sheen})'))
          .toList(),
    );
  }

  pw.Widget _doDont(ColorPlan plan) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: plan.doDont
          .map((d) => pw.Bullet(
              text: 'Do: ${d.doText}\nDon\'t: ${d.dontText}'))
          .toList(),
    );
  }

  pw.Widget _swatches(ColorPlan plan) {
    return pw.Wrap(
      spacing: 8,
      runSpacing: 8,
      children: plan.paletteColorIds.map((id) {
        return pw.Container(
          width: 150,
          padding: const pw.EdgeInsets.all(8),
          decoration:
              pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
          child: pw.Column(children: [
            pw.Container(
                height: 60,
                width: double.infinity,
                color: PdfColors.grey300), // TODO: real color sample
            pw.SizedBox(height: 6),
            pw.Text(id, style: const pw.TextStyle(fontSize: 12)),
          ]),
        );
      }).toList(),
    );
  }
}

