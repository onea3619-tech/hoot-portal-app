import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Default server: the Odoo.sh staging (Test) branch. Can be changed from
/// the app menu ("إعدادات الخادم") without rebuilding, or at build time with
/// --dart-define=BASE_URL=https://...
const String kDefaultBaseUrl = String.fromEnvironment(
  'BASE_URL',
  defaultValue: 'https://flex2022-alhoot-drug-test-42741321.dev.odoo.com',
);
const String kPrefBaseUrl = 'base_url';
const Color kBlue = Color(0xFF0058C0);
const Color kGreen = Color(0xFF98C840);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HootApp());
}

class HootApp extends StatelessWidget {
  const HootApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'الحوت',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: kBlue, primary: kBlue, secondary: kGreen),
        useMaterial3: true,
      ),
      home: const PortalPage(),
    );
  }
}

class PortalPage extends StatefulWidget {
  const PortalPage({super.key});

  @override
  State<PortalPage> createState() => _PortalPageState();
}

class _PortalPageState extends State<PortalPage> {
  WebViewController? _controller;
  String _baseUrl = kDefaultBaseUrl;
  int _progress = 0;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(kPrefBaseUrl) ?? kDefaultBaseUrl;

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..addJavaScriptChannel('HootApp', onMessageReceived: (msg) {
        // The portal can call HootApp.postMessage('scan') to open the scanner.
        if (msg.message == 'scan') _scan();
      })
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) => setState(() => _progress = p),
        onPageStarted: (_) => setState(() => _hasError = false),
        onWebResourceError: (err) {
          if (err.isForMainFrame ?? true) setState(() => _hasError = true);
        },
        onNavigationRequest: (req) {
          final uri = Uri.tryParse(req.url);
          if (uri == null) return NavigationDecision.prevent;
          final base = Uri.parse(_baseUrl);
          final internal = (uri.scheme == 'https' || uri.scheme == 'http') && uri.host == base.host;
          if (internal || uri.scheme == 'about' || uri.scheme == 'data' || uri.scheme == 'blob') {
            return NavigationDecision.navigate;
          }
          // WhatsApp, phone, maps, PDFs on other hosts... open outside the app.
          launchUrl(uri, mode: LaunchMode.externalApplication);
          return NavigationDecision.prevent;
        },
      ));

    final ua = await controller.getUserAgent();
    await controller.setUserAgent('${ua ?? ''} HootPortalApp/0.1');
    await controller.loadRequest(Uri.parse('$_baseUrl/my'));
    setState(() => _controller = controller);
  }

  Future<void> _goHome() async => _controller?.loadRequest(Uri.parse('$_baseUrl/my'));

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScannerPage()),
    );
    if (code == null || code.isEmpty || _controller == null) return;
    final js = '''
(function(code){
  var el = document.activeElement;
  if (!el || el.tagName !== 'INPUT') {
    el = document.querySelector('input[type=search], input[name=search], input[name=q], input[placeholder*="بحث"], input[placeholder*="Search"]');
  }
  if (!el) return 'none';
  var setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
  setter.call(el, code);
  el.dispatchEvent(new Event('input', {bubbles: true}));
  el.dispatchEvent(new Event('change', {bubbles: true}));
  el.dispatchEvent(new KeyboardEvent('keydown', {key: 'Enter', keyCode: 13, bubbles: true}));
  if (el.form) { if (el.form.requestSubmit) el.form.requestSubmit(); else el.form.submit(); }
  return 'ok';
})(${jsonEncode(code)})''';
    Object? result;
    try {
      result = await _controller!.runJavaScriptReturningResult(js);
    } catch (_) {}
    if (!mounted) return;
    if (result.toString().contains('ok')) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('الباركود $code — تم نسخه، الصقه بخانة البحث')),
    );
  }

  Future<void> _editServer() async {
    final ctrl = TextEditingController(text: _baseUrl);
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إعدادات الخادم'),
        content: TextField(
          controller: ctrl,
          textDirection: TextDirection.ltr,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(labelText: 'رابط أودو'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, kDefaultBaseUrl), child: const Text('الافتراضي')),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('حفظ')),
        ],
      ),
    );
    if (value == null || value.isEmpty) return;
    var url = value.endsWith('/') ? value.substring(0, value.length - 1) : value;
    if (!url.startsWith('http')) url = 'https://$url';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPrefBaseUrl, url);
    setState(() => _baseUrl = url);
    _goHome();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (controller != null && await controller.canGoBack()) {
          controller.goBack();
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: kBlue,
          foregroundColor: Colors.white,
          toolbarHeight: 48,
          title: const Text('مستودع أدوية الحوت', style: TextStyle(fontSize: 17)),
          actions: [
            IconButton(tooltip: 'مسح باركود', icon: const Icon(Icons.qr_code_scanner), onPressed: _scan),
            IconButton(tooltip: 'تحديث', icon: const Icon(Icons.refresh), onPressed: () => controller?.reload()),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'home') _goHome();
                if (v == 'server') _editServer();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'home', child: Text('الرئيسية')),
                PopupMenuItem(value: 'server', child: Text('إعدادات الخادم')),
              ],
            ),
          ],
          bottom: _progress < 100
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: LinearProgressIndicator(value: _progress / 100, minHeight: 3, color: kGreen),
                )
              : null,
        ),
        body: controller == null
            ? const Center(child: CircularProgressIndicator())
            : _hasError
                ? _ErrorView(onRetry: () => controller.reload(), onServer: _editServer)
                : WebViewWidget(controller: controller),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry, required this.onServer});
  final VoidCallback onRetry;
  final VoidCallback onServer;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.wifi_off, size: 64, color: kBlue),
          const SizedBox(height: 16),
          const Text('تعذّر الاتصال بالخادم', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('تأكد من اتصال الإنترنت ثم أعد المحاولة', textAlign: TextAlign.center),
          const SizedBox(height: 20),
          FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة')),
          TextButton(onPressed: onServer, child: const Text('إعدادات الخادم')),
        ]),
      ),
    );
  }
}

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final MobileScannerController _ctrl = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  bool _done = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kBlue,
        foregroundColor: Colors.white,
        title: const Text('امسح باركود الصنف'),
        actions: [
          IconButton(icon: const Icon(Icons.flash_on), onPressed: () => _ctrl.toggleTorch()),
        ],
      ),
      body: Stack(children: [
        MobileScanner(
          controller: _ctrl,
          onDetect: (capture) {
            if (_done) return;
            final value = capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
            if (value == null || value.isEmpty) return;
            _done = true;
            Navigator.of(context).pop(value);
          },
        ),
        Center(
          child: Container(
            width: 260,
            height: 160,
            decoration: BoxDecoration(
              border: Border.all(color: kGreen, width: 3),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ]),
    );
  }
}
