import 'package:flutter/material.dart';

import 'api.dart';
import 'theme.dart';
import 'wds.dart';
import 'widgets.dart';

/// Opens the full invoice details (same information as the Compact Invoice form).
void openInvoiceDetails(BuildContext context, int moveId) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => InvoiceFullScreen(moveId: moveId)));

/// "عرض التفاصيل" button used in invoices, orders and returns.
class InvoiceDetailsButton extends StatelessWidget {
  const InvoiceDetailsButton({super.key, required this.moveId, this.label = 'عرض تفاصيل الفاتورة'});
  final int moveId;
  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: HootColors.blue,
        side: const BorderSide(color: HootColors.blue),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: () => openInvoiceDetails(context, moveId),
      icon: const Icon(Icons.receipt_long_rounded),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}

class InvoiceFullScreen extends StatefulWidget {
  const InvoiceFullScreen({super.key, required this.moveId});
  final int moveId;

  @override
  State<InvoiceFullScreen> createState() => _InvoiceFullScreenState();
}

class _InvoiceFullScreenState extends State<InvoiceFullScreen> {
  late Future<dynamic> _f = api.jcall('/hoot_app/invoice/detail', {'move_id': widget.moveId});

  String _cur = '';
  String _m(dynamic v) => '${((v as num?) ?? 0).toStringAsFixed(3)} $_cur'.trim();
  static String _n(dynamic v) {
    final d = ((v as num?) ?? 0).toDouble();
    return d == d.roundToDouble() ? d.toInt().toString() : d.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(actions: const [WdsBadge()], title: const HootTitle('تفاصيل الفاتورة')),
      body: FutureBuilder(
        future: _f,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          final d = snap.data;
          if (snap.hasError || d is! Map || d['error'] != null) {
            return EmptyState(
              icon: Icons.receipt_long_rounded,
              title: 'ما قدرنا نجيب الفاتورة',
              sub: 'تأكد من الإنترنت وحاول مرة ثانية',
              action: FilledButton(
                onPressed: () => setState(() => _f = api.jcall('/hoot_app/invoice/detail', {'move_id': widget.moveId})),
                child: const Text('إعادة المحاولة'),
              ),
            );
          }
          _cur = (d['currency'] ?? '').toString().trim();
          final header = (d['header'] as List? ?? []);
          final lines = (d['lines'] as List? ?? []);
          final taxGroups = (d['tax_groups'] as List? ?? []);
          final payments = (d['payments'] as List? ?? []);
          return ListView(padding: const EdgeInsets.fromLTRB(14, 6, 14, 28), children: [
            // title
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(gradient: HootColors.heroGradient, borderRadius: BorderRadius.circular(20)),
              child: Row(children: [
                const HootLogo(size: 38),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text((d['title'] ?? '').toString(), style: const TextStyle(color: Colors.white70)),
                    Text((d['name'] ?? '').toString(),
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 19)),
                  ]),
                ),
                if ((d['payment_state'] ?? '').toString().isNotEmpty)
                  Pill((d['payment_state']).toString(), color: Colors.white),
              ]),
            ),
            const SizedBox(height: 12),
            // header fields
            _box(Column(children: [
              for (final h in header)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(
                      width: 130,
                      child: Text('${h['label']}', style: const TextStyle(color: HootColors.muted, fontSize: 12.5)),
                    ),
                    Expanded(
                      child: Text('${h['value']}',
                          style: const TextStyle(fontWeight: FontWeight.w800, color: HootColors.navy, fontSize: 13)),
                    ),
                  ]),
                ),
            ])),
            const SizedBox(height: 14),
            const Text('الأصناف', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 8),
            for (final l in lines) _line(Map.from(l as Map)),
            const SizedBox(height: 8),
            // totals
            _box(Column(children: [
              _tot('قبل الضريبة', _m(d['amount_untaxed'])),
              for (final t in taxGroups) _tot('${t['name']} (على ${_m(t['base'])})', _m(t['amount'])),
              _tot('الضريبة', _m(d['amount_tax'])),
              const Divider(),
              _tot('الإجمالي', _m(d['amount_total']), strong: true),
              for (final p in payments) _tot('دفعة بتاريخ ${p['date']}', _m(p['amount'])),
              if (((d['amount_residual'] as num?) ?? 0) > 0)
                _tot('المبلغ المستحق', _m(d['amount_residual']), color: HootColors.danger, strong: true),
            ])),
            if ((d['amount_words'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 10),
              _box(Text('المبلغ كتابةً: ${d['amount_words']}', style: const TextStyle(fontWeight: FontWeight.w700))),
            ],
            if ((d['prepared_by'] ?? '').toString().isNotEmpty || (d['invoiced_by'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 10),
              _box(Column(children: [
                if ((d['prepared_by'] ?? '').toString().isNotEmpty) _tot('حضّرها', d['prepared_by'].toString()),
                if ((d['invoiced_by'] ?? '').toString().isNotEmpty) _tot('فوترها', d['invoiced_by'].toString()),
              ])),
            ],
            for (final k in ['narration', 'note'])
              if ((d[k] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 10),
                _box(Text('ملاحظة: ${d[k]}')),
              ],
          ]);
        },
      ),
    );
  }

  Widget _box(Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: child,
      );

  Widget _tot(String k, String v, {bool strong = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(k, style: TextStyle(color: color ?? HootColors.muted, fontWeight: strong ? FontWeight.w900 : FontWeight.w600))),
          Text(v,
              textDirection: TextDirection.ltr,
              style: TextStyle(
                  fontWeight: strong ? FontWeight.w900 : FontWeight.w800, color: color ?? HootColors.navy, fontSize: strong ? 16 : 13.5)),
        ]),
      );

  Widget _line(Map l) {
    if (l['type'] == 'line_section') {
      return Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
        child: Text('${l['name']}', style: const TextStyle(fontWeight: FontWeight.w900, color: HootColors.blue)),
      );
    }
    if (l['type'] == 'line_note') {
      return Padding(
        padding: const EdgeInsets.fromLTRB(4, 2, 4, 6),
        child: Text('${l['name']}', style: const TextStyle(fontStyle: FontStyle.italic, color: HootColors.muted)),
      );
    }
    final batches = (l['batches'] as List? ?? []).map((e) => e.toString()).toList();
    final exps = (l['exps'] as List? ?? []).map((e) => e.toString()).toList();
    final bonus = ((l['bonus'] as num?) ?? 0).toDouble();
    final bd = ((l['bonus_discount'] as num?) ?? 0).toDouble();
    final disc = ((l['discount'] as num?) ?? 0).toDouble();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${l['name']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: HootColors.navy)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          _chip('الكمية', _n(l['qty'])),
          if (bonus > 0) _chip('بونص', _n(bonus), color: HootColors.greenDark),
          if (bd > 0) _chip('خصم بونص', '${_n(bd)}%'),
          _chip('السعر', _m(l['price_unit'])),
          if (disc > 0) _chip('خصم', '${_n(disc)}%', color: HootColors.hot),
          if ((l['tax'] ?? '').toString().isNotEmpty) _chip('الضريبة', '${l['tax']}'),
        ]),
        if (batches.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            [for (var i = 0; i < batches.length; i++) '${batches[i]} — ${i < exps.length ? exps[i] : '-'}'].join('   ·   '),
            textDirection: TextDirection.ltr,
            style: const TextStyle(color: HootColors.muted, fontSize: 12),
          ),
        ],
        const SizedBox(height: 4),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Text(_m(l['subtotal']),
              textDirection: TextDirection.ltr,
              style: const TextStyle(fontWeight: FontWeight.w900, color: HootColors.blue, fontSize: 15)),
        ),
      ]),
    );
  }

  Widget _chip(String k, String v, {Color color = HootColors.navy}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
        child: Text('$k: $v', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      );
}
