import 'package:flutter/material.dart';

import 'api.dart';
import 'main.dart';
import 'portal.dart';
import 'theme.dart';

void goToLogin(BuildContext context) {
  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (_) => false,
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _login = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hide = true;
  String? _error;

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_login.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'اكتب اسم المستخدم وكلمة السر');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await api.login(_login.text, _password.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const Shell()));
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : 'تعذّر الاتصال، تأكد من الإنترنت');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(24, 24, 24, 24), children: [
          const SizedBox(height: 24),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.85, end: 1),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutBack,
            builder: (_, v, c) => Transform.scale(scale: v, child: c),
            // Long-press the logo for 2 seconds: hidden server settings (for the technical team).
            child: GestureDetector(
              onLongPress: () => editServerDialog(context),
              child: Image.asset('assets/logo_full.png', height: 170),
            ),
          ),
          const SizedBox(height: 18),
          const Text('أهلاً بك في Hoot drug store',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('سجّل دخول بحساب صيدليتك لتبدأ الطلب',
              textAlign: TextAlign.center, style: TextStyle(color: HootColors.muted)),
          const SizedBox(height: 26),
          TextField(
            controller: _login,
            keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.ltr,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'اسم المستخدم أو الإيميل',
              prefixIcon: Icon(Icons.person_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: _hide,
            textDirection: TextDirection.ltr,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'كلمة السر',
              prefixIcon: const Icon(Icons.lock_rounded),
              suffixIcon: IconButton(
                icon: Icon(_hide ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                onPressed: () => setState(() => _hide = !_hide),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: _error == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: HootColors.danger, fontWeight: FontWeight.w700)),
                  ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : const Text('دخول'),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: HootColors.green.withOpacity(0.14), borderRadius: BorderRadius.circular(14)),
            child: const Row(children: [
              Icon(Icons.chat_rounded, color: HootColors.greenDark),
              SizedBox(width: 10),
              Expanded(
                child: Text('قريباً: الدخول برقم الهاتف ورمز يوصلك على واتساب',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
