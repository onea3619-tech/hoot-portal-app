import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'account_screens.dart';
import 'api.dart';
import 'data.dart';
import 'invoice_detail.dart';
import 'login.dart';
import 'portal.dart';
import 'theme.dart';
import 'wds.dart';
import 'widgets.dart';

Future<void> scanToCatalog(BuildContext context) async {
  final code = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const ScannerPage()));
  if (code == null || code.isEmpty) return;
  api.track('scan', value: code);
  catalogQuery.value = code;
  tabIndex.value = 1;
}

void handleError(BuildContext context, Object e) {
  if (e is ApiException && e.auth) {
    goToLogin(context);
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'صار خطأ، حاول مرة ثانية')));
}

void openPortal(BuildContext context, String title, String path) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PortalPage(title: title, path: path)));

// ───────────────────────────── Home ─────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Product>? _hot;
  List<Product>? _fresh;
  bool _error = false;
  int? _pl;

  @override
  void initState() {
    super.initState();
    _load();
    cart.addListener(_onCart);
  }

  @override
  void dispose() {
    cart.removeListener(_onCart);
    super.dispose();
  }

  void _onCart() {
    if (cart.pricelistId != _pl) _load();
  }

  Future<void> _load() async {
    _pl = cart.pricelistId;
    try {
      // Lists managed by staff in Odoo: Sales > App (الأكثر طلباً / Newly Received).
      final page = await api.cards(list: 'top');
      final fresh = await api.cards(list: 'new', limit: 12);
      if (mounted) setState(() {
        _hot = page.items;
        _fresh = fresh.items.take(12).toList();
        _error = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = true);
        handleError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: _Header()),
        const SliverToBoxAdapter(child: _PricelistBanner()),
        const SliverToBoxAdapter(child: RequestItemBanner()),
        SliverToBoxAdapter(child: _Offers()),
        const SliverToBoxAdapter(child: _ScanTip()),
        const SliverToBoxAdapter(child: SectionTitle('التصنيفات')),
        SliverToBoxAdapter(
          child: ValueListenableBuilder<int>(valueListenable: metaVersion, builder: (_, __, ___) => const _CategoryStrip()),
        ),
        // "وصل حديثاً" shows only the items staff register in Sales > App > Newly Received.
        if (_fresh == null || _fresh!.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: SectionTitle('وصل حديثاً ✨', onMore: () {
              catalogQuery.value = '#list:new';
              tabIndex.value = 1;
            }),
          ),
          SliverToBoxAdapter(
            child: _fresh == null
                ? const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
                : _HorizontalProducts(_fresh!),
          ),
        ],
        SliverToBoxAdapter(
          child: SectionTitle('الموردين', onMore: () {
            catalogQuery.value = '';
            tabIndex.value = 1;
          }),
        ),
        SliverToBoxAdapter(
          child: ValueListenableBuilder<int>(valueListenable: metaVersion, builder: (_, __, ___) => _VendorStrip()),
        ),
        SliverToBoxAdapter(
          child: SectionTitle('الأكثر طلباً 🔥', onMore: () {
            catalogQuery.value = '#list:top';
            tabIndex.value = 1;
          }),
        ),
        SliverToBoxAdapter(
          child: _hot == null
              ? SizedBox(
                  height: 120,
                  child: Center(
                    child: _error
                        ? TextButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('إعادة المحاولة'))
                        : const CircularProgressIndicator(),
                  ),
                )
              : _HorizontalProducts(_hot!),
        ),
        const SliverToBoxAdapter(child: WdsSignature()),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ]),
    );
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
          const HootLogo(size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(api.userName.isEmpty ? 'أهلاً بك 👋' : 'أهلاً ${api.userName} 👋',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 14)),
              const Text('Hoot drug store', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
            ]),
          ),
          const WdsBadge(onDark: true),
          Material(
            color: kWhatsappGreen,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: openWhatsapp,
              child: const Padding(
                padding: EdgeInsets.all(9),
                child: FaIcon(FontAwesomeIcons.whatsapp, color: Colors.white, size: 24),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 14),
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
                  child: Text('ابحث بالاسم، المادة الفعالة أو الباركود', style: TextStyle(color: HootColors.muted, fontSize: 14)),
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

class _PricelistBanner extends StatelessWidget {
  const _PricelistBanner();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: cart,
      builder: (context, _) {
        final chosen = cart.pricelistId != null;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Material(
            color: chosen ? Colors.white : const Color(0xFFFFF4E5),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => showPricelistSheet(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(children: [
                  Icon(chosen ? Icons.sell_rounded : Icons.warning_amber_rounded,
                      color: chosen ? HootColors.blue : Colors.orange.shade800),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      chosen ? 'قائمة الأسعار: ${cart.pricelistName}' : 'اختر قائمة الأسعار لتظهر الأسعار وتقدر تطلب',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(chosen ? 'تغيير' : 'اختيار',
                      style: const TextStyle(color: HootColors.blue, fontWeight: FontWeight.w800)),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Explains the barcode search to the pharmacist; can be hidden.
class _ScanTip extends StatefulWidget {
  const _ScanTip();

  @override
  State<_ScanTip> createState() => _ScanTipState();
}

class _ScanTipState extends State<_ScanTip> {
  bool _hidden = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted && (p.getBool('tip_scan_hidden') ?? false)) setState(() => _hidden = true);
    });
  }

  Future<void> _hide() async {
    setState(() => _hidden = true);
    final p = await SharedPreferences.getInstance();
    await p.setBool('tip_scan_hidden', true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      child: _hidden
          ? const SizedBox(width: double.infinity)
          : Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: HootColors.green, width: 1.5),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: HootColors.green.withOpacity(0.18), borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.qr_code_scanner_rounded, color: HootColors.greenDark, size: 30),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('لاقي الصنف بالكاميرا', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5)),
                    const SizedBox(height: 2),
                    const Text(
                      'بدل ما تكتب اسم الصنف: اضغط زر الكاميرا، ووجّهها على الباركود المطبوع على علبة الدواء، والتطبيق بيجيبلك الصنف فوراً لتضيفه للسلة.',
                      style: TextStyle(fontSize: 12.5, color: HootColors.muted, height: 1.45),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: HootColors.greenDark,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                      onPressed: () => scanToCatalog(context),
                      icon: const Icon(Icons.photo_camera_rounded, size: 18),
                      label: const Text('جرّب الآن'),
                    ),
                  ]),
                ),
                IconButton(
                  tooltip: 'إخفاء',
                  onPressed: _hide,
                  icon: const Icon(Icons.close_rounded, color: HootColors.muted, size: 20),
                ),
              ]),
            ),
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
    ('العروض', 'أصناف مختارة بعروض خاصة', Icons.card_giftcard_rounded, [Color(0xFF5E9A1E), Color(0xFF98C840)], '#list:offer'),
    ('وصل حديثاً', 'آخر الأصناف يلي وصلت المستودع', Icons.new_releases_rounded, [Color(0xFF1C47A8), Color(0xFF3D7BE8)], '#list:new'),
    ('الأكثر طلباً', 'أكثر الأصناف طلباً من الصيدليات', Icons.local_fire_department_rounded, [Color(0xFF0B2545), Color(0xFF2458BF)], '#list:top'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const SizedBox(height: 16),
      SizedBox(
        height: 128,
        child: PageView.builder(
          controller: _pc,
          itemCount: _items.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (_, i) {
            final (title, sub, icon, colors, query) = _items[i];
            return AnimatedScale(
              duration: const Duration(milliseconds: 250),
              scale: _page == i ? 1 : 0.94,
              child: GestureDetector(
                onTap: () {
                  catalogQuery.value = query;
                  tabIndex.value = 1;
                },
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
            decoration: BoxDecoration(color: _page == i ? HootColors.blue : HootColors.line, borderRadius: BorderRadius.circular(8)),
          );
        }),
      ),
    ]);
  }
}

const kWhatsappGreen = Color(0xFF25D366);

void openWhatsapp() {
  api.track('whatsapp');
  launchUrl(Uri.parse('https://wa.me/$kSupportWhatsapp'), mode: LaunchMode.externalApplication);
}

void callSupport() {
  api.track('call');
  launchUrl(Uri.parse('tel:$kSupportPhone'));
}

/// Product classification shown in the app ("تصنيف التطبيق" on the product
/// card in Odoo, plus Agent / Subagent).
const appCategories = [
  ('agent', 'وكالاتنا', Icons.verified_rounded, Color(0xFF2458BF)),
  ('medicine', 'أدوية', Icons.medication_rounded, Color(0xFF1C47A8)),
  ('supplement', 'مكملات غذائية', Icons.spa_rounded, Color(0xFF5E9A1E)),
  ('device', 'أجهزة ومستلزمات', Icons.monitor_heart_rounded, Color(0xFF0B2545)),
  ('care', 'عناية وتجميل', Icons.face_retouching_natural_rounded, Color(0xFF1E88E5)),
  ('baby', 'أطفال وأمومة', Icons.child_care_rounded, Color(0xFF7CB342)),
];

String categoryLabel(String key) {
  for (final c in appCategories) {
    if (c.$1 == key) return c.$2;
  }
  return key;
}

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip();

  /// Categories from Odoo (with products available), drawn with their icon.
  List<(String, String, IconData, Color)> get _cats {
    if (api.categories.isEmpty) return appCategories;
    return [
      for (final c in api.categories)
        if (c.count > 0)
          for (final a in appCategories)
            if (a.$1 == c.key) (c.key, c.label, a.$3, a.$4),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _cats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final (key, label, icon, color) = _cats[i];
          return FadeIn(
            index: i,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                catalogQuery.value = 'cat:$key';
                tabIndex.value = 1;
              },
              child: SizedBox(
                width: 80,
                child: Column(children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [color.withOpacity(0.14), HootColors.green.withOpacity(0.16)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(icon, color: color, size: 30),
                  ),
                  const SizedBox(height: 6),
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}

const _vendorColors = [HootColors.blue, HootColors.greenDark, HootColors.navy, Color(0xFF1E88E5), Color(0xFF7CB342)];

class _VendorStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final vendors = api.vendors;
    if (vendors.isEmpty) return const SizedBox(height: 8);
    return SizedBox(
      height: 112,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: vendors.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final v = vendors[i];
          final color = _vendorColors[i % _vendorColors.length];
          final letter = v.name.isEmpty ? '?' : v.name.characters.first.toUpperCase();
          return FadeIn(
            index: i,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                catalogQuery.value = 'vendor:${v.id}';
                tabIndex.value = 1;
              },
              child: SizedBox(
                width: 82,
                child: Column(children: [
                  Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: HootColors.line),
                    ),
                    child: Text(letter, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: color)),
                  ),
                  const SizedBox(height: 6),
                  Text(v.name,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, height: 1.2)),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HorizontalProducts extends StatelessWidget {
  const _HorizontalProducts(this.items);
  final List<Product> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox(height: 60, child: Center(child: Text('ما في أصناف حالياً')));
    }
    return SizedBox(
      height: 236,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => FadeIn(index: i, child: SizedBox(width: 172, child: ProductCard(items[i]))),
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
  final _scroll = ScrollController();
  Timer? _debounce;
  int _vendorId = 0;
  bool _hot = false;
  String _category = '';
  String _list = ''; // offer / new / top (Sales > App lists)
  bool _grid = true;

  final List<Product> _items = [];
  int _count = 0;
  bool _hasMore = false;
  bool _loading = false;
  bool _error = false;
  int _reqId = 0;
  int? _pl;

  @override
  void initState() {
    super.initState();
    catalogQuery.addListener(_applyQuery);
    cart.addListener(_onCart);
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) _loadMore();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (catalogQuery.value.isNotEmpty) {
        _applyQuery();
      } else {
        _reload();
      }
    });
  }

  @override
  void dispose() {
    catalogQuery.removeListener(_applyQuery);
    cart.removeListener(_onCart);
    _debounce?.cancel();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onCart() {
    if (cart.pricelistId != _pl) _reload();
  }

  void _applyQuery() {
    final q = catalogQuery.value;
    if (q.isEmpty) return;
    if (q.startsWith('#list:')) {
      _list = q.substring(6);
      _category = '';
      _vendorId = 0;
      _hot = false;
      _ctrl.clear();
      catalogQuery.value = '';
      api.track('list', value: _list);
      _reload();
      return;
    }
    _list = '';
    if (q.startsWith('cat:')) {
      _category = q.substring(4);
      api.track('category', value: _category);
      _vendorId = 0;
      _hot = false;
      _ctrl.clear();
      catalogQuery.value = '';
      _reload();
      return;
    }
    if (q == '#hot') {
      _hot = true;
      _vendorId = 0;
      _ctrl.clear();
    } else if (q.startsWith('vendor:')) {
      _vendorId = int.tryParse(q.substring(7)) ?? 0;
      api.track('vendor', value: _vendorLabel);
      _hot = false;
      _ctrl.clear();
    } else {
      _ctrl.text = q;
      _vendorId = 0;
      _hot = false;
    }
    catalogQuery.value = '';
    _reload();
  }

  Future<void> _reload() async {
    _pl = cart.pricelistId;
    final id = ++_reqId;
    setState(() {
      _loading = true;
      _error = false;
      _items.clear();
    });
    try {
      final search = _ctrl.text.trim();
      final page = await api.cards(search: search, vendorId: _vendorId, hot: _hot, category: _category, list: _list);
      if (!mounted || id != _reqId) return;
      if (search.length >= 2) api.track(page.count == 0 ? 'search_empty' : 'search', value: search, results: page.count);
      setState(() {
        _items.addAll(page.items);
        _count = page.count;
        _hasMore = page.hasMore;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || id != _reqId) return;
      setState(() {
        _loading = false;
        _error = true;
      });
      handleError(context, e);
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    final id = _reqId;
    setState(() => _loading = true);
    try {
      final page = await api.cards(search: _ctrl.text.trim(), vendorId: _vendorId, hot: _hot, category: _category, list: _list, offset: _items.length);
      if (!mounted || id != _reqId) return;
      setState(() {
        _items.addAll(page.items);
        _hasMore = page.hasMore;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearch(String _) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _reload);
  }

  Future<void> _pickCategory() async {
    final cats = api.categories.where((c) => c.count > 0).toList();
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(8, 16, 8, 16), children: [
          const Center(child: Text('اختر التصنيف', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.apps_rounded, color: HootColors.blue),
            title: const Text('كل التصنيفات', style: TextStyle(fontWeight: FontWeight.w800)),
            trailing: _category.isEmpty ? const Icon(Icons.check_rounded, color: HootColors.blue) : null,
            onTap: () => Navigator.pop(ctx, ''),
          ),
          for (final c in cats)
            ListTile(
              title: Text(c.label),
              subtitle: Text('${c.count} صنف'),
              trailing: _category == c.key ? const Icon(Icons.check_rounded, color: HootColors.blue) : null,
              onTap: () => Navigator.pop(ctx, c.key),
            ),
        ]),
      ),
    );
    if (picked == null) return;
    _category = picked;
    _list = '';
    if (picked.isNotEmpty) api.track('category', value: picked);
    _reload();
  }

  Future<void> _pickVendor() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => _VendorPicker(selected: _vendorId),
    );
    if (picked == null) return;
    _vendorId = picked;
    _list = '';
    if (picked != 0) api.track('vendor', value: _vendorLabel);
    _reload();
  }

  /// Vendors whose name matches what is typed in the search box.
  List<Vendor> get _vendorMatches {
    final q = _ctrl.text.trim().toLowerCase();
    if (q.length < 2) return const [];
    return api.vendors.where((v) => v.name.toLowerCase().contains(q)).take(8).toList();
  }

  String _listLabel(String l) => switch (l) {
        'offer' => '🎁 العروض',
        'new' => '✨ وصل حديثاً',
        'top' => '🔥 الأكثر طلباً',
        _ => l,
      };

  String get _vendorLabel {
    if (_vendorId == 0) return 'كل الموردين';
    final v = api.vendors.where((e) => e.id == _vendorId);
    return v.isEmpty ? 'المورد' : v.first.name;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(children: [
            const HootLogo(size: 34),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _ctrl,
                onChanged: _onSearch,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'اسم الصنف، المادة الفعالة، الباركود',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _ctrl.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _ctrl.clear();
                            _reload();
                          },
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
              ListenableBuilder(
                listenable: cart,
                builder: (_, __) => _chip(
                  cart.pricelistId == null ? '⚠️ اختر قائمة الأسعار' : '💲 ${cart.pricelistName}',
                  cart.pricelistId == null,
                  () => showPricelistSheet(context),
                  color: cart.pricelistId == null ? Colors.orange.shade800 : HootColors.blue,
                ),
              ),
              if (_list.isNotEmpty)
                _chip('${_listLabel(_list)}  ✕', true, () {
                  _list = '';
                  _reload();
                }, color: HootColors.greenDark),
              _chip('🔥 Hot', _hot, () {
                _hot = !_hot;
                _reload();
              }),
              _chip('📂 ${_category.isEmpty ? 'التصنيف' : categoryLabel(_category)}', _category.isNotEmpty, _pickCategory,
                  color: HootColors.greenDark),
              _chip('🏢 $_vendorLabel', _vendorId != 0, _pickVendor),

              if (_vendorId != 0)
                _chip('✕ إلغاء المورد', false, () {
                  _vendorId = 0;
                  _reload();
                }),
            ],
          ),
        ),
        if (_vendorMatches.isNotEmpty)
          SizedBox(
            height: 40,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              scrollDirection: Axis.horizontal,
              children: [
                const Center(
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(end: 6),
                    child: Text('موردين:', style: TextStyle(fontWeight: FontWeight.w800, color: HootColors.muted)),
                  ),
                ),
                for (final v in _vendorMatches)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 6),
                    child: ActionChip(
                      avatar: const Icon(Icons.storefront_rounded, size: 16, color: HootColors.blue),
                      label: Text(v.name),
                      onPressed: () {
                        _ctrl.clear();
                        _vendorId = v.id;
                        _reload();
                      },
                    ),
                  ),
              ],
            ),
          ),
        ListenableBuilder(
          listenable: cart,
          builder: (_, __) => cart.editingOrderId == null
              ? const SizedBox.shrink()
              : Container(
                  margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
                  decoration: BoxDecoration(color: HootColors.blue, borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [
                    const Icon(Icons.edit_note_rounded, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('بتضيف أصناف لطلب ${cart.editingOrderName}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    ),
                    TextButton(
                      onPressed: () => tabIndex.value = 2,
                      style: TextButton.styleFrom(foregroundColor: Colors.white),
                      child: const Text('رجوع للطلب'),
                    ),
                  ]),
                ),
        ),
        const RequestItemBanner(compact: true),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
          child: Row(children: [
            Text(_loading && _items.isEmpty ? 'جاري التحميل...' : '$_count صنف',
                style: const TextStyle(color: HootColors.muted, fontWeight: FontWeight.w700)),
          ]),
        ),
        Expanded(child: _body()),
      ]),
    );
  }

  Widget _body() {
    if (_items.isEmpty && _loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty && _error) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'ما قدرنا نجيب الأصناف',
        sub: 'تأكد من الإنترنت وحاول مرة ثانية',
        action: FilledButton(onPressed: _reload, child: const Text('إعادة المحاولة')),
      );
    }
    if (_items.isEmpty) {
      if (_list == 'offer') {
        return const EmptyState(icon: Icons.card_giftcard_rounded, title: 'ما في عروض حالياً', sub: 'تابعنا، العروض الجديدة بتنزل هون');
      }
      if (_list == 'new') {
        return const EmptyState(icon: Icons.new_releases_rounded, title: 'ما في أصناف جديدة حالياً', sub: 'الأصناف يلي بتوصل حديثاً بتظهر هون');
      }
      return ListView(children: [
        const SizedBox(height: 20),
        const EmptyState(icon: Icons.search_off_rounded, title: 'ما في نتائج', sub: 'جرّب اسم ثاني أو امسح الباركود'),
        RequestItemBanner(initialName: _ctrl.text.trim()),
      ]);
    }
    final footer = _hasMore
        ? const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
        : const Padding(padding: EdgeInsets.only(bottom: 16), child: WdsSignature());
    return RefreshIndicator(
      onRefresh: _reload,
      child: _grid
          ? CustomScrollView(controller: _scroll, slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 236,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => FadeIn(index: i % 10, child: ProductCard(_items[i])),
                    childCount: _items.length,
                  ),
                ),
              ),
              SliverToBoxAdapter(child: footer),
            ])
          : ListView.separated(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              itemCount: _items.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => i == _items.length ? footer : FadeIn(index: i % 10, child: ProductRow(_items[i])),
            ),
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

  Widget _chip(String label, bool selected, VoidCallback onTap, {Color color = HootColors.blue}) => Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
          showCheckmark: false,
          selectedColor: color,
          backgroundColor: Colors.white,
          side: BorderSide(color: selected ? color : HootColors.line),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          labelStyle: TextStyle(color: selected ? Colors.white : HootColors.navy, fontWeight: FontWeight.w700),
        ),
      );
}

class _VendorPicker extends StatefulWidget {
  const _VendorPicker({required this.selected});
  final int selected;

  @override
  State<_VendorPicker> createState() => _VendorPickerState();
}

class _VendorPickerState extends State<_VendorPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final list = api.vendors.where((v) => _q.isEmpty || v.name.toLowerCase().contains(_q.toLowerCase())).toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(children: [
        const SizedBox(height: 14),
        const Text('اختر المورد', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: (v) => setState(() => _q = v),
            decoration: const InputDecoration(hintText: 'ابحث عن مورد', prefixIcon: Icon(Icons.search_rounded)),
          ),
        ),
        Expanded(
          child: ListView(children: [
            ListTile(
              leading: const Icon(Icons.apps_rounded, color: HootColors.blue),
              title: const Text('كل الموردين', style: TextStyle(fontWeight: FontWeight.w800)),
              trailing: widget.selected == 0 ? const Icon(Icons.check_rounded, color: HootColors.blue) : null,
              onTap: () => Navigator.pop(context, 0),
            ),
            for (final v in list)
              ListTile(
                title: Text(v.name),
                trailing: widget.selected == v.id ? const Icon(Icons.check_rounded, color: HootColors.blue) : null,
                onTap: () => Navigator.pop(context, v.id),
              ),
          ]),
        ),
      ]),
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
        final lines = cart.lines.values.toList();
        return Scaffold(
          appBar: AppBar(
            title: HootTitle(cart.editingOrderId == null ? 'السلة' : 'تعديل الطلب ${cart.editingOrderName}',
                style: const TextStyle(fontWeight: FontWeight.w900)),
            actions: [
              if (cart.editingOrderId != null)
                TextButton(onPressed: cart.stopEditing, child: const Text('إلغاء التعديل')),
              const WdsBadge(),
            ],
          ),
          body: lines.isEmpty
              ? EmptyState(
                  icon: Icons.shopping_cart_outlined,
                  title: 'السلة فاضية',
                  sub: 'ضيف أصناف من الرئيسية أو البحث',
                  action: FilledButton(onPressed: () => tabIndex.value = 1, child: const Text('تصفّح الأصناف')),
                )
              : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 140), children: [
                  if (cart.editingOrderId != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(color: HootColors.blue.withOpacity(0.07), borderRadius: BorderRadius.circular(16)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        const Text('عدّل الكميات، احذف أصناف، أو ضيف أصناف جديدة، وبعدين اضغط "حفظ التعديل".',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: () => tabIndex.value = 1,
                          icon: const Icon(Icons.add_shopping_cart_rounded),
                          label: const Text('إضافة أصناف للطلب'),
                        ),
                      ]),
                    ),
                  ],
                  for (final l in lines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Dismissible(
                        key: ValueKey('line-${l.product.id}'),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) => cart.setQty(l.product, 0),
                        background: Container(
                          alignment: AlignmentDirectional.centerEnd,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          decoration: BoxDecoration(color: HootColors.danger, borderRadius: BorderRadius.circular(18)),
                          child: const Icon(Icons.delete_rounded, color: Colors.white),
                        ),
                        child: Row(children: [
                          Expanded(child: ProductRow(l.product)),
                          IconButton(
                            tooltip: 'حذف الصنف',
                            onPressed: () => cart.setQty(l.product, 0),
                            icon: const Icon(Icons.delete_outline_rounded, color: HootColors.danger),
                          ),
                        ]),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Material(
                    color: cart.pricelistId == null ? const Color(0xFFFFF4E5) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    child: ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      leading: Icon(cart.pricelistId == null ? Icons.warning_amber_rounded : Icons.sell_rounded,
                          color: cart.pricelistId == null ? Colors.orange.shade800 : HootColors.blue),
                      title: Text(
                        cart.pricelistId == null ? 'اختر قائمة الأسعار (إجباري)' : 'قائمة الأسعار: ${cart.pricelistName}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      trailing: const Icon(Icons.chevron_left_rounded),
                      onTap: () => showPricelistSheet(context),
                    ),
                  ),
                ]),
          bottomSheet: lines.isEmpty ? null : const _CheckoutBar(),
        );
      },
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar();

  @override
  Widget build(BuildContext context) {
    final ready = cart.pricelistId != null && !cart.sending;
    final total = cart.serverTotal.isNotEmpty ? cart.serverTotal : money(cart.localTotal);
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
            Text('${cart.lines.length} صنف · ${cart.count} قطعة', style: const TextStyle(color: HootColors.muted, fontSize: 12)),
            Text(total,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19, color: HootColors.blue)),
          ]),
        ),
        FilledButton.icon(
          onPressed: ready
              ? () => _submit(context)
              : (cart.pricelistId == null ? () => showPricelistSheet(context) : null),
          icon: cart.sending
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send_rounded),
          label: Text(cart.pricelistId == null
              ? 'اختر قائمة الأسعار'
              : (cart.editingOrderId != null ? 'حفظ التعديل' : 'إرسال الطلب')),
        ),
      ]),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final editing = cart.editingOrderId != null;
    try {
      await cart.submit();
      ordersVersion.value++;
      if (!context.mounted) return;
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
              Text(editing ? 'تم حفظ التعديل' : 'تم إرسال طلبك',
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              const Text('بنبلّشه بأسرع وقت', style: TextStyle(color: HootColors.muted)),
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
    } catch (e) {
      if (context.mounted) handleError(context, e);
    }
  }
}

// ───────────────────────────── Orders ─────────────────────────────

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrderItem {
  final String name;
  final DateTime? date;
  final String total;
  final int step; // -1 cancelled, 0 new .. 3 delivered
  final VoidCallback onTap;
  _OrderItem(this.name, this.date, this.total, this.step, this.onTap);
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<PortalOrder>? _orders;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
    ordersVersion.addListener(_load);
    sentOrders.addListener(_rebuild);
  }

  @override
  void dispose() {
    ordersVersion.removeListener(_load);
    sentOrders.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  Future<void> _load() async {
    try {
      final o = await api.orders();
      if (mounted) setState(() {
        _orders = o;
        _error = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = true);
      if (e is ApiException && e.auth) handleError(context, e);
    }
  }

  /// مسودة = quotation, مؤكدة = sales order, جاهز = posted invoice.
  static int _stepOf(PortalOrder o) {
    if (o.state == 'cancel') return -1;
    if (o.state == 'draft' || o.state == 'sent') return 0;
    if (o.invoiced) return 2;
    return 1;
  }

  List<_OrderItem> _items(BuildContext context) {
    final server = _orders ?? [];
    final known = {for (final o in server) o.id};
    final items = <_OrderItem>[
      // Orders just sent from the app that Odoo doesn't list yet
      for (final s in sentOrders.value)
        if (!known.contains(s.id))
          _OrderItem('طلب رقم ${s.id}', s.date, s.total, 0, () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => SentOrderScreen(order: s)));
          }),
      for (final o in server)
        _OrderItem(o.name, o.date?.toLocal(), money(o.total), _stepOf(o), () {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderDetailScreen(order: o)));
        }),
    ];
    items.sort((a, b) => (b.date ?? DateTime(2000)).compareTo(a.date ?? DateTime(2000)));
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final items = _items(context);
    Widget body;
    if (_orders == null && !_error && items.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (items.isEmpty) {
      body = EmptyState(
        icon: Icons.receipt_long_rounded,
        title: _error ? 'ما قدرنا نجيب الطلبات' : 'ما في طلبات لسا',
        sub: _error ? 'تأكد من الإنترنت وحاول مرة ثانية' : 'أول طلب بترسله بيظهر هون',
        action: FilledButton(
          onPressed: _error ? _load : () => tabIndex.value = 1,
          child: Text(_error ? 'إعادة المحاولة' : 'ابدأ الطلب'),
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: items.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => i == items.length ? const WdsSignature() : FadeIn(index: i, child: _OrderCard(items[i])),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(actions: const [WdsBadge()], title: const HootTitle('طلباتي', style: TextStyle(fontWeight: FontWeight.w900))),
      body: body,
    );
  }
}

const _steps = ['مسودة', 'مؤكدة', 'جاهز'];
const _stepColors = [HootColors.blue, Colors.orange, HootColors.greenDark];

class _OrderCard extends StatelessWidget {
  const _OrderCard(this.o);
  final _OrderItem o;

  @override
  Widget build(BuildContext context) {
    final cancelled = o.step < 0;
    final step = cancelled ? 0 : o.step;
    final color = cancelled ? HootColors.danger : _stepColors[step];
    final d = o.date;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: o.onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: HootColors.line)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(o.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
              Pill(cancelled ? 'ملغي' : _steps[step], color: color, solid: true),
            ]),
            if (d != null) ...[
              const SizedBox(height: 4),
              Text('${d.day}/${d.month}/${d.year}', style: const TextStyle(color: HootColors.muted, fontSize: 12.5)),
            ],
            if (!cancelled) ...[
              const SizedBox(height: 14),
              Row(children: List.generate(_steps.length, (s) {
                return Expanded(
                  child: Container(
                    margin: const EdgeInsetsDirectional.only(end: 4),
                    height: 6,
                    decoration: BoxDecoration(color: s <= step ? color : HootColors.line, borderRadius: BorderRadius.circular(6)),
                  ),
                );
              })),
              const SizedBox(height: 6),
              Row(children: [
                for (final s in _steps) Expanded(child: Text(s, style: const TextStyle(fontSize: 10.5, color: HootColors.muted))),
              ]),
            ],
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: Text(o.total, style: const TextStyle(fontWeight: FontWeight.w900, color: HootColors.blue, fontSize: 17)),
              ),
              const Icon(Icons.chevron_left_rounded, color: HootColors.muted),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// Lines of an order or invoice, read from Odoo with the pharmacy's access.
class _LinesView extends StatelessWidget {
  const _LinesView({required this.header, required this.future, required this.total});
  final Widget header;
  final Future<List<DocLine>> future;
  final String total;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DocLine>>(
      future: future,
      builder: (context, snap) {
        return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
          header,
          const SizedBox(height: 14),
          const Text('الأصناف', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 8),
          if (snap.connectionState != ConnectionState.done)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
          else if (snap.hasError)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('ما قدرنا نجيب الأصناف')))
          else
            for (final l in snap.data!)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                      const SizedBox(height: 2),
                      Row(children: [
                        Text('${_qty(l.qty)} × ${money(l.price)}', style: const TextStyle(color: HootColors.muted, fontSize: 12)),
                        if (l.bonus > 0) ...[const SizedBox(width: 6), BonusChip('+${_qty(l.bonus)} بونص')],
                      ]),
                    ]),
                  ),
                  Text(money(l.subtotal), style: const TextStyle(fontWeight: FontWeight.w900, color: HootColors.navy)),
                ]),
              ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(gradient: HootColors.brandGradient, borderRadius: BorderRadius.circular(18)),
            child: Row(children: [
              const Expanded(child: Text('الإجمالي', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
              Text(total, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
            ]),
          ),
        ]);
      },
    );
  }

  static String _qty(double q) => q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(2);
}

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.order});
  final PortalOrder order;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Future<Map> _future = _load();
  bool _busy = false;

  Future<Map> _load() async {
    final r = await api.jcall('/hoot_app/order', {'order_id': widget.order.id});
    if (r is! Map || r['error'] != null) throw ApiException('ما قدرنا نجيب الطلب');
    return r;
  }

  int _step(Map o) {
    final st = o['state'];
    if (st == 'cancel') return -1;
    if (st == 'draft' || st == 'sent') return 0;
    if (o['invoiced'] == true) return 2;
    return 1;
  }

  void _edit(Map o) {
    final lines = <CartLine>[
      for (final l in (o['lines'] as List))
        CartLine(
          Product(
            id: l['product_id'] as int,
            name: (l['name'] ?? '').toString(),
            vendor: '',
            hot: false,
            bonus: '',
            available: true,
            batchExp: '',
            price: (l['price_unit'] as num?)?.toDouble(),
          ),
          ((l['qty'] as num?) ?? 0).round(),
        ),
    ];
    cart.startEditing(o['id'] as int, (o['name'] ?? '').toString(), o['pricelist_id'] as int?, lines);
    Navigator.of(context).popUntil((r) => r.isFirst);
    tabIndex.value = 2;
  }

  Future<void> _cancel(Map o) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء الطلب'),
        content: Text('أكيد بدك تلغي الطلب ${o['name']}؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('لا')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: HootColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('نعم، ألغِ الطلب'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final r = await api.jcall('/hoot_app/order/cancel', {'order_id': o['id']});
      if (r is Map && r['ok'] == true) {
        ordersVersion.value++;
        setState(() => _future = _load());
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الطلب تأكد وما عاد ينفع يتلغى')));
      }
    } catch (e) {
      if (mounted) handleError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(actions: const [WdsBadge()], title: HootTitle(widget.order.name, style: const TextStyle(fontWeight: FontWeight.w900))),
      body: FutureBuilder<Map>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'ما قدرنا نجيب الطلب',
              sub: 'تأكد من الإنترنت وحاول مرة ثانية',
              action: FilledButton(onPressed: () => setState(() => _future = _load()), child: const Text('إعادة المحاولة')),
            );
          }
          final o = snap.data!;
          final step = _step(o);
          final cancelled = step < 0;
          final d = DateTime.tryParse('${o['date']}Z')?.toLocal();
          final lines = [
            for (final l in (o['lines'] as List))
              DocLine((l['name'] ?? '').toString(), ((l['qty'] as num?) ?? 0).toDouble(),
                  ((l['price_unit'] as num?) ?? 0).toDouble(), ((l['subtotal'] as num?) ?? 0).toDouble(),
                  ((l['bonus'] as num?) ?? 0).toDouble()),
          ];
          final invoices = (o['invoices'] as List? ?? []);
          return Column(children: [
            Expanded(
              child: _LinesView(
                future: Future.value(lines),
                total: money(((o['amount_total'] as num?) ?? 0).toDouble()),
                header: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(
                        child: Text(d == null ? '' : 'تاريخ الطلب: ${d.day}/${d.month}/${d.year}',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      Pill(cancelled ? 'ملغي' : _steps[step],
                          color: cancelled ? HootColors.danger : _stepColors[step], solid: true),
                    ]),
                    const SizedBox(height: 6),
                    Text('قائمة الأسعار: ${o['pricelist'] ?? ''}', style: const TextStyle(color: HootColors.muted)),
                    Text('قبل الضريبة: ${money(((o['amount_untaxed'] as num?) ?? 0).toDouble())}   ·   الضريبة: ${money(((o['amount_tax'] as num?) ?? 0).toDouble())}',
                        style: const TextStyle(color: HootColors.muted, fontSize: 12.5)),
                    for (final inv in invoices) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: InvoiceDetailsButton(moveId: inv['id'] as int, label: 'تفاصيل الفاتورة ${inv['name']}'),
                      ),
                    ],
                  ]),
                ),
              ),
            ),
            if (o['editable'] == true)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Row(children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _busy ? null : () => _edit(o),
                        icon: const Icon(Icons.edit_rounded),
                        label: const Text('تعديل الطلب'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: HootColors.danger,
                        side: const BorderSide(color: HootColors.danger),
                        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _busy ? null : () => _cancel(o),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('إلغاء'),
                    ),
                  ]),
                ),
              ),
          ]);
        },
      ),
    );
  }
}

/// An order just sent from the app (still a quotation in Odoo).
class SentOrderScreen extends StatelessWidget {
  const SentOrderScreen({super.key, required this.order});
  final SentOrder order;

  @override
  Widget build(BuildContext context) {
    final d = order.date;
    return Scaffold(
      appBar: AppBar(actions: const [WdsBadge()], title: HootTitle('طلب رقم ${order.id}', style: const TextStyle(fontWeight: FontWeight.w900))),
      body: _LinesView(
        future: Future.value([
          for (final l in order.lines)
            DocLine(
              (l['name'] ?? '').toString(),
              (l['qty'] as num? ?? 0).toDouble(),
              (l['price'] as num? ?? 0).toDouble(),
              (l['qty'] as num? ?? 0).toDouble() * (l['price'] as num? ?? 0).toDouble(),
            ),
        ]),
        total: order.total,
        header: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text('تاريخ الطلب: ${d.day}/${d.month}/${d.year}', style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              Pill(_steps[0], color: _stepColors[0], solid: true),
            ]),
            const SizedBox(height: 8),
            const Text('الطلب وصلنا كمسودة، وبيتأكد من قبل فريق المبيعات.',
                style: TextStyle(color: HootColors.muted, fontSize: 12.5)),
          ]),
        ),
      ),
    );
  }
}

// ───────────────────────────── Invoices / statement ─────────────────────────────

String _payLabel(Invoice m) {
  if (m.isRefund) return 'مرتجع';
  switch (m.paymentState) {
    case 'paid':
    case 'in_payment':
      return 'مدفوعة';
    case 'partial':
      return 'مدفوعة جزئياً';
    case 'reversed':
      return 'معكوسة';
    default:
      final due = m.due;
      if (due != null && due.isBefore(DateTime.now())) return 'متأخرة';
      return 'غير مدفوعة';
  }
}

Color _payColor(String label) {
  switch (label) {
    case 'مدفوعة':
      return HootColors.greenDark;
    case 'مدفوعة جزئياً':
      return Colors.orange;
    case 'متأخرة':
      return HootColors.danger;
    case 'مرتجع':
      return HootColors.navy;
    default:
      return HootColors.blue;
  }
}

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  late Future<List<Invoice>> _future = api.invoices();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(actions: const [WdsBadge()], title: const HootTitle('كشف الحساب والفواتير', style: TextStyle(fontWeight: FontWeight.w900))),
      body: FutureBuilder<List<Invoice>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'ما قدرنا نجيب الفواتير',
              sub: 'تأكد من الإنترنت وحاول مرة ثانية',
              action: FilledButton(
                onPressed: () => setState(() => _future = api.invoices()),
                child: const Text('إعادة المحاولة'),
              ),
            );
          }
          final list = snap.data!;
          double due = 0, overdue = 0;
          final now = DateTime.now();
          for (final m in list) {
            final r = m.isRefund ? -m.residual : m.residual;
            due += r;
            if (!m.isRefund && m.residual > 0 && m.due != null && m.due!.isBefore(now)) overdue += m.residual;
          }
          return RefreshIndicator(
            onRefresh: () async => setState(() => _future = api.invoices()),
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(gradient: HootColors.heroGradient, borderRadius: BorderRadius.circular(24)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('الرصيد المستحق', style: TextStyle(color: Colors.white70)),
                  Text(money(due), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Pill('متأخر: ${money(overdue)}', color: overdue > 0 ? HootColors.hot : HootColors.green, solid: true),
                    const SizedBox(width: 6),
                    Pill('${list.length} مستند', color: Colors.white),
                  ]),
                ]),
              ),
              const SizedBox(height: 14),
              if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('ما في فواتير ظاهرة لحسابك لحد الآن')),
                ),
              for (final m in list) _invoiceTile(context, m),
              const WdsSignature(),
            ]),
          );
        },
      ),
    );
  }

  Widget _invoiceTile(BuildContext context, Invoice m) {
    final label = _payLabel(m);
    final d = m.date;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => InvoiceDetailScreen(invoice: m))),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: _payColor(label).withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                child: Icon(m.isRefund ? Icons.assignment_return_rounded : Icons.description_rounded, color: _payColor(label)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(m.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                  Text(d == null ? '' : '${d.day}/${d.month}/${d.year}', style: const TextStyle(color: HootColors.muted, fontSize: 12)),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(money(m.total), style: const TextStyle(fontWeight: FontWeight.w900, color: HootColors.navy)),
                const SizedBox(height: 4),
                Pill(label, color: _payColor(label)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class InvoiceDetailScreen extends StatelessWidget {
  const InvoiceDetailScreen({super.key, required this.invoice});
  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final label = _payLabel(invoice);
    final d = invoice.date;
    final due = invoice.due;
    return Scaffold(
      appBar: AppBar(actions: const [WdsBadge()], title: HootTitle(invoice.name, style: const TextStyle(fontWeight: FontWeight.w900))),
      body: _LinesView(
        future: api.invoiceLines(invoice.id),
        total: money(invoice.total),
        header: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(d == null ? '' : 'التاريخ: ${d.day}/${d.month}/${d.year}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              Pill(label, color: _payColor(label), solid: true),
            ]),
            if (due != null) ...[
              const SizedBox(height: 6),
              Text('الاستحقاق: ${due.day}/${due.month}/${due.year}', style: const TextStyle(color: HootColors.muted)),
            ],
            if (invoice.residual > 0) ...[
              const SizedBox(height: 6),
              Text('المتبقي: ${money(invoice.residual)}',
                  style: const TextStyle(color: HootColors.danger, fontWeight: FontWeight.w800)),
            ],
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: InvoiceDetailsButton(moveId: invoice.id, label: 'عرض التفاصيل الكاملة')),
          ]),
        ),
      ),
    );
  }
}

// ───────────────────────────── Account ─────────────────────────────

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(actions: const [WdsBadge()], title: const HootTitle('حسابي', style: TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(gradient: HootColors.heroGradient, borderRadius: BorderRadius.circular(24)),
          child: Row(children: [
            const CircleAvatar(
              radius: 28,
              backgroundColor: HootColors.green,
              child: Icon(Icons.local_pharmacy_rounded, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(api.userName.isEmpty ? 'حسابي' : api.userName,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 19)),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        _tile(Icons.account_balance_wallet_rounded, 'كشف الحساب والفواتير', 'الرصيد المستحق وكل الفواتير',
            () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InvoicesScreen()))),
        _tile(Icons.shopping_bag_rounded, 'طلباتي', 'حالة كل طلب وأصنافه', () => tabIndex.value = 3),
        _tile(Icons.manage_search_rounded, 'أصناف طلبتها', 'في أصناف ما لقيتها؟ سجلها وتابع رد المشتريات',
            () => _go(context, const RequestedItemsScreen())),
        _tile(Icons.assignment_return_rounded, 'المرتجعات', 'طلبات المرتجع وطلب مرتجع جديد', () => _go(context, const ReturnsScreen())),
        _tile(Icons.badge_rounded, 'بطاقتي', 'بيانات الصيدلية وقائمة الأسعار والمنطقة', () => _go(context, const CardScreen())),
        _tile(Icons.event_available_rounded, 'المواعيد', 'حجز زيارة مندوب أو يوم طبي، ومواعيدي', () => _go(context, const AppointmentsScreen())),
        _tile(Icons.support_agent_rounded, 'الدعم والشكاوى', 'طلبات الدعم ومتابعتها', () => _go(context, const TicketsScreen())),
        _tile(Icons.manage_accounts_rounded, 'بياناتي', 'الهاتف والإيميل والعنوان', () => _go(context, const DetailsScreen())),
        _tile(Icons.lock_rounded, 'الأمان وكلمة السر', 'تغيير كلمة السر', () => _go(context, const PasswordScreen())),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text('تواصل معنا', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        ),
        Row(children: [
          Expanded(
            child: _contactBtn(const Icon(Icons.call_rounded, color: Colors.white), 'اتصال', kSupportPhoneDisplay,
                HootColors.blue, callSupport),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _contactBtn(const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.white), 'واتساب',
                kSupportWhatsappDisplay, kWhatsappGreen, openWhatsapp),
          ),
        ]),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: HootColors.danger,
            side: const BorderSide(color: HootColors.danger),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: () async {
            await api.logout();
            cart.clear();
            if (context.mounted) goToLogin(context);
          },
          icon: const Icon(Icons.logout_rounded),
          label: const Text('تسجيل الخروج', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        const WdsSignature(),
      ]),
    );
  }

  void _go(BuildContext context, Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  Widget _contactBtn(Widget icon, String title, String sub, Color color, VoidCallback onTap) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            child: Column(children: [
              CircleAvatar(radius: 22, backgroundColor: color, child: icon),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(sub, textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 12, color: HootColors.muted)),
            ]),
          ),
        ),
      );

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
            subtitle: sub.isEmpty ? null : Text(sub, style: const TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.chevron_left_rounded),
          ),
        ),
      );
}
