import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'data.dart';
import 'login.dart';
import 'portal.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> scanToCatalog(BuildContext context) async {
  final code = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const ScannerPage()));
  if (code == null || code.isEmpty) return;
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
      final page = await api.cards(hot: true);
      if (mounted) setState(() {
        _hot = page.items;
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
        SliverToBoxAdapter(child: _Offers()),
        const SliverToBoxAdapter(child: _ScanTip()),
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
            catalogQuery.value = '#hot';
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
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
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
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(api.userName.isEmpty ? 'أهلاً بك 👋' : 'أهلاً ${api.userName} 👋',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 14)),
              const Text('Hoot drug store', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
            ]),
          ),
          IconButton(
            tooltip: 'واتساب',
            onPressed: () => launchUrl(Uri.parse('https://wa.me/$kSupportWhatsapp'), mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.chat_rounded, color: Colors.white),
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
    ('عروض البونص', 'بونص على أصناف مختارة', Icons.card_giftcard_rounded, [Color(0xFF5E9A1E), Color(0xFF98C840)], '#hot'),
    ('جهاز Joycoo Plus', 'اطلبه الآن', Icons.monitor_heart_rounded, [Color(0xFF1C47A8), Color(0xFF3D7BE8)], 'JOYCOO'),
    ('الأكثر طلباً', 'أصناف Hot Item', Icons.local_fire_department_rounded, [Color(0xFF0B2545), Color(0xFF2458BF)], '#hot'),
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
    if (q == '#hot') {
      _hot = true;
      _vendorId = 0;
      _ctrl.clear();
    } else if (q.startsWith('vendor:')) {
      _vendorId = int.tryParse(q.substring(7)) ?? 0;
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
      final page = await api.cards(search: _ctrl.text.trim(), vendorId: _vendorId, hot: _hot);
      if (!mounted || id != _reqId) return;
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
      final page = await api.cards(search: _ctrl.text.trim(), vendorId: _vendorId, hot: _hot, offset: _items.length);
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
    _reload();
  }

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
              _chip('🔥 Hot', _hot, () {
                _hot = !_hot;
                _reload();
              }),
              _chip('🏢 $_vendorLabel', _vendorId != 0, _pickVendor),
              if (_vendorId != 0)
                _chip('✕ إلغاء المورد', false, () {
                  _vendorId = 0;
                  _reload();
                }),
            ],
          ),
        ),
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
      return const EmptyState(icon: Icons.search_off_rounded, title: 'ما في نتائج', sub: 'جرّب اسم ثاني أو امسح الباركود');
    }
    final footer = _hasMore
        ? const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
        : const SizedBox(height: 24);
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
          appBar: AppBar(title: const Text('السلة', style: TextStyle(fontWeight: FontWeight.w900))),
          body: lines.isEmpty
              ? EmptyState(
                  icon: Icons.shopping_cart_outlined,
                  title: 'السلة فاضية',
                  sub: 'ضيف أصناف من الرئيسية أو البحث',
                  action: FilledButton(onPressed: () => tabIndex.value = 1, child: const Text('تصفّح الأصناف')),
                )
              : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 140), children: [
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
                        child: ProductRow(l.product),
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
          label: Text(cart.pricelistId == null ? 'اختر قائمة الأسعار' : 'إرسال الطلب'),
        ),
      ]),
    );
  }

  Future<void> _submit(BuildContext context) async {
    try {
      final url = await cart.submit();
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
              const Text('تم إرسال طلبك', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
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
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  final path = Uri.tryParse(url)?.path ?? '/my/orders';
                  openPortal(context, 'تفاصيل الطلب', path);
                },
                child: const Text('عرض تفاصيل الطلب'),
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

class _OrdersScreenState extends State<OrdersScreen> {
  List<PortalOrder>? _orders;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
    ordersVersion.addListener(_load);
  }

  @override
  void dispose() {
    ordersVersion.removeListener(_load);
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_orders == null && !_error) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error) {
      body = EmptyState(
        icon: Icons.receipt_long_rounded,
        title: 'ما قدرنا نجيب الطلبات',
        sub: 'تقدر تشوفها من البورتال',
        action: FilledButton(onPressed: () => openPortal(context, 'طلباتي', '/my/orders'), child: const Text('فتح طلباتي')),
      );
    } else if (_orders!.isEmpty) {
      body = EmptyState(
        icon: Icons.receipt_long_rounded,
        title: 'ما في طلبات لسا',
        sub: 'أول طلب بترسله بيظهر هون',
        action: FilledButton(onPressed: () => tabIndex.value = 1, child: const Text('ابدأ الطلب')),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: _orders!.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => FadeIn(index: i, child: _OrderCard(_orders![i])),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('طلباتي', style: TextStyle(fontWeight: FontWeight.w900))),
      body: body,
    );
  }
}

const _steps = ['جديد', 'مؤكد', 'بالطريق', 'تم التسليم'];

class _OrderCard extends StatelessWidget {
  const _OrderCard(this.o);
  final PortalOrder o;

  int get _step {
    if (o.state == 'draft' || o.state == 'sent') return 0;
    if (o.delivery == 'full') return 3;
    if (o.delivery == 'partial' || o.delivery == 'started') return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final cancelled = o.state == 'cancel';
    final colors = [HootColors.blue, Colors.orange, HootColors.blueLight, HootColors.greenDark];
    final step = _step;
    final color = cancelled ? HootColors.danger : colors[step];
    final d = o.date?.toLocal();
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => openPortal(context, o.name, '/my/orders/${o.id}'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: HootColors.line)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(o.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const Spacer(),
              Pill(cancelled ? 'ملغي' : _steps[step], color: color, solid: true),
            ]),
            if (d != null) ...[
              const SizedBox(height: 4),
              Text('${d.day}/${d.month}/${d.year}', style: const TextStyle(color: HootColors.muted, fontSize: 12.5)),
            ],
            if (!cancelled) ...[
              const SizedBox(height: 14),
              Row(children: List.generate(4, (s) {
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
            Text(money(o.total), style: const TextStyle(fontWeight: FontWeight.w900, color: HootColors.blue, fontSize: 17)),
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
      appBar: AppBar(title: const Text('حسابي', style: TextStyle(fontWeight: FontWeight.w900))),
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
        _tile(Icons.receipt_long_rounded, 'كشف الحساب والفواتير', '', () => openPortal(context, 'الفواتير', '/my/invoices')),
        _tile(Icons.shopping_bag_rounded, 'كل طلباتي', '', () => openPortal(context, 'طلباتي', '/my/orders')),
        _tile(Icons.event_available_rounded, 'حجز زيارة مندوب', '', () => openPortal(context, 'المواعيد', '/appointment')),
        _tile(Icons.language_rounded, 'البورتال الكامل', 'المرتجعات وكل الخدمات', () => openPortal(context, 'البورتال', '/my')),
        _tile(Icons.dns_rounded, 'إعدادات الخادم', 'Staging / Live', () => editServerDialog(context)),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text('تواصل معنا', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        ),
        Row(children: [
          Expanded(
            child: _contactBtn(Icons.call_rounded, 'اتصال', kSupportPhoneDisplay, HootColors.blue,
                () => launchUrl(Uri.parse('tel:$kSupportPhone'))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _contactBtn(Icons.chat_rounded, 'واتساب', kSupportWhatsappDisplay, const Color(0xFF25D366),
                () => launchUrl(Uri.parse('https://wa.me/$kSupportWhatsapp'), mode: LaunchMode.externalApplication)),
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
      ]),
    );
  }

  Widget _contactBtn(IconData icon, String title, String sub, Color color, VoidCallback onTap) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            child: Column(children: [
              CircleAvatar(radius: 22, backgroundColor: color, child: Icon(icon, color: Colors.white)),
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
