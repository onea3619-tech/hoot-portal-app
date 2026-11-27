import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

/// An order sent from the app. Kept on the phone so it shows in
/// "طلباتي" right away, even before Odoo lists it for the pharmacy.
class SentOrder {
  final int id;
  final String url;
  final String total;
  final DateTime date;
  final int items;
  SentOrder(this.id, this.url, this.total, this.date, this.items);

  Map<String, dynamic> toJson() => {'id': id, 'url': url, 'total': total, 'date': date.toIso8601String(), 'items': items};
  static SentOrder fromJson(Map<String, dynamic> j) =>
      SentOrder(j['id'] as int, j['url'] as String, j['total'] as String, DateTime.parse(j['date'] as String), j['items'] as int);
}

final sentOrders = ValueNotifier<List<SentOrder>>([]);

Future<void> loadSentOrders() async {
  final p = await SharedPreferences.getInstance();
  final raw = p.getString('sent_orders');
  if (raw == null) return;
  try {
    sentOrders.value = [for (final j in jsonDecode(raw) as List) SentOrder.fromJson(Map<String, dynamic>.from(j as Map))];
  } catch (_) {}
}

Future<void> _saveSentOrders() async {
  final p = await SharedPreferences.getInstance();
  await p.setString('sent_orders', jsonEncode([for (final o in sentOrders.value.take(30)) o.toJson()]));
}

class CartLine {
  final Product product;
  int qty;
  CartLine(this.product, this.qty);
}

/// The cart lives on the phone (like the web quick order); prices and the
/// total come from Odoo for the chosen pricelist.
class CartModel extends ChangeNotifier {
  final Map<int, CartLine> _lines = {};
  int? pricelistId;
  String serverTotal = '';
  bool sending = false;
  Timer? _debounce;

  Map<int, CartLine> get lines => Map.unmodifiable(_lines);
  int get count => _lines.values.fold(0, (a, b) => a + b.qty);
  int qtyOf(Product p) => _lines[p.id]?.qty ?? 0;

  String get pricelistName {
    final pl = api.pricelists.where((e) => e.id == pricelistId);
    return pl.isEmpty ? '' : pl.first.name;
  }

  void add(Product p, [int n = 1]) => setQty(p, qtyOf(p) + n);
  void remove(Product p) => setQty(p, qtyOf(p) - 1);

  void setQty(Product p, int n) {
    if (n <= 0) {
      _lines.remove(p.id);
    } else {
      _lines.putIfAbsent(p.id, () => CartLine(p, 0)).qty = n;
    }
    notifyListeners();
    _refreshTotal();
  }

  /// Local estimate shown instantly; replaced by the server total.
  double get localTotal =>
      _lines.values.fold(0.0, (s, l) => s + (l.product.price ?? 0) * l.qty);

  Future<void> choosePricelist(int id) async {
    await api.setPricelist(id);
    pricelistId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('pricelist_id', id);
    notifyListeners();
    _refreshTotal();
  }

  void _refreshTotal() {
    _debounce?.cancel();
    if (_lines.isEmpty) {
      serverTotal = '';
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        serverTotal = await api.reviewTotal({for (final l in _lines.values) l.product.id: l.qty});
        notifyListeners();
      } catch (_) {}
    });
  }

  Future<String> submit() async {
    sending = true;
    notifyListeners();
    try {
      final url = await api.submit(pricelistId!, {for (final l in _lines.values) l.product.id: l.qty});
      final id = int.tryParse(RegExp(r'/orders/(\d+)').firstMatch(url)?.group(1) ?? '');
      if (id != null) {
        final total = serverTotal.isNotEmpty ? serverTotal : money(localTotal);
        sentOrders.value = [SentOrder(id, url, total, DateTime.now(), count), ...sentOrders.value];
        await _saveSentOrders();
      }
      _lines.clear();
      serverTotal = '';
      return url;
    } finally {
      sending = false;
      notifyListeners();
    }
  }

  void clear() {
    _lines.clear();
    pricelistId = null;
    serverTotal = '';
    notifyListeners();
  }
}

final cart = CartModel();

/// Bottom navigation index, so any screen can switch tabs.
final tabIndex = ValueNotifier<int>(0);

/// Filter to apply when switching to the catalog: plain text (search or a
/// scanned barcode), '#hot', or 'vendor:<id>'.
final catalogQuery = ValueNotifier<String>('');

/// Bumped when pricelists/vendors are loaded from Odoo.
final metaVersion = ValueNotifier<int>(0);

/// Bumped when orders should reload (after sending one).
final ordersVersion = ValueNotifier<int>(0);

String money(double v) => '${v.toStringAsFixed(3)} د.أ';

/// Company contact numbers shown in the app.
const kSupportPhone = '+962793888844';
const kSupportPhoneDisplay = '07 9388 8844';

/// WhatsApp number linked to Odoo's WhatsApp API.
const kSupportWhatsapp = '962799559077';
const kSupportWhatsappDisplay = '+962 7 9955 9077';
