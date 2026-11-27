import 'dart:async';
import 'dart:convert';

import 'package:html/parser.dart' as html_parser;
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

  const Product({
    required this.id,
    required this.name,
    required this.vendor,
    required this.hot,
    required this.bonus,
    required this.available,
    required this.batchExp,
    required this.price,
  });

  String get imageUrl => '${AppConfig.baseUrl}/my/quick_order/image/$id?size=256';
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
  const PortalOrder(this.id, this.name, this.date, this.total, this.state, this.delivery);
}

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
      final name = (err is Map ? err['data']?['name'] : '')?.toString() ?? '';
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
    final doc = html_parser.parse(body);
    pricelists = [
      for (final e in doc.querySelectorAll('.o_fq_pricelist'))
        if (int.tryParse(e.attributes['data-id'] ?? '') != null)
          Pricelist(int.parse(e.attributes['data-id']!), e.text.trim()),
    ];
    final seen = <int>{};
    vendors = [
      for (final e in doc.querySelectorAll('.o_fq_vendor'))
        if ((int.tryParse(e.attributes['data-id'] ?? '') ?? 0) > 0 &&
            seen.add(int.parse(e.attributes['data-id']!)))
          Vendor(int.parse(e.attributes['data-id']!), _cleanVendor(e.text)),
    ];
  }

  static String _cleanVendor(String s) => s.replaceAll('*', '').replaceAll(RegExp(r'\s+'), ' ').trim();

  Future<void> setPricelist(int id) async {
    final r = await _rpc('/my/quick_order/pricelist', {'pricelist_id': id, 'csrf_token': _csrf});
    if (r is Map && r['error'] != null) throw ApiException('ما قدرنا نختار قائمة الأسعار');
  }

  Future<CardsPage> cards({String search = '', int vendorId = 0, bool hot = false, int offset = 0}) async {
    final params = <String, dynamic>{'search': search, 'offset': offset};
    if (vendorId > 0) params['vendor_id'] = vendorId;
    if (hot) params['hot'] = true;
    final r = await _rpc('/my/quick_order/cards', params);
    if (r is! Map) return const CardsPage([], 0, false, false);
    return CardsPage(
      _parseCards((r['html'] ?? '').toString()),
      (r['count'] as num?)?.toInt() ?? 0,
      r['has_more'] == true,
      r['has_pricelist'] == true,
    );
  }

  List<Product> _parseCards(String html) {
    final doc = html_parser.parse(html);
    final out = <Product>[];
    for (final card in doc.querySelectorAll('.o_fq_card')) {
      final id = int.tryParse(card.attributes['data-id'] ?? '');
      if (id == null) continue;
      final name = card.querySelector('.o_fq_name')?.text.trim() ?? '';
      final smalls = card.querySelectorAll('.o_fq_info > div.small');
      final vendor = smalls.isNotEmpty ? _cleanVendor(smalls.first.text) : '';
      var batch = smalls.length > 1 ? smalls.last.text.trim() : '';
      final colon = batch.indexOf(':');
      if (colon >= 0) batch = batch.substring(colon + 1).trim();
      var hot = false, available = false;
      var bonus = '';
      for (final b in card.querySelectorAll('.badge')) {
        final text = b.text.trim();
        final cls = b.className;
        if (b.querySelector('.fa-fire') != null || text.contains('Hot')) {
          hot = cls.contains('text-bg-warning') || text.contains('Yes') || text.contains('نعم');
        } else if (cls.contains('text-bg-success')) {
          available = true;
        } else if (cls.contains('text-bg-info')) {
          final i = text.indexOf(':');
          bonus = i >= 0 ? text.substring(i + 1).trim() : text;
        }
      }
      final priceText = card.querySelector('.oe_currency_value')?.text.replaceAll(',', '').trim();
      out.add(Product(
        id: id,
        name: name,
        vendor: vendor,
        hot: hot,
        bonus: bonus,
        available: available,
        batchExp: batch,
        price: priceText == null ? null : double.tryParse(priceText),
      ));
    }
    return out;
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

  // ───────────── orders ─────────────

  Future<List<PortalOrder>> orders() async {
    final r = await _rpc('/web/dataset/call_kw/sale.order/search_read', {
      'model': 'sale.order',
      'method': 'search_read',
      'args': [],
      'kwargs': {
        'domain': [],
        'fields': ['name', 'date_order', 'amount_total', 'state', 'delivery_status'],
        'order': 'date_order desc',
        'limit': 40,
      },
    });
    if (r is! List) return [];
    return [
      for (final o in r)
        PortalOrder(
          o['id'] as int,
          (o['name'] ?? '').toString(),
          DateTime.tryParse((o['date_order'] ?? '').toString()),
          (o['amount_total'] as num?)?.toDouble() ?? 0,
          (o['state'] ?? '').toString(),
          (o['delivery_status'] ?? '').toString(),
        ),
    ];
  }
}

final api = OdooApi.instance;
