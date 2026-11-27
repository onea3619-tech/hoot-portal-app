import 'package:flutter/material.dart';

import 'data.dart';
import 'portal.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> scanToCatalog(BuildContext context) async {
  final code = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const ScannerPage()));
  if (code == null || code.isEmpty) return;
  catalogQuery.value = code;
  tabIndex.value = 1;
}

// ───────────────────────────── Home ─────────────────────────────

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hot = products.where((p) => p.hot).toList();
    final fresh = products.where((p) => p.isNew).toList();
    return CustomScrollView(slivers: [
      SliverToBoxAdapter(child: _Header()),
      SliverToBoxAdapter(child: _Offers()),
      const SliverToBoxAdapter(child: SectionTitle('الأقسام')),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 104,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: categories.length - 1,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final c = categories[i + 1];
              return FadeIn(
                index: i,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    catalogQuery.value = '#${c.name}';
                    tabIndex.value = 1;
                  },
                  child: SizedBox(
                    width: 78,
                    child: Column(children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: HootColors.line),
                        ),
                        child: Icon(c.icon, color: c.color, size: 30),
                      ),
                      const SizedBox(height: 6),
                      Text(c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: SectionTitle('الأكثر طلباً 🔥', onMore: () {
          catalogQuery.value = '#hot';
          tabIndex.value = 1;
        }),
      ),
      SliverToBoxAdapter(child: _HorizontalProducts(hot)),
      const SliverToBoxAdapter(child: SectionTitle('وصل حديثاً')),
      SliverToBoxAdapter(child: _HorizontalProducts(fresh)),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ]);
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(16, top + 14, 16, 22),
      decoration: const BoxDecoration(
        gradient: HootColors.heroGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('أهلاً بك 👋', style: TextStyle(color: Colors.white70, fontSize: 14)),
              Text('Hoot drug store',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: HootColors.green, borderRadius: BorderRadius.circular(20)),
            child: const Text('نسخة تجريبية',
                style: TextStyle(color: HootColors.navy, fontWeight: FontWeight.w800, fontSize: 12)),
          ),
        ]),
        const SizedBox(height: 16),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => tabIndex.value = 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(children: [
                const Icon(Icons.search_rounded, color: HootColors.muted),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('ابحث بالاسم، المادة الفعالة، المورد...',
                      style: TextStyle(color: HootColors.muted, fontSize: 14)),
                ),
                IconButton(
                  tooltip: 'مسح باركود',
                  onPressed: () => scanToCatalog(context),
                  icon: const Icon(Icons.qr_code_scanner_rounded, color: HootColors.blue),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Offers extends StatefulWidget {
  @override
  State<_Offers> createState() => _OffersState();
}

class _OffersState extends State<_Offers> {
  final _pc = PageController(viewportFraction: 0.9);
  int _page = 0;

  static const _items = [
    ('عروض البونص', 'بونص يصل إلى 10+1 على أصناف مختارة', Icons.card_giftcard_rounded,
        [Color(0xFF5E9A1E), Color(0xFF98C840)]),
    ('جهاز Joycoo Plus', 'بونص 5+1 لفترة محدودة', Icons.monitor_heart_rounded,
        [Color(0xFF1C47A8), Color(0xFF3D7BE8)]),
    ('وصل حديثاً', 'New Glucan Plus + Zinc و VIXMINT', Icons.new_releases_rounded,
        [Color(0xFF0B2545), Color(0xFF2458BF)]),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const SizedBox(height: 16),
      SizedBox(
        height: 132,
        child: PageView.builder(
          controller: _pc,
          itemCount: _items.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (_, i) {
            final (title, sub, icon, colors) = _items[i];
            return AnimatedScale(
              duration: const Duration(milliseconds: 250),
              scale: _page == i ? 1 : 0.94,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(colors: colors, begin: Alignment.topRight, end: Alignment.bottomLeft),
                  boxShadow: [BoxShadow(color: colors.first.withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 6))],
                ),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(title, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(sub, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ]),
                  ),
                  Icon(icon, size: 58, color: Colors.white.withOpacity(0.9)),
                ]),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_items.length, (i) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: _page == i ? 20 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: _page == i ? HootColors.blue : HootColors.line,
              borderRadius: BorderRadius.circular(8),
            ),
          );
        }),
      ),
    ]);
  }
}

class _HorizontalProducts extends StatelessWidget {
  const _HorizontalProducts(this.items);
  final List<Product> items;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 236,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => FadeIn(index: i, child: SizedBox(width: 170, child: ProductCard(items[i]))),
      ),
    );
  }
}

// ───────────────────────────── Catalog / search ─────────────────────────────

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _ctrl = TextEditingController();
  String _category = 'الكل';
  bool _hotOnly = false;
  bool _grid = true;

  @override
  void initState() {
    super.initState();
    catalogQuery.addListener(_applyQuery);
    _applyQuery();
  }

  @override
  void dispose() {
    catalogQuery.removeListener(_applyQuery);
    _ctrl.dispose();
    super.dispose();
  }

  void _applyQuery() {
    final q = catalogQuery.value;
    if (q.isEmpty) return;
    setState(() {
      if (q == '#hot') {
        _hotOnly = true;
        _category = 'الكل';
        _ctrl.clear();
      } else if (q.startsWith('#')) {
        _category = q.substring(1);
        _hotOnly = false;
        _ctrl.clear();
      } else {
        _ctrl.text = q;
        _category = 'الكل';
        _hotOnly = false;
      }
    });
    catalogQuery.value = '';
  }

  List<Product> get _results {
    final q = _ctrl.text.trim().toLowerCase();
    return products.where((p) {
      if (_hotOnly && !p.hot) return false;
      if (_category != 'الكل' && p.category != _category) return false;
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) ||
          p.scientific.toLowerCase().contains(q) ||
          p.vendor.toLowerCase().contains(q) ||
          p.barcode.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return SafeArea(
      bottom: false,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'اسم الصنف، المادة الفعالة، المورد، الباركود',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _ctrl.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => setState(_ctrl.clear),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _square(Icons.qr_code_scanner_rounded, () => scanToCatalog(context), filled: true),
            const SizedBox(width: 8),
            _square(_grid ? Icons.view_list_rounded : Icons.grid_view_rounded, () => setState(() => _grid = !_grid)),
          ]),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            children: [
              _chip('🔥 Hot', _hotOnly, () => setState(() => _hotOnly = !_hotOnly)),
              for (final c in categories) _chip(c.name, _category == c.name, () => setState(() => _category = c.name)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
          child: Row(children: [
            Text('${results.length} صنف متوفر', style: const TextStyle(color: HootColors.muted, fontWeight: FontWeight.w700)),
          ]),
        ),
        Expanded(
          child: results.isEmpty
              ? const _Empty(icon: Icons.search_off_rounded, title: 'ما في نتائج', sub: 'جرّب اسم ثاني أو امسح الباركود')
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _grid
                      ? GridView.builder(
                          key: const ValueKey('grid'),
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            mainAxisExtent: 236,
                          ),
                          itemCount: results.length,
                          itemBuilder: (_, i) => FadeIn(index: i, child: ProductCard(results[i])),
                        )
                      : ListView.separated(
                          key: const ValueKey('list'),
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: results.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => FadeIn(index: i, child: ProductRow(results[i])),
                        ),
                ),
        ),
      ]),
    );
  }

  Widget _square(IconData icon, VoidCallback onTap, {bool filled = false}) => Material(
        color: filled ? HootColors.blue : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: filled ? null : Border.all(color: HootColors.line),
            ),
            child: Icon(icon, color: filled ? Colors.white : HootColors.blue),
          ),
        ),
      );

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
          showCheckmark: false,
          selectedColor: HootColors.blue,
          backgroundColor: Colors.white,
          side: BorderSide(color: selected ? HootColors.blue : HootColors.line),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          labelStyle: TextStyle(
            color: selected ? Colors.white : HootColors.navy,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.title, required this.sub, this.action});
  final IconData icon;
  final String title;
  final String sub;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: HootColors.blue.withOpacity(0.08), shape: BoxShape.circle),
            child: Icon(icon, size: 54, color: HootColors.blue),
          ),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(sub, textAlign: TextAlign.center, style: const TextStyle(color: HootColors.muted)),
          if (action != null) ...[const SizedBox(height: 18), action!],
        ]),
      ),
    );
  }
}

// ───────────────────────────── Cart ─────────────────────────────

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: cart,
      builder: (context, _) {
        final lines = cart.lines.entries.toList();
        return Scaffold(
          appBar: AppBar(title: const Text('السلة', style: TextStyle(fontWeight: FontWeight.w900))),
          body: lines.isEmpty
              ? _Empty(
                  icon: Icons.shopping_cart_outlined,
                  title: 'السلة فاضية',
                  sub: 'ضيف أصناف من الرئيسية أو البحث',
                  action: FilledButton(onPressed: () => tabIndex.value = 1, child: const Text('تصفّح الأصناف')),
                )
              : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 140), children: [
                  for (final e in lines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Dismissible(
                        key: ValueKey('line-${e.key}'),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) => cart.setQty(productById(e.key), 0),
                        background: Container(
                          alignment: AlignmentDirectional.centerEnd,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          decoration: BoxDecoration(color: HootColors.danger, borderRadius: BorderRadius.circular(18)),
                          child: const Icon(Icons.delete_rounded, color: Colors.white),
                        ),
                        child: ProductRow(productById(e.key)),
                      ),
                    ),
                  const SizedBox(height: 8),
                  const Text('قائمة الأسعار (إجباري)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 8),
                  for (final pl in pricelists)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _PricelistTile(pl, selected: cart.pricelist == pl.code),
                    ),
                ]),
          bottomSheet: lines.isEmpty ? null : _CheckoutBar(),
        );
      },
    );
  }
}

class _PricelistTile extends StatelessWidget {
  const _PricelistTile(this.pl, {required this.selected});
  final Pricelist pl;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: selected ? HootColors.blue.withOpacity(0.06) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: selected ? HootColors.blue : HootColors.line, width: selected ? 1.8 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => cart.setPricelist(pl.code),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: selected ? HootColors.blue : HootColors.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(pl.label, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(pl.hint, style: const TextStyle(color: HootColors.muted, fontSize: 12)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ready = cart.pricelist != null;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 14, 16, 14 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: Row(children: [
        Expanded(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${cart.count} قطعة', style: const TextStyle(color: HootColors.muted, fontSize: 12)),
            Text(money(cart.total),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: HootColors.blue)),
          ]),
        ),
        FilledButton.icon(
          onPressed: ready ? () => _submit(context) : null,
          icon: const Icon(Icons.send_rounded),
          label: Text(ready ? 'إرسال الطلب' : 'اختر قائمة الأسعار'),
        ),
      ]),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final order = cart.submit();
    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (_, v, c) => Transform.scale(scale: v, child: c),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(color: HootColors.green, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 52),
              ),
            ),
            const SizedBox(height: 16),
            const Text('تم إرسال طلبك', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('رقم الطلب ${order.ref}', style: const TextStyle(color: HootColors.muted)),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  tabIndex.value = 3;
                },
                child: const Text('متابعة الطلب'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ───────────────────────────── Orders ─────────────────────────────

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: cart,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('طلباتي', style: TextStyle(fontWeight: FontWeight.w900))),
        body: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: cart.orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => FadeIn(index: i, child: _OrderCard(cart.orders[i])),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard(this.o);
  final Order o;

  @override
  Widget build(BuildContext context) {
    final colors = [HootColors.blue, Colors.orange, HootColors.blueLight, HootColors.greenDark];
    final d = o.date;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: HootColors.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(o.ref, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const Spacer(),
          Pill(orderStatuses[o.status], color: colors[o.status], solid: true),
        ]),
        const SizedBox(height: 4),
        Text('${d.day}/${d.month}/${d.year}  ·  ${o.items} قطعة  ·  ${o.pricelist}',
            style: const TextStyle(color: HootColors.muted, fontSize: 12.5)),
        const SizedBox(height: 14),
        Row(children: List.generate(4, (s) {
          final done = s <= o.status;
          return Expanded(
            child: Container(
              margin: const EdgeInsetsDirectional.only(end: 4),
              height: 6,
              decoration: BoxDecoration(
                color: done ? colors[o.status] : HootColors.line,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          );
        })),
        const SizedBox(height: 6),
        Row(children: [
          for (final s in orderStatuses)
            Expanded(child: Text(s, style: const TextStyle(fontSize: 10.5, color: HootColors.muted))),
        ]),
        const SizedBox(height: 10),
        Text(money(o.total), style: const TextStyle(fontWeight: FontWeight.w900, color: HootColors.blue, fontSize: 17)),
      ]),
    );
  }
}

// ───────────────────────────── Account ─────────────────────────────

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    void open(String title, String path) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => PortalPage(title: title, path: path)));
    return Scaffold(
      appBar: AppBar(title: const Text('حسابي', style: TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(gradient: HootColors.heroGradient, borderRadius: BorderRadius.circular(24)),
          child: const Row(children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: HootColors.green,
              child: Icon(Icons.local_pharmacy_rounded, color: Colors.white, size: 30),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('صيدليتي', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 19)),
                Text('الحساب يظهر هون بعد الربط مع أودو',
                    style: TextStyle(color: Colors.white70, fontSize: 12.5)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        _tile(Icons.receipt_long_rounded, 'كشف الحساب', 'من البورتال', () => open('كشف الحساب', '/my/invoices')),
        _tile(Icons.description_rounded, 'فواتيري', 'من البورتال', () => open('فواتيري', '/my/invoices')),
        _tile(Icons.assignment_return_rounded, 'المرتجعات', 'من البورتال', () => open('المرتجعات', '/my')),
        _tile(Icons.event_available_rounded, 'حجز زيارة مندوب', 'من البورتال', () => open('المواعيد', '/appointment')),
        _tile(Icons.language_rounded, 'البورتال الكامل', 'تسجيل الدخول وكل الخدمات', () => open('البورتال', '/my')),
        _tile(Icons.dns_rounded, 'إعدادات الخادم', 'Staging / Live', () => editServerDialog(context)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: HootColors.green.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Text(
            'هاي نسخة تجريبية لشكل التطبيق: الأصناف والأسعار والطلبات بيانات تجريبية، والخطوة الجاية ربطها مع أودو.',
            style: TextStyle(fontSize: 12.5, color: HootColors.navy),
          ),
        ),
      ]),
    );
  }

  Widget _tile(IconData icon, String title, String sub, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          child: ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            onTap: onTap,
            leading: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: HootColors.blue.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: HootColors.blue),
            ),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(sub, style: const TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.chevron_left_rounded),
          ),
        ),
      );
}
