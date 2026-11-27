import 'package:flutter/material.dart';

/// Demo data for the first UI version of the app. The next step replaces
/// it with live data from Odoo (products, pricelists, orders, statement).

class Product {
  final int id;
  final String name;
  final String scientific;
  final String vendor;
  final String category;
  final String barcode;
  final String bonus; // e.g. "10+1", empty if none
  final String batch;
  final String exp;
  final double price;
  final bool hot;
  final bool isNew;
  final IconData icon;

  const Product({
    required this.id,
    required this.name,
    required this.scientific,
    required this.vendor,
    required this.category,
    required this.barcode,
    required this.price,
    this.bonus = '',
    this.batch = '',
    this.exp = '',
    this.hot = false,
    this.isNew = false,
    this.icon = Icons.medication_rounded,
  });
}

class Category {
  final String name;
  final IconData icon;
  final Color color;
  const Category(this.name, this.icon, this.color);
}

class Pricelist {
  final String code;
  final String label;
  final String hint;
  final double factor;
  const Pricelist(this.code, this.label, this.hint, this.factor);
}

const categories = <Category>[
  Category('الكل', Icons.apps_rounded, Color(0xFF0058C0)),
  Category('أدوية', Icons.medication_rounded, Color(0xFF0058C0)),
  Category('مكملات', Icons.spa_rounded, Color(0xFF6BA32E)),
  Category('أجهزة طبية', Icons.monitor_heart_rounded, Color(0xFF0B2545)),
  Category('عناية', Icons.face_retouching_natural_rounded, Color(0xFF1E88E5)),
  Category('أطفال', Icons.child_care_rounded, Color(0xFF7CB342)),
];

const pricelists = <Pricelist>[
  Pricelist('Standard', 'Standard', 'السعر العادي', 1.0),
  Pricelist('Best', 'Best', 'أفضل سعر للدفع النقدي', 0.96),
  Pricelist('Extended', 'Extended', 'دفع ممتد', 1.04),
];

const products = <Product>[
  Product(id: 1, name: 'Paracetamol 500mg 24 Tab', scientific: 'Paracetamol', vendor: 'دار الدواء', category: 'أدوية', barcode: '6251234500011', price: 0.85, bonus: '10+1', batch: 'B2311', exp: '08/2028', hot: true),
  Product(id: 2, name: 'Amoxicillin 500mg 16 Cap', scientific: 'Amoxicillin', vendor: 'الحكمة', category: 'أدوية', barcode: '6251234500028', price: 1.95, batch: 'A7781', exp: '03/2028'),
  Product(id: 3, name: 'Omeprazole 20mg 14 Cap', scientific: 'Omeprazole', vendor: 'رام', category: 'أدوية', barcode: '6251234500035', price: 2.40, bonus: '5+1', batch: 'R1290', exp: '11/2027', hot: true),
  Product(id: 4, name: 'Ibuprofen 400mg 20 Tab', scientific: 'Ibuprofen', vendor: 'دار الدواء', category: 'أدوية', barcode: '6251234500042', price: 1.10, batch: 'D5521', exp: '01/2029', isNew: true),
  Product(id: 5, name: 'Vitamin D3 5000 IU 30 Cap', scientific: 'Cholecalciferol', vendor: 'هوت فارما', category: 'مكملات', barcode: '6251234500059', price: 3.75, bonus: '6+1', batch: 'H0915', exp: '06/2028', hot: true, icon: Icons.wb_sunny_rounded),
  Product(id: 6, name: 'New Glucan Plus + Zinc 30 Cap', scientific: 'Beta Glucan + Zinc', vendor: 'هوت فارما', category: 'مكملات', barcode: '6251234500066', price: 6.50, bonus: '3+1', batch: 'G2201', exp: '09/2028', hot: true, isNew: true, icon: Icons.spa_rounded),
  Product(id: 7, name: 'Omega 3 1000mg 60 Softgel', scientific: 'Fish Oil', vendor: 'الحكمة', category: 'مكملات', barcode: '6251234500073', price: 4.20, batch: 'O3310', exp: '12/2027', icon: Icons.water_drop_rounded),
  Product(id: 8, name: 'Joycoo Plus Glucometer', scientific: 'جهاز قياس سكر', vendor: 'Joycoo', category: 'أجهزة طبية', barcode: '6251234500080', price: 9.90, bonus: '5+1', batch: 'J7001', exp: '-', hot: true, isNew: true, icon: Icons.monitor_heart_rounded),
  Product(id: 9, name: 'Joycoo Test Strips 50', scientific: 'شرائح فحص السكر', vendor: 'Joycoo', category: 'أجهزة طبية', barcode: '6251234500097', price: 7.25, batch: 'J7102', exp: '05/2027', icon: Icons.science_rounded),
  Product(id: 10, name: 'Digital Thermometer', scientific: 'ميزان حرارة رقمي', vendor: 'ميدي تك', category: 'أجهزة طبية', barcode: '6251234500103', price: 2.10, batch: 'M0301', exp: '-', icon: Icons.thermostat_rounded),
  Product(id: 11, name: 'VIXMINT Mouthwash 250ml', scientific: 'Chlorhexidine', vendor: 'هوت فارما', category: 'عناية', barcode: '6251234500110', price: 2.95, bonus: '12+2', batch: 'V1120', exp: '10/2028', isNew: true, icon: Icons.face_retouching_natural_rounded),
  Product(id: 12, name: 'Sunscreen SPF50 50ml', scientific: 'واقي شمس', vendor: 'ديرما', category: 'عناية', barcode: '6251234500127', price: 5.60, batch: 'S5050', exp: '04/2028', icon: Icons.wb_sunny_outlined),
  Product(id: 13, name: 'Baby Paracetamol Syrup 100ml', scientific: 'Paracetamol 120mg/5ml', vendor: 'دار الدواء', category: 'أطفال', barcode: '6251234500134', price: 1.35, bonus: '10+1', batch: 'P1205', exp: '07/2027', hot: true, icon: Icons.child_care_rounded),
  Product(id: 14, name: 'Diaper Rash Cream 100g', scientific: 'Zinc Oxide', vendor: 'ديرما', category: 'أطفال', barcode: '6251234500141', price: 2.25, batch: 'Z1001', exp: '02/2029', icon: Icons.child_friendly_rounded),
];

Product productById(int id) => products.firstWhere((p) => p.id == id);

class Order {
  final String ref;
  final DateTime date;
  final int items;
  final double total;
  final String pricelist;
  int status; // 0 new, 1 preparing, 2 on the way, 3 delivered
  Order(this.ref, this.date, this.items, this.total, this.pricelist, this.status);
}

const orderStatuses = ['جديد', 'قيد التحضير', 'بالطريق', 'تم التسليم'];

class CartModel extends ChangeNotifier {
  final Map<int, int> _qty = {};
  String? pricelist;
  int _seq = 1043;

  final List<Order> orders = [
    Order('S01042', DateTime.now().subtract(const Duration(hours: 5)), 12, 84.30, 'Best', 1),
    Order('S01031', DateTime.now().subtract(const Duration(days: 2)), 7, 41.75, 'Standard', 2),
    Order('S00998', DateTime.now().subtract(const Duration(days: 9)), 20, 156.20, 'Extended', 3),
  ];

  Map<int, int> get lines => Map.unmodifiable(_qty);
  int get count => _qty.values.fold(0, (a, b) => a + b);
  int qtyOf(Product p) => _qty[p.id] ?? 0;

  void add(Product p, [int n = 1]) {
    _qty[p.id] = qtyOf(p) + n;
    notifyListeners();
  }

  void setQty(Product p, int n) {
    if (n <= 0) {
      _qty.remove(p.id);
    } else {
      _qty[p.id] = n;
    }
    notifyListeners();
  }

  void remove(Product p) => setQty(p, qtyOf(p) - 1);

  void setPricelist(String code) {
    pricelist = code;
    notifyListeners();
  }

  double get factor =>
      pricelists.firstWhere((e) => e.code == pricelist, orElse: () => pricelists.first).factor;

  double priceOf(Product p) => p.price * factor;

  double get total =>
      _qty.entries.fold(0.0, (s, e) => s + priceOf(productById(e.key)) * e.value);

  Order submit() {
    final order = Order('S0${_seq++}', DateTime.now(), count, total, pricelist ?? 'Standard', 0);
    orders.insert(0, order);
    _qty.clear();
    pricelist = null;
    notifyListeners();
    return order;
  }
}

final cart = CartModel();

/// Bottom navigation index, so any screen can switch tabs.
final tabIndex = ValueNotifier<int>(0);

/// Text to put in the catalog search when switching to it (e.g. a scan).
final catalogQuery = ValueNotifier<String>('');

String money(double v) => '${v.toStringAsFixed(2)} د.أ';

/// Company contact numbers shown in the app.
const kSupportPhone = '+962793888844';
const kSupportPhoneDisplay = '07 9388 8844';
/// WhatsApp number linked to Odoo's WhatsApp API (international, digits only).
/// Empty = the WhatsApp button is hidden until the number is filled in.
const kSupportWhatsapp = '';
const kSupportWhatsappDisplay = '';
