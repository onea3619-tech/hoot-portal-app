import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'data.dart';
import 'login.dart';
import 'portal.dart';
import 'screens.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.load();
  await loadSentOrders();
  final loggedIn = await api.restore();
  runApp(HootApp(loggedIn: loggedIn));
}

class HootApp extends StatelessWidget {
  const HootApp({super.key, required this.loggedIn});
  final bool loggedIn;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hoot drug store',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildTheme(),
      home: loggedIn ? const Shell() : const LoginScreen(),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _offline = false;

  static const _pages = [HomeScreen(), CatalogScreen(), CartScreen(), OrdersScreen(), AccountScreen()];

  @override
  void initState() {
    super.initState();
    tabIndex.value = 0;
    api.track('open');
    _loadMeta();
    Connectivity().checkConnectivity().then(_onConn);
    _sub = Connectivity().onConnectivityChanged.listen(_onConn);
  }

  /// Pricelists and vendors from the quick order page, then the last
  /// chosen pricelist is selected again.
  Future<void> _loadMeta() async {
    try {
      await api.loadQuickOrderMeta();
      final p = await SharedPreferences.getInstance();
      final saved = p.getInt('pricelist_id');
      if (api.selectedPricelist != null) {
        cart.setPricelistLocal(api.selectedPricelist!);
      } else if (saved != null && api.pricelists.any((e) => e.id == saved)) {
        await cart.choosePricelist(saved);
      }
      metaVersion.value++;
      if (mounted) setState(() {});
    } catch (e) {
      if (e is ApiException && e.auth && mounted) goToLogin(context);
    }
  }

  void _onConn(List<ConnectivityResult> r) {
    final offline = r.isEmpty || r.every((e) => e == ConnectivityResult.none);
    if (mounted && offline != _offline) setState(() => _offline = offline);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: tabIndex,
      builder: (context, index, _) => PopScope(
        canPop: index == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) tabIndex.value = 0;
        },
        child: Scaffold(
          body: Column(children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              child: _offline ? _OfflineBanner() : const SizedBox(width: double.infinity),
            ),
            Expanded(child: IndexedStack(index: index, children: _pages)),
          ]),
          bottomNavigationBar: ListenableBuilder(
            listenable: cart,
            builder: (context, _) => NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (i) => tabIndex.value = i,
              destinations: [
                const NavigationDestination(
                    icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'الرئيسية'),
                const NavigationDestination(
                    icon: Icon(Icons.search_rounded), selectedIcon: Icon(Icons.manage_search_rounded), label: 'الأصناف'),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: cart.count > 0,
                    label: Text('${cart.count}'),
                    backgroundColor: HootColors.green,
                    textColor: HootColors.navy,
                    child: const Icon(Icons.shopping_cart_outlined),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: cart.count > 0,
                    label: Text('${cart.count}'),
                    backgroundColor: HootColors.green,
                    textColor: HootColors.navy,
                    child: const Icon(Icons.shopping_cart_rounded),
                  ),
                  label: 'السلة',
                ),
                const NavigationDestination(
                    icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long_rounded), label: 'طلباتي'),
                const NavigationDestination(
                    icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'حسابي'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: HootColors.danger,
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 8, 16, 10),
      child: const Row(children: [
        Icon(Icons.wifi_off_rounded, color: Colors.white),
        SizedBox(width: 10),
        Expanded(
          child: Text('الإنترنت مفصول — تأكد من الاتصال',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }
}
