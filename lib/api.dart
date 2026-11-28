import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'portal.dart';

/// A product card as returned by the portal quick order (flex_customer_portal).
class Product {
  final int id;
  final String name;
  final String vendor;
  final bool hot;
  final String bonus; // empty if none / not known yet
  final bool available;
  final String batchExp;
  final double? price; // null until a pricelist is chosen
  final String tax; // e.g. "16%" or "0% O"
  final double taxPercent;
  final String category;
  final String productType; // Agent / Subagent
  final String label; // offer / list label set by staff in Sales > App

  const Product({
    required this.id,
    required this.name,
    required this.vendor,
    required this.hot,
    required this.bonus,
    required this.available,
    required this.batchExp,
    required this.price,
    this.tax = '',
    this.taxPercent = 0,
    this.category = '',
    this.productType = '',
    this.label = '',
  });

  factory Product.fromJson(Map j) => Product(
        id: j['id'] as int,
        name: (j['name'] ?? '').toString().trim(),
        vendor: OdooApi._cleanVendor((j['vendor'] ?? '').toString()),
        hot: j['hot'] == true,
        bonus: (j['bonus'] ?? '').toString(),
        available: true,
        batchExp: (j['batch_exp'] ?? '').toString(),
        price: j['price'] is num ? (j['price'] as num).toDouble() : null,
        tax: (j['tax'] ?? '').toString(),
        taxPercent: j['tax_percent'] is num ? (j['tax_percent'] as num).toDouble() : 0,
        category: (j['category'] ?? '').toString(),
        productType: (j['product_type'] ?? '').toString(),
        label: (j['label'] ?? '').toString(),
      );

  String get imageUrl => '${AppConfig.baseUrl}/my/quick_order/image/$id?size=256';
}

class AppCategory {
  final String key;
  final String label;
  final int count;
  const AppCategory(this.key, this.label, this.count);
}

class Vendor {
  final int id;
  final String name;
  const Vendor(this.id, this.name);
}

class Pricelist {
  final int id;
  final String name;
  const Pricelist(this.id, this.name);
}

class CardsPage {
  final List<Product> items;
  final int count;
  final bool hasMore;
  final bool hasPricelist;
  const CardsPage(this.items, this.count, this.hasMore, this.hasPricelist);
}

class PortalOrder {
  final int id;
  final String name;
  final DateTime? date;
  final double total;
  final String state;
  final String delivery;
  final bool invoiced; // a confirmed (posted) invoice exists
  const PortalOrder(this.id, this.name, this.date, this.total, this.state, this.delivery, [this.invoiced = false]);
}


class Invoice {
  final int id;
  final String name;
  final String type; // out_invoice / out_refund
  final DateTime? date;
  final DateTime? due;
  final double total;
  final double residual;
  final String paymentState;
  const Invoice(this.id, this.name, this.type, this.date, this.due, this.total, this.residual, this.paymentState);
  bool get isRefund => type == 'out_refund';
}

class DocLine {
  final String name;
  final double qty;
  final double price;
  final double subtotal;
  const DocLine(this.name, this.qty, this.price, this.subtotal);
}

DateTime? _date(dynamic v) => v is String ? DateTime.tryParse(v) : null;
double _num(dynamic v) => v is num ? v.toDouble() : 0;

class ApiException implements Exception {
  final String message;
  final bool auth;
  ApiException(this.message, {this.auth = false});
  @override
  String toString() => message;
}

/// Talks to Odoo with the portal user's own session (same rights as the
/// web portal): login form, quick order endpoints and JSON-RPC.
class OdooApi {
  OdooApi._();
  static final OdooApi instance = OdooApi._();

  static const _prefSession = 'session_id';
  static const _timeout = Duration(seconds: 25);

  String? sessionId;
  String? _csrf;
  String userName = '';
  List<Pricelist> pricelists = [];
  List<Vendor> vendors = [];
  List<AppCategory> categories = [];
  int? selectedPricelist;

  /// Generic JSON call to an Odoo route with the pharmacy's session.
  Future<dynamic> jcall(String path, [Map<String, dynamic> params = const {}]) => _rpc(path, params);

  // ── usage events for the "تقرير التطبيق التحليلي" report ──
  final List<Map<String, dynamic>> _events = [];
  Timer? _flushTimer;

  /// Records an app event; events are sent in small batches, never blocking the UI.
  void track(String type,
      {String value = '', int productId = 0, double quantity = 0, double amount = 0, int? results, int orderId = 0}) {
    if (sessionId == null) return;
    _events.add({
      'type': type,
      if (value.isNotEmpty) 'value': value,
      if (productId > 0) 'product_id': productId,
      if (quantity != 0) 'quantity': quantity,
      if (amount != 0) 'amount': amount,
      if (results != null) 'results': results,
      if (orderId > 0) 'order_id': orderId,
    });
    _flushTimer?.cancel();
    _flushTimer = Timer(Duration(seconds: _events.length >= 20 ? 0 : 4), flushEvents);
  }

  Future<void> flushEvents() async {
    if (_events.isEmpty) return;
    final batch = List<Map<String, dynamic>>.from(_events);
    _events.clear();
    try {
      await _rpc('/hoot_app/track', {'events': batch});
    } catch (_) {/* analytics is best-effort */}
  }

  Uri _u(String path) => Uri.parse('${AppConfig.baseUrl}$path');

  Map<String, String> get cookieHeader =>
      sessionId == null ? {} : {'Cookie': 'session_id=$sessionId'};

  // ───────────── session ─────────────

  Future<bool> restore() async {
    final p = await SharedPreferences.getInstance();
    sessionId = p.getString(_prefSession);
    if (sessionId == null) return false;
    try {
      final ok = await _loadSessionInfo();
      if (ok) await _syncWebViewCookie();
      return ok;
    } catch (_) {
      return false;
    }
  }

  Future<void> login(String login, String password) async {
    final client = http.Client();
    try {
      // 1) login page: anonymous session cookie + csrf token
      final page = await client.get(_u('/web/login')).timeout(_timeout);
      final anon = _readSessionCookie(page.headers['set-cookie']);
      final csrf = RegExp(r'name="csrf_token"\s+value="([^"]+)"').firstMatch(page.body)?.group(1);
      if (anon == null || csrf == null) throw ApiException('تعذّر فتح صفحة الدخول');

      // 2) post the form, without following the redirect
      final req = http.Request('POST', _u('/web/login'))
        ..followRedirects = false
        ..headers['Cookie'] = 'session_id=$anon'
        ..headers['Content-Type'] = 'application/x-www-form-urlencoded'
        ..bodyFields = {'login': login.trim(), 'password': password, 'csrf_token': csrf, 'redirect': '/my'};
      final res = await client.send(req).timeout(_timeout);
      final location = res.headers['location'] ?? '';
      final newSession = _readSessionCookie(res.headers['set-cookie']) ?? anon;
      final redirected = res.statusCode >= 300 && res.statusCode < 400;
      if (!redirected || location.contains('/web/login')) {
        throw ApiException('اسم المستخدم أو كلمة السر غير صحيحة', auth: true);
      }
      sessionId = newSession;
    } on TimeoutException {
      throw ApiException('الاتصال بطيء، حاول مرة ثانية');
    } finally {
      client.close();
    }
    if (!await _loadSessionInfo()) {
      throw ApiException('اسم المستخدم أو كلمة السر غير صحيحة', auth: true);
    }
    final p = await SharedPreferences.getInstance();
    await p.setString(_prefSession, sessionId!);
    await _syncWebViewCookie();
  }

  Future<void> logout() async {
    try {
      await _rpc('/web/session/destroy', {});
    } catch (_) {}
    sessionId = null;
    _csrf = null;
    userName = '';
    final p = await SharedPreferences.getInstance();
    await p.remove(_prefSession);
    await WebViewCookieManager().clearCookies();
  }

  String? _readSessionCookie(String? setCookie) {
    if (setCookie == null) return null;
    return RegExp(r'session_id=([^;,\s]+)').firstMatch(setCookie)?.group(1);
  }

  Future<bool> _loadSessionInfo() async {
    final info = await _rpc('/web/session/get_session_info', {});
    if (info is! Map || info['uid'] == null || info['uid'] == false) return false;
    userName = (info['partner_display_name'] ?? info['name'] ?? '').toString();
    return true;
  }

  Future<void> _syncWebViewCookie() async {
    if (sessionId == null) return;
    final host = Uri.parse(AppConfig.baseUrl).host;
    await WebViewCookieManager().setCookie(
      WebViewCookie(name: 'session_id', value: sessionId!, domain: host, path: '/'),
    );
  }

  // ───────────── low level ─────────────

  Future<dynamic> _rpc(String path, Map<String, dynamic> params) async {
    final http.Response res;
    try {
      res = await http
          .post(
            _u(path),
            headers: {'Content-Type': 'application/json', ...cookieHeader},
            body: jsonEncode({'jsonrpc': '2.0', 'method': 'call', 'params': params}),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw ApiException('الاتصال بطيء، حاول مرة ثانية');
    }
    if (res.statusCode == 404) throw ApiException('الخدمة غير موجودة على الخادم');
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    if (body is Map && body['error'] != null) {
      final err = body['error'];
      var name = '';
      if (err is Map && err['data'] is Map) {
        name = ((err['data'] as Map)['name'] ?? '').toString();
      }
      if (name.contains('SessionExpired') || name.contains('AccessDenied')) {
        throw ApiException('انتهت الجلسة، سجّل دخول من جديد', auth: true);
      }
      throw ApiException('صار خطأ بالخادم');
    }
    return body is Map ? body['result'] : null;
  }

  // ───────────── quick order ─────────────

  /// Reads csrf token, pricelists and vendors from the quick order page.
  Future<void> loadQuickOrderMeta() async {
    final res = await http.get(_u('/my/quick_order'), headers: cookieHeader).timeout(_timeout);
    final body = utf8.decode(res.bodyBytes);
    if (body.contains('oe_login_form')) {
      throw ApiException('انتهت الجلسة، سجّل دخول من جديد', auth: true);
    }
    _csrf = RegExp(r'csrf_token\s*:\s*"([^"]+)"').firstMatch(body)?.group(1) ??
        RegExp(r'name="csrf_token"\s+value="([^"]+)"').firstMatch(body)?.group(1);
    final meta = await _rpc('/hoot_app/meta', {});
    if (meta is Map) {
      userName = (meta['user_name'] ?? userName).toString();
      pricelists = [for (final p in (meta['pricelists'] as List? ?? [])) Pricelist(p['id'] as int, (p['name'] ?? '').toString())];
      vendors = [for (final v in (meta['vendors'] as List? ?? [])) Vendor(v['id'] as int, _cleanVendor((v['name'] ?? '').toString()))];
      categories = [
        for (final c in (meta['categories'] as List? ?? []))
          AppCategory((c['key'] ?? '').toString(), (c['label'] ?? '').toString(), (c['count'] as num?)?.toInt() ?? 0)
      ];
      selectedPricelist = meta['selected_pricelist'] is int ? meta['selected_pricelist'] as int : null;
    }
  }

  static String _cleanVendor(String s) => s.replaceAll('*', '').replaceAll(RegExp(r'\s+'), ' ').trim();

  Future<void> setPricelist(int id) async {
    final r = await _rpc('/my/quick_order/pricelist', {'pricelist_id': id, 'csrf_token': _csrf});
    if (r is Map && r['error'] != null) throw ApiException('ما قدرنا نختار قائمة الأسعار');
  }

  Future<CardsPage> cards(
      {String search = '', int vendorId = 0, bool hot = false, String category = '', bool fresh = false, String list = '', int offset = 0, int limit = 20}) async {
    final params = <String, dynamic>{'search': search, 'offset': offset, 'limit': limit};
    if (list.isNotEmpty) params['list'] = list;
    if (vendorId > 0) params['vendor_id'] = vendorId;
    if (hot) params['hot'] = true;
    if (category.isNotEmpty) params['category'] = category;
    if (fresh) params['new'] = true;
    final r = await _rpc('/hoot_app/cards', params);
    if (r is! Map) return const CardsPage([], 0, false, false);
    return CardsPage(
      [for (final j in (r['items'] as List? ?? [])) Product.fromJson(j as Map)],
      (r['count'] as num?)?.toInt() ?? 0,
      r['has_more'] == true,
      r['has_pricelist'] == true,
    );
  }

  /// Server-side check of the cart: returns the formatted total.
  Future<String> reviewTotal(Map<int, int> lines) async {
    final r = await _rpc('/my/quick_order/review', {
      'lines': [for (final e in lines.entries) {'id': e.key, 'qty': e.value}],
    });
    return r is Map ? (r['total'] ?? '').toString() : '';
  }

  /// Sends the order. Returns the portal URL of the created order.
  Future<String> submit(int pricelistId, Map<int, int> lines) async {
    final r = await _rpc('/my/quick_order/submit', {
      'pricelist_id': pricelistId,
      'lines': [for (final e in lines.entries) {'id': e.key, 'qty': e.value}],
      'csrf_token': _csrf,
    });
    if (r is Map && r['url'] != null) return r['url'].toString();
    final code = r is Map ? (r['error'] ?? '').toString() : '';
    throw ApiException(code.isEmpty ? 'ما قدرنا نرسل الطلب' : 'ما قدرنا نرسل الطلب ($code)');
  }


  Future<List<dynamic>> _searchRead(String model, List domain, List<String> fields,
      {String? order, int limit = 80}) async {
    final r = await _rpc('/web/dataset/call_kw/$model/search_read', {
      'model': model,
      'method': 'search_read',
      'args': [],
      'kwargs': {
        'domain': domain,
        'fields': fields,
        if (order != null) 'order': order,
        'limit': limit,
      },
    });
    return r is List ? r : [];
  }

  Future<List<Invoice>> invoices() async {
    final r = await _searchRead(
      'account.move',
      [
        ['move_type', 'in', ['out_invoice', 'out_refund']]
      ],
      ['name', 'move_type', 'invoice_date', 'invoice_date_due', 'amount_total', 'amount_residual', 'payment_state'],
      order: 'invoice_date desc, id desc',
      limit: 200,
    );
    return [
      for (final m in r)
        Invoice(
          m['id'] as int,
          (m['name'] ?? '').toString(),
          (m['move_type'] ?? '').toString(),
          _date(m['invoice_date']),
          _date(m['invoice_date_due']),
          _num(m['amount_total']),
          _num(m['amount_residual']),
          (m['payment_state'] ?? '').toString(),
        ),
    ];
  }

  Future<List<DocLine>> invoiceLines(int moveId) async {
    final r = await _searchRead(
      'account.move.line',
      [
        ['move_id', '=', moveId],
        ['display_type', '=', 'product']
      ],
      ['name', 'quantity', 'price_unit', 'price_subtotal'],
      order: 'sequence, id',
      limit: 500,
    );
    return [
      for (final l in r)
        DocLine((l['name'] ?? '').toString(), _num(l['quantity']), _num(l['price_unit']), _num(l['price_subtotal'])),
    ];
  }

  Future<List<DocLine>> orderLines(int orderId) async {
    final r = await _searchRead(
      'sale.order.line',
      [
        ['order_id', '=', orderId],
        ['display_type', '=', false]
      ],
      ['name', 'product_uom_qty', 'price_unit', 'price_subtotal'],
      order: 'sequence, id',
      limit: 500,
    );
    return [
      for (final l in r)
        DocLine((l['name'] ?? '').toString(), _num(l['product_uom_qty']), _num(l['price_unit']), _num(l['price_subtotal'])),
    ];
  }

  // ───────────── orders ─────────────

  Future<List<PortalOrder>> orders() async {
    final r = await _searchRead(
      'sale.order',
      [],
      ['name', 'date_order', 'amount_total', 'state', 'delivery_status', 'invoice_ids'],
      order: 'date_order desc',
      limit: 60,
    );
    final invIds = <int>{for (final o in r) ...((o['invoice_ids'] as List?) ?? []).cast<int>()};
    var posted = <int>{};
    if (invIds.isNotEmpty) {
      try {
        // The portal only sees posted invoices, so any invoice returned is confirmed.
        final inv = await _searchRead(
          'account.move',
          [
            ['id', 'in', invIds.toList()],
            ['state', '=', 'posted']
          ],
          ['id'],
          limit: 500,
        );
        posted = {for (final m in inv) m['id'] as int};
      } catch (_) {}
    }
    return [
      for (final o in r)
        PortalOrder(
          o['id'] as int,
          (o['name'] ?? '').toString(),
          DateTime.tryParse((o['date_order'] ?? '').toString()),
          _num(o['amount_total']),
          (o['state'] ?? '').toString(),
          (o['delivery_status'] ?? '').toString(),
          ((o['invoice_ids'] as List?) ?? []).any((i) => posted.contains(i)),
        ),
    ];
  }
}

final api = OdooApi.instance;
