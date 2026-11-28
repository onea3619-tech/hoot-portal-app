import 'package:flutter/material.dart';

import 'api.dart';
import 'invoice_detail.dart';
import 'theme.dart';
import 'widgets.dart';

/// Native "My account" screens, backed by the hoot_app_api module in Odoo.

Widget _card({required Widget child, EdgeInsets padding = const EdgeInsets.all(16)}) => Container(
      padding: padding,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: child,
    );

void _toast(BuildContext context, String msg) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

Widget _errorView(VoidCallback retry) => EmptyState(
      icon: Icons.cloud_off_rounded,
      title: 'ما قدرنا نجيب البيانات',
      sub: 'تأكد من الإنترنت وحاول مرة ثانية',
      action: FilledButton(onPressed: retry, child: const Text('إعادة المحاولة')),
    );

String _fmtDate(String iso) {
  final d = DateTime.tryParse(iso);
  return d == null ? iso : '${d.day}/${d.month}/${d.year}';
}

// ───────────────────────────── My card ─────────────────────────────

class CardScreen extends StatefulWidget {
  const CardScreen({super.key});

  @override
  State<CardScreen> createState() => _CardScreenState();
}

class _CardScreenState extends State<CardScreen> {
  late Future<dynamic> _f = api.jcall('/hoot_app/card');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const HootTitle('بطاقتي', style: TextStyle(fontWeight: FontWeight.w900))),
      body: FutureBuilder(
        future: _f,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError || snap.data is! Map) return _errorView(() => setState(() => _f = api.jcall('/hoot_app/card')));
          final d = snap.data as Map;
          return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(gradient: HootColors.heroGradient, borderRadius: BorderRadius.circular(24)),
              child: Row(children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: HootColors.green,
                  child: Icon(Icons.local_pharmacy_rounded, color: Colors.white, size: 32),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text((d['name'] ?? '').toString(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            _card(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(children: [
                for (final r in (d['rows'] as List? ?? []))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(
                        width: 130,
                        child: Text((r['label'] ?? '').toString(), style: const TextStyle(color: HootColors.muted)),
                      ),
                      Expanded(
                        child: Text((r['value'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ]),
                  ),
              ]),
            ),
          ]);
        },
      ),
    );
  }
}

// ───────────────────────────── My details ─────────────────────────────

class DetailsScreen extends StatefulWidget {
  const DetailsScreen({super.key});

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  static const _fields = [
    ('mobile', 'الموبايل', Icons.phone_iphone_rounded, TextInputType.phone),
    ('phone', 'الهاتف', Icons.call_rounded, TextInputType.phone),
    ('email', 'الإيميل', Icons.alternate_email_rounded, TextInputType.emailAddress),
    ('city', 'المدينة', Icons.location_city_rounded, TextInputType.text),
    ('street', 'العنوان', Icons.place_rounded, TextInputType.streetAddress),
  ];
  final Map<String, TextEditingController> _c = {for (final f in _fields) f.$1: TextEditingController()};
  String _name = '';
  bool _editable = false;
  String _closedMsg = '';
  bool _loading = true;
  bool _saving = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load([Map<String, dynamic>? values]) async {
    try {
      final r = await api.jcall('/hoot_app/details', values == null ? {} : {'values': values});
      if (r is Map && r['error'] == 'closed') {
        _editable = false;
        _closedMsg = (r['message'] ?? '').toString();
        _error = true;
        if (mounted) setState(() => _loading = false);
        return;
      }
      if (r is Map) {
        _name = (r['name'] ?? '').toString();
        _editable = r['editable'] == true;
        _closedMsg = (r['closed_message'] ?? '').toString();
        for (final f in _fields) {
          _c[f.$1]!.text = (r[f.$1] ?? '').toString();
        }
      }
      _error = false;
    } catch (_) {
      _error = true;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await _load({for (final f in _fields) f.$1: _c[f.$1]!.text});
    if (!mounted) return;
    setState(() => _saving = false);
    _toast(context, _error ? (_closedMsg.isNotEmpty ? _closedMsg : 'ما قدرنا نحفظ') : 'تم حفظ البيانات');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const HootTitle('بياناتي', style: TextStyle(fontWeight: FontWeight.w900))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
              _card(child: Row(children: [
                const Icon(Icons.store_rounded, color: HootColors.blue),
                const SizedBox(width: 10),
                Expanded(child: Text(_name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
              ])),
              const SizedBox(height: 14),
              if (!_editable)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: const Color(0xFFFFF4E5), borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [
                    Icon(Icons.lock_clock_rounded, color: Colors.orange.shade800),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_closedMsg.isEmpty ? 'تعديل البيانات مسكّر حالياً.' : _closedMsg,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ]),
                ),
              for (final f in _fields)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: _c[f.$1],
                    readOnly: !_editable,
                    keyboardType: f.$4,
                    decoration: InputDecoration(labelText: f.$2, prefixIcon: Icon(f.$3)),
                  ),
                ),
              const SizedBox(height: 6),
              if (_editable)
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : const Text('حفظ'),
              ),
            ]),
    );
  }
}

// ───────────────────────────── Password ─────────────────────────────

class PasswordScreen extends StatefulWidget {
  const PasswordScreen({super.key});

  @override
  State<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen> {
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _msg;

  Future<void> _submit() async {
    if (_new.text.length < 8) {
      setState(() => _msg = 'كلمة السر الجديدة لازم تكون 8 أحرف أو أكثر');
      return;
    }
    if (_new.text != _confirm.text) {
      setState(() => _msg = 'كلمتا السر غير متطابقتين');
      return;
    }
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      final r = await api.jcall('/hoot_app/password', {'old': _old.text, 'new': _new.text});
      if (r is Map && r['ok'] == true) {
        if (!mounted) return;
        _toast(context, 'تم تغيير كلمة السر');
        Navigator.pop(context);
        return;
      }
      _msg = 'كلمة السر الحالية غير صحيحة';
    } catch (_) {
      _msg = 'صار خطأ، حاول مرة ثانية';
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration dec(String l) => InputDecoration(labelText: l, prefixIcon: const Icon(Icons.lock_rounded));
    return Scaffold(
      appBar: AppBar(title: const HootTitle('الأمان وكلمة السر', style: TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
        TextField(controller: _old, obscureText: true, decoration: dec('كلمة السر الحالية')),
        const SizedBox(height: 12),
        TextField(controller: _new, obscureText: true, decoration: dec('كلمة السر الجديدة')),
        const SizedBox(height: 12),
        TextField(controller: _confirm, obscureText: true, decoration: dec('تأكيد كلمة السر الجديدة')),
        if (_msg != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_msg!, style: const TextStyle(color: HootColors.danger, fontWeight: FontWeight.w700)),
          ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
              : const Text('تغيير كلمة السر'),
        ),
      ]),
    );
  }
}

// ───────────────────────────── Returns ─────────────────────────────

Color _returnColor(String state) {
  switch (state) {
    case 'approved':
    case 'done':
      return HootColors.greenDark;
    case 'rejected':
    case 'cancel':
      return HootColors.danger;
    default:
      return Colors.orange;
  }
}

class ReturnsScreen extends StatefulWidget {
  const ReturnsScreen({super.key});

  @override
  State<ReturnsScreen> createState() => _ReturnsScreenState();
}

class _ReturnsScreenState extends State<ReturnsScreen> {
  late Future<dynamic> _f = api.jcall('/hoot_app/returns');

  void _reload() => setState(() => _f = api.jcall('/hoot_app/returns'));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const HootTitle('المرتجعات', style: TextStyle(fontWeight: FontWeight.w900))),
      floatingActionButton: FutureBuilder(
        future: _f,
        builder: (context, snap) => FloatingActionButton.extended(
          backgroundColor: HootColors.blue,
          foregroundColor: Colors.white,
          onPressed: snap.data is Map
              ? () async {
                  final reasons = [for (final r in ((snap.data as Map)['reasons'] as List? ?? [])) (r[0].toString(), r[1].toString())];
                  final done = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(builder: (_) => NewReturnScreen(reasons: reasons)),
                  );
                  if (done == true) _reload();
                }
              : null,
          icon: const Icon(Icons.add_rounded),
          label: const Text('طلب مرتجع جديد'),
        ),
      ),
      body: FutureBuilder(
        future: _f,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError || snap.data is! Map) return _errorView(_reload);
          final reqs = ((snap.data as Map)['requests'] as List? ?? []);
          if (reqs.isEmpty) {
            return const EmptyState(
              icon: Icons.assignment_return_rounded,
              title: 'ما في طلبات مرتجع',
              sub: 'اضغط "طلب مرتجع جديد" واختر الأصناف من فواتيرك',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 96), children: [
              for (final r in reqs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _card(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text((r['name'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w900))),
                        Pill((r['state_label'] ?? '').toString(), color: _returnColor((r['state'] ?? '').toString()), solid: true),
                      ]),
                      const SizedBox(height: 4),
                      Text('${_fmtDate((r['date'] ?? '').toString())} · ${r['invoice'] ?? ''} · ${r['reason'] ?? ''}',
                          style: const TextStyle(color: HootColors.muted, fontSize: 12.5)),
                      const SizedBox(height: 8),
                      for (final l in (r['lines'] as List? ?? []))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text('• ${l['name']}  ×${(l['qty'] as num?)?.toStringAsFixed(0) ?? ''}  ${l['batch_exp'] ?? ''}',
                              style: const TextStyle(fontSize: 12.5)),
                        ),
                      if ((r['reject_reason'] ?? '').toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('سبب الرفض: ${r['reject_reason']}',
                              style: const TextStyle(color: HootColors.danger, fontWeight: FontWeight.w700)),
                        ),
                      if (((r['invoice_id'] as num?) ?? 0) > 0) ...[
                        const SizedBox(height: 8),
                        InvoiceDetailsButton(moveId: (r['invoice_id'] as num).toInt(), label: 'تفاصيل الفاتورة ${r['invoice'] ?? ''}'),
                      ],
                    ]),
                  ),
                ),
            ]),
          );
        },
      ),
    );
  }
}

class NewReturnScreen extends StatefulWidget {
  const NewReturnScreen({super.key, required this.reasons});
  final List<(String, String)> reasons;

  @override
  State<NewReturnScreen> createState() => _NewReturnScreenState();
}

class _NewReturnScreenState extends State<NewReturnScreen> {
  final _search = TextEditingController();
  final _note = TextEditingController();
  final List<Map> _rows = [];
  final Map<int, int> _qty = {};
  final Map<int, Map> _chosenRows = {};
  bool _loading = false;
  bool _hasMore = false;
  bool _sending = false;
  late String _reason = widget.reasons.isNotEmpty ? widget.reasons.first.$1 : 'other';
  int _req = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    final id = ++_req;
    setState(() => _loading = true);
    try {
      final r = await api.jcall('/hoot_app/returns/search', {'term': _search.text.trim(), 'offset': more ? _rows.length : 0});
      if (id != _req || !mounted) return;
      setState(() {
        if (!more) _rows.clear();
        _rows.addAll([for (final x in (r['rows'] as List? ?? [])) x as Map]);
        _hasMore = r['has_more'] == true;
      });
    } catch (_) {}
    if (mounted && id == _req) setState(() => _loading = false);
  }

  void _setQty(Map row, int q) {
    final id = row['id'] as int;
    final max = ((row['left'] as num?) ?? 0).floor();
    q = q.clamp(0, max);
    setState(() {
      if (q == 0) {
        _qty.remove(id);
        _chosenRows.remove(id);
      } else {
        _qty[id] = q;
        _chosenRows[id] = row;
      }
    });
  }

  Future<void> _submit() async {
    setState(() => _sending = true);
    try {
      final r = await api.jcall('/hoot_app/returns/submit', {
        'reason': _reason,
        'note': _note.text,
        'lines': [for (final e in _qty.entries) {'id': e.key, 'qty': e.value}],
      });
      if (!mounted) return;
      if (r is Map && r['ok'] == true) {
        api.track('return', value: _reason, quantity: _qty.values.fold<int>(0, (a, b) => a + b).toDouble());
        _toast(context, 'تم إرسال طلب المرتجع');
        Navigator.pop(context, true);
        return;
      }
      final code = r is Map ? r['error'] : '';
      _toast(context, code == 'not_allowed' ? 'في صنف ما بينطبق عليه شرط المرتجع' : 'ما قدرنا نرسل الطلب');
    } catch (_) {
      if (mounted) _toast(context, 'صار خطأ، حاول مرة ثانية');
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const HootTitle('طلب مرتجع جديد', style: TextStyle(fontWeight: FontWeight.w900))),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: _search,
            onChanged: (_) => _load(),
            decoration: const InputDecoration(
              hintText: 'ابحث بالصنف، الباركود، الفاتورة، الـ Batch أو الشهر 12/2027',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
        ),
        Expanded(
          child: _rows.isEmpty && _loading
              ? const Center(child: CircularProgressIndicator())
              : _rows.isEmpty
                  ? const EmptyState(icon: Icons.receipt_long_rounded, title: 'ما في أصناف', sub: 'ما لقينا مشتريات بهالبحث')
                  : ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
                      for (final row in _rows) _rowTile(row),
                      if (_hasMore)
                        TextButton(onPressed: _loading ? null : () => _load(more: true), child: const Text('عرض المزيد')),
                    ]),
        ),
        if (_qty.isNotEmpty)
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, -4))],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                value: _reason,
                decoration: const InputDecoration(labelText: 'سبب المرتجع'),
                items: [for (final r in widget.reasons) DropdownMenuItem(value: r.$1, child: Text(r.$2))],
                onChanged: (v) => setState(() => _reason = v ?? _reason),
              ),
              const SizedBox(height: 8),
              TextField(controller: _note, decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)')),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _sending ? null : _submit,
                  icon: const Icon(Icons.send_rounded),
                  label: Text('إرسال طلب المرتجع (${_qty.length} صنف)'),
                ),
              ),
            ]),
          ),
      ]),
    );
  }

  Widget _rowTile(Map row) {
    final id = row['id'] as int;
    final eligible = row['eligible'] == true;
    final q = _qty[id] ?? 0;
    final left = ((row['left'] as num?) ?? 0).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Opacity(
        opacity: eligible ? 1 : 0.55,
        child: _card(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text((row['name'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                Text('${row['invoice'] ?? ''} · ${_fmtDate((row['invoice_date'] ?? '').toString())}',
                    style: const TextStyle(color: HootColors.muted, fontSize: 12)),
                Text('Batch & Exp: ${row['batch_exp'] ?? '-'}',
                    textDirection: TextDirection.ltr, style: const TextStyle(color: HootColors.muted, fontSize: 11.5)),
                const SizedBox(height: 4),
                eligible
                    ? Text('المتاح للإرجاع: ${left.toStringAsFixed(0)}',
                        style: const TextStyle(color: HootColors.greenDark, fontWeight: FontWeight.w700, fontSize: 12))
                    : const Text('ما بينطبق عليه شرط المرتجع',
                        style: TextStyle(color: HootColors.danger, fontWeight: FontWeight.w700, fontSize: 12)),
              ]),
            ),
            if (eligible)
              Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(onPressed: q > 0 ? () => _setQty(row, q - 1) : null, icon: const Icon(Icons.remove_circle_outline_rounded)),
                Text('$q', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                IconButton(
                  onPressed: q < left ? () => _setQty(row, q + 1) : null,
                  icon: const Icon(Icons.add_circle_rounded, color: HootColors.blue),
                ),
              ]),
          ]),
        ),
      ),
    );
  }
}

// ───────────────────────────── Support tickets ─────────────────────────────

class TicketsScreen extends StatefulWidget {
  const TicketsScreen({super.key});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  late Future<dynamic> _f = api.jcall('/hoot_app/tickets');

  void _reload() => setState(() => _f = api.jcall('/hoot_app/tickets'));

  Future<void> _new() async {
    final subject = TextEditingController();
    final desc = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('طلب دعم جديد', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          TextField(controller: subject, decoration: const InputDecoration(labelText: 'الموضوع')),
          const SizedBox(height: 10),
          TextField(controller: desc, maxLines: 4, decoration: const InputDecoration(labelText: 'التفاصيل')),
          const SizedBox(height: 14),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إرسال')),
        ]),
      ),
    );
    if (ok != true || subject.text.trim().isEmpty) return;
    try {
      final r = await api.jcall('/hoot_app/tickets/create', {'subject': subject.text, 'description': desc.text});
      if (!mounted) return;
      _toast(context, r is Map && r['ok'] == true ? 'تم إرسال طلب الدعم' : 'ما قدرنا نرسل الطلب');
      _reload();
    } catch (_) {
      if (mounted) _toast(context, 'صار خطأ، حاول مرة ثانية');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const HootTitle('الدعم والشكاوى', style: TextStyle(fontWeight: FontWeight.w900))),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: HootColors.blue,
        foregroundColor: Colors.white,
        onPressed: _new,
        icon: const Icon(Icons.add_comment_rounded),
        label: const Text('طلب دعم جديد'),
      ),
      body: FutureBuilder(
        future: _f,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError || snap.data is! Map) return _errorView(_reload);
          final list = ((snap.data as Map)['tickets'] as List? ?? []);
          if (list.isEmpty) {
            return const EmptyState(icon: Icons.support_agent_rounded, title: 'ما في طلبات دعم', sub: 'إذا عندك ملاحظة أو شكوى ابعتها من هون');
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 96), children: [
              for (final t in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _card(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text((t['name'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w900))),
                        Pill((t['stage'] ?? '').toString(),
                            color: t['closed'] == true ? HootColors.greenDark : HootColors.blue, solid: true),
                      ]),
                      const SizedBox(height: 4),
                      Text('${t['ref'] ?? ''}  ${_fmtDate((t['date'] ?? '').toString())}',
                          style: const TextStyle(color: HootColors.muted, fontSize: 12)),
                      if ((t['description'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text((t['description'] ?? '').toString(), maxLines: 3, overflow: TextOverflow.ellipsis),
                      ],
                    ]),
                  ),
                ),
            ]),
          );
        },
      ),
    );
  }
}

// ───────────────────────────── Appointments ─────────────────────────────

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  late Future<dynamic> _f = api.jcall('/hoot_app/appointments');

  void _reload() => setState(() => _f = api.jcall('/hoot_app/appointments'));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const HootTitle('المواعيد', style: TextStyle(fontWeight: FontWeight.w900))),
      body: FutureBuilder(
        future: _f,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError || snap.data is! Map) return _errorView(_reload);
          final d = snap.data as Map;
          final types = (d['types'] as List? ?? []);
          final events = (d['events'] as List? ?? []);
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
              const Text('احجز موعد', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 8),
              for (final t in types)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () async {
                        final booked = await Navigator.of(context).push<bool>(MaterialPageRoute(
                          builder: (_) => BookingScreen(typeId: t['id'] as int, title: (t['name'] ?? '').toString()),
                        ));
                        if (booked == true) _reload();
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(gradient: HootColors.brandGradient, borderRadius: BorderRadius.circular(14)),
                            child: const Icon(Icons.event_available_rounded, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text((t['name'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                              if ((t['intro'] ?? '').toString().isNotEmpty)
                                Text((t['intro'] ?? '').toString(),
                                    maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: HootColors.muted, fontSize: 12.5)),
                            ]),
                          ),
                          const Icon(Icons.chevron_left_rounded),
                        ]),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              const Text('مواعيدي', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 8),
              if (events.isEmpty)
                _card(child: const Text('ما في مواعيد محجوزة', style: TextStyle(color: HootColors.muted))),
              for (final e in events)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _card(
                    child: Row(children: [
                      Icon(Icons.event_rounded, color: e['upcoming'] == true ? HootColors.blue : HootColors.muted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text((e['type'] ?? e['name'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text(_eventTime((e['start'] ?? '').toString()), style: const TextStyle(color: HootColors.muted, fontSize: 12.5)),
                        ]),
                      ),
                      Pill(e['upcoming'] == true ? 'قادم' : 'سابق',
                          color: e['upcoming'] == true ? HootColors.greenDark : HootColors.muted),
                    ]),
                  ),
                ),
            ]),
          );
        },
      ),
    );
  }

  static String _eventTime(String utc) {
    final d = DateTime.tryParse('${utc}Z')?.toLocal();
    if (d == null) return utc;
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day}/${d.month}/${d.year}  ${d.hour}:$mm';
  }
}

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key, required this.typeId, required this.title});
  final int typeId;
  final String title;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  late Future<dynamic> _f = api.jcall('/hoot_app/appointment/slots', {'type_id': widget.typeId});
  int _day = 0;
  Map? _slot;
  bool _busy = false;

  static const _weekdays = ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];

  Future<void> _book() async {
    if (_slot == null) return;
    setState(() => _busy = true);
    try {
      final r = await api.jcall('/hoot_app/appointment/book', {
        'type_id': widget.typeId,
        'datetime_str': _slot!['datetime'],
        'duration': _slot!['duration'],
        'staff_user_id': _slot!['staff_user_id'],
      });
      if (r is Map && r['error'] == null) api.track('appointment', value: (_slot!['datetime'] ?? '').toString());
      if (!mounted) return;
      if (r is Map && r['ok'] == true) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.check_circle_rounded, color: HootColors.greenDark, size: 48),
            title: const Text('تم حجز الموعد'),
            content: Text('${widget.title}\n${_slot!['datetime'].toString().substring(0, 16)}', textAlign: TextAlign.center),
            actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('تمام'))],
          ),
        );
        if (mounted) Navigator.pop(context, true);
        return;
      }
      _toast(context, 'هالموعد انحجز، اختر وقت ثاني');
      setState(() => _f = api.jcall('/hoot_app/appointment/slots', {'type_id': widget.typeId}));
    } catch (_) {
      if (mounted) _toast(context, 'صار خطأ، حاول مرة ثانية');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: HootTitle(widget.title, style: const TextStyle(fontWeight: FontWeight.w900))),
      body: FutureBuilder(
        future: _f,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError || snap.data is! Map) {
            return _errorView(() => setState(() => _f = api.jcall('/hoot_app/appointment/slots', {'type_id': widget.typeId})));
          }
          final days = ((snap.data as Map)['days'] as List? ?? []);
          if (days.isEmpty) {
            return const EmptyState(icon: Icons.event_busy_rounded, title: 'ما في مواعيد متاحة', sub: 'جرّب بعدين أو تواصل معنا');
          }
          if (_day >= days.length) _day = 0;
          final slots = (days[_day]['slots'] as List? ?? []);
          return Column(children: [
            SizedBox(
              height: 86,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                scrollDirection: Axis.horizontal,
                itemCount: days.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final dt = DateTime.tryParse(days[i]['date'].toString());
                  final sel = i == _day;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _day = i;
                      _slot = null;
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 74,
                      decoration: BoxDecoration(
                        gradient: sel ? HootColors.brandGradient : null,
                        color: sel ? null : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: sel ? Colors.transparent : HootColors.line),
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(dt == null ? '' : _weekdays[dt.weekday - 1],
                            style: TextStyle(fontSize: 11, color: sel ? Colors.white70 : HootColors.muted)),
                        Text(dt == null ? '' : '${dt.day}/${dt.month}',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: sel ? Colors.white : HootColors.navy)),
                      ]),
                    ),
                  );
                },
              ),
            ),
            Expanded(
              child: GridView.count(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.3,
                children: [
                  for (final s in slots)
                    ChoiceChip(
                      label: Text((s['hours'] ?? '').toString(), textAlign: TextAlign.center),
                      selected: _slot == s,
                      showCheckmark: false,
                      selectedColor: HootColors.blue,
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _slot == s ? Colors.white : HootColors.navy,
                      ),
                      side: BorderSide(color: _slot == s ? HootColors.blue : HootColors.line),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      onSelected: (_) => setState(() => _slot = s as Map),
                    ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _slot == null || _busy ? null : _book,
                    icon: _busy
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_rounded),
                    label: Text(_slot == null ? 'اختر الوقت' : 'تأكيد الحجز الساعة ${_slot!['hours']}'),
                  ),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

// ───────────────────────────── Items the pharmacy did not find ─────────────────────────────

const kRequestTitle = 'في أصناف ما لقيتها؟';
const kRequestSub = 'سجّلها لنتواصل معك بخصوص توفيرها';

class RequestedItemsScreen extends StatefulWidget {
  final String initialName;
  const RequestedItemsScreen({super.key, this.initialName = ''});

  @override
  State<RequestedItemsScreen> createState() => _RequestedItemsScreenState();
}

class _RequestedItemsScreenState extends State<RequestedItemsScreen> {
  late Future<dynamic> _f = api.jcall('/hoot_app/requests');

  void _reload() => setState(() => _f = api.jcall('/hoot_app/requests'));

  @override
  void initState() {
    super.initState();
    if (widget.initialName.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _new(widget.initialName));
    }
  }

  Future<void> _new([String initial = '']) async {
    final name = TextEditingController(text: initial);
    final details = TextEditingController();
    final qty = TextEditingController(text: '1');
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('سجّل صنف ما لقيته', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('فريق المشتريات رح يتابع الطلب ويرد عليك هون',
              style: TextStyle(color: HootColors.muted, fontSize: 12.5)),
          const SizedBox(height: 12),
          TextField(
            controller: name,
            autofocus: initial.isEmpty,
            decoration: const InputDecoration(labelText: 'اسم الصنف', prefixIcon: Icon(Icons.medication_rounded)),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: qty,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'الكمية المطلوبة تقريباً', prefixIcon: Icon(Icons.numbers_rounded)),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: details,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'تفاصيل (التركيز، الشركة، الشكل...)'),
          ),
          const SizedBox(height: 14),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تسجيل الطلب')),
        ]),
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    try {
      final r = await api.jcall('/hoot_app/requests/create', {
        'name': name.text.trim(),
        'details': details.text.trim(),
        'quantity': double.tryParse(qty.text.trim()) ?? 1,
      });
      if (!mounted) return;
      final done = r is Map && r['ok'] == true;
      if (done) api.track('request_item', value: name.text.trim());
      _toast(context, done ? 'تم تسجيل الصنف، رح نتواصل معك قريباً' : 'ما قدرنا نسجل الصنف');
      _reload();
    } catch (_) {
      if (mounted) _toast(context, 'صار خطأ، حاول مرة ثانية');
    }
  }

  Color _stateColor(String s) => switch (s) {
        'available' => HootColors.greenDark,
        'unavailable' => HootColors.danger,
        'in_progress' => const Color(0xFFE6A100),
        _ => HootColors.blue,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const HootTitle('أصناف طلبتها', style: TextStyle(fontWeight: FontWeight.w900))),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: HootColors.blue,
        foregroundColor: Colors.white,
        onPressed: _new,
        icon: const Icon(Icons.add_rounded),
        label: const Text('سجّل صنف'),
      ),
      body: FutureBuilder(
        future: _f,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError || snap.data is! Map) return _errorView(_reload);
          final list = ((snap.data as Map)['items'] as List? ?? []);
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 96), children: [
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(gradient: HootColors.heroGradient, borderRadius: BorderRadius.circular(22)),
                child: const Row(children: [
                  Icon(Icons.manage_search_rounded, color: Colors.white, size: 40),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(kRequestTitle, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
                      SizedBox(height: 2),
                      Text(kRequestSub, style: TextStyle(color: Colors.white70, fontSize: 13)),
                    ]),
                  ),
                ]),
              ),
              if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: EmptyState(
                      icon: Icons.inventory_2_rounded, title: 'ما سجّلت أصناف لسا', sub: 'اكبس "سجّل صنف" واكتب اسم الصنف يلي بدك ياه'),
                ),
              for (final t in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _card(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text((t['name'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w900))),
                        Pill((t['state_label'] ?? '').toString(), color: _stateColor((t['state'] ?? '').toString()), solid: true),
                      ]),
                      const SizedBox(height: 4),
                      Text('الكمية: ${_qty(t['quantity'])}   •   ${_fmtDate((t['date'] ?? '').toString())}',
                          style: const TextStyle(color: HootColors.muted, fontSize: 12)),
                      if ((t['details'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text((t['details'] ?? '').toString(), maxLines: 3, overflow: TextOverflow.ellipsis),
                      ],
                      if ((t['note'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: HootColors.green.withOpacity(0.14), borderRadius: BorderRadius.circular(14)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Row(children: [
                              Icon(Icons.reply_rounded, size: 18, color: HootColors.greenDark),
                              SizedBox(width: 6),
                              Text('رد المشتريات', style: TextStyle(fontWeight: FontWeight.w900, color: HootColors.greenDark)),
                            ]),
                            const SizedBox(height: 4),
                            Text((t['note'] ?? '').toString()),
                          ]),
                        ),
                      ],
                    ]),
                  ),
                ),
            ]),
          );
        },
      ),
    );
  }

  String _qty(dynamic q) {
    final v = q is num ? q.toDouble() : 1.0;
    return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  }
}

/// Card inviting the pharmacy to record items it could not find.
class RequestItemBanner extends StatelessWidget {
  final String initialName;
  final bool compact;
  const RequestItemBanner({super.key, this.initialName = '', this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
        child: Material(
          color: HootColors.blue.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => RequestedItemsScreen(initialName: initialName))),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(children: [
                Icon(Icons.manage_search_rounded, color: HootColors.blue, size: 22),
                SizedBox(width: 8),
                Expanded(
                  child: Text('$kRequestTitle سجّلها هون',
                      style: TextStyle(fontWeight: FontWeight.w800, color: HootColors.blue, fontSize: 13.5)),
                ),
                Icon(Icons.chevron_left_rounded, color: HootColors.blue),
              ]),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => RequestedItemsScreen(initialName: initialName))),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: HootColors.blue.withOpacity(0.25), width: 1.4),
            ),
            child: const Row(children: [
              CircleAvatar(
                  radius: 22, backgroundColor: HootColors.blue, child: Icon(Icons.manage_search_rounded, color: Colors.white)),
              SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(kRequestTitle, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5)),
                  SizedBox(height: 2),
                  Text(kRequestSub, style: TextStyle(color: HootColors.muted, fontSize: 12.5)),
                ]),
              ),
              Icon(Icons.chevron_left_rounded, color: HootColors.blue),
            ]),
          ),
        ),
      ),
    );
  }
}
