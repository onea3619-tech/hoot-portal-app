import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'theme.dart';

/// Default server: the Odoo.sh staging (Test) branch. Changeable from the
/// account screen ("إعدادات الخادم") without rebuilding the app.
const String kDefaultBaseUrl = String.fromEnvironment(
  'BASE_URL',
  defaultValue: 'https://flex2022-alhoot-drug-test-42741321.dev.odoo.com',
);
const String _kPrefBaseUrl = 'base_url';

class AppConfig {
  static String baseUrl = kDefaultBaseUrl;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    baseUrl = prefs.getString(_kPrefBaseUrl) ?? kDefaultBaseUrl;
  }

  static Future<void> save(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefBaseUrl, url);
    baseUrl = url;
  }
}

Future<void> editServerDialog(BuildContext context) async {
  final ctrl = TextEditingController(text: AppConfig.baseUrl);
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
  await AppConfig.save(url);
}

/// Shows a page of the Odoo portal (statement, invoices, full portal...).
class PortalPage extends StatefulWidget {
  const PortalPage({super.key, required this.title, this.path = '/my'});
  final String title;
  final String path;

  @override
  State<PortalPage> createState() => _PortalPageState();
}

class _PortalPageState extends State<PortalPage> {
  late final WebViewController _c;
  int _progress = 0;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    final base = Uri.parse(AppConfig.baseUrl);
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) => setState(() => _progress = p),
        onPageStarted: (_) => setState(() => _error = false),
        onWebResourceError: (e) {
          if (e.isForMainFrame ?? true) setState(() => _error = true);
        },
        onNavigationRequest: (req) {
          final uri = Uri.tryParse(req.url);
          if (uri == null) return NavigationDecision.prevent;
          final internal = (uri.scheme == 'https' || uri.scheme == 'http') && uri.host == base.host;
          if (internal || uri.scheme == 'about' || uri.scheme == 'data' || uri.scheme == 'blob') {
            return NavigationDecision.navigate;
          }
          launchUrl(uri, mode: LaunchMode.externalApplication);
          return NavigationDecision.prevent;
        },
      ))
      ..loadRequest(Uri.parse('${AppConfig.baseUrl}${widget.path}'));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _c.canGoBack()) {
          _c.goBack();
        } else if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800)),
          actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: () => _c.reload())],
          bottom: _progress < 100
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: LinearProgressIndicator(value: _progress / 100, minHeight: 3, color: HootColors.green),
                )
              : null,
        ),
        body: _error ? OfflineView(onRetry: () => _c.reload()) : WebViewWidget(controller: _c),
      ),
    );
  }
}

/// Shown when there is no internet.
class OfflineView extends StatelessWidget {
  const OfflineView({super.key, required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(color: HootColors.danger.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.wifi_off_rounded, size: 56, color: HootColors.danger),
          ),
          const SizedBox(height: 18),
          const Text('الإنترنت مفصول', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('تأكد من اتصالك بالإنترنت (واي فاي أو بيانات الهاتف) ثم أعد المحاولة',
              textAlign: TextAlign.center, style: TextStyle(color: HootColors.muted)),
          const SizedBox(height: 22),
          FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('إعادة المحاولة')),
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('امسح باركود الصنف'),
        actions: [IconButton(icon: const Icon(Icons.flash_on_rounded), onPressed: () => _ctrl.toggleTorch())],
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
            width: 270,
            height: 170,
            decoration: BoxDecoration(
              border: Border.all(color: HootColors.green, width: 3),
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        const Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Text('وجّه الكاميرا على باركود العلبة',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 16)),
        ),
      ]),
    );
  }
}
