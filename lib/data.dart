import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

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
