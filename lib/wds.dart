import 'dart:async';

import 'package:flutter/material.dart';

import 'theme.dart';

/// "W-DS" capsule shown in every app bar. Tapping it shows a small bubble:
/// Crafted by W-DS · Weam for Digital Solutions.
class WdsBadge extends StatefulWidget {
  const WdsBadge({super.key, this.onDark = false});
  final bool onDark;

  @override
  State<WdsBadge> createState() => _WdsBadgeState();
}

class _WdsBadgeState extends State<WdsBadge> {
  final _link = LayerLink();
  OverlayEntry? _entry;
  Timer? _timer;

  void _toggle() {
    if (_entry != null) {
      _hide();
      return;
    }
    _entry = OverlayEntry(
      builder: (_) => Stack(children: [
        Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _hide)),
        CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(-4, 6),
          child: const _Bubble(),
        ),
      ]),
    );
    Overlay.of(context).insert(_entry!);
    _timer = Timer(const Duration(seconds: 4), _hide);
  }

  void _hide() {
    _timer?.cancel();
    _entry?.remove();
    _entry = null;
  }

  @override
  void dispose() {
    _hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.onDark;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4, end: 12),
      child: Center(
        child: CompositedTransformTarget(
          link: _link,
          child: GestureDetector(
            onTap: _toggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: dark ? Colors.white.withOpacity(.14) : HootColors.blue.withOpacity(.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: dark ? Colors.white.withOpacity(.28) : HootColors.blue.withOpacity(.18)),
              ),
              child: Text('W-DS',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .5,
                      color: dark ? Colors.white : HootColors.blue.withOpacity(.75))),
            ),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.only(left: 18),
          child: CustomPaint(size: const Size(12, 6), painter: _Arrow()),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: HootColors.navy,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 6))],
          ),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text.rich(
              TextSpan(children: [
                TextSpan(text: 'Crafted by '),
                TextSpan(text: 'W-DS', style: TextStyle(color: HootColors.green, fontWeight: FontWeight.w900)),
              ]),
              textDirection: TextDirection.ltr,
              style: TextStyle(color: Colors.white, fontSize: 12.5),
            ),
            SizedBox(height: 2),
            Text('Weam for Digital Solutions',
                textDirection: TextDirection.ltr, style: TextStyle(color: Colors.white, fontSize: 12.5)),
          ]),
        ),
      ]),
    );
  }
}

class _Arrow extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(p, Paint()..color = HootColors.navy);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Quiet signature at the end of a page.
class WdsSignature extends StatelessWidget {
  const WdsSignature({super.key});

  @override
  Widget build(BuildContext context) {
    const muted = Color(0xFFB3BDCC);
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 8),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 46, height: 1, color: const Color(0xFFD7DEEA)),
          Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: const BoxDecoration(color: HootColors.green, shape: BoxShape.circle)),
          Container(width: 46, height: 1, color: const Color(0xFFD7DEEA)),
        ]),
        const SizedBox(height: 6),
        const Text.rich(
          TextSpan(children: [
            TextSpan(text: 'Crafted by '),
            TextSpan(text: 'W-DS', style: TextStyle(color: HootColors.blue, fontWeight: FontWeight.w800)),
          ]),
          textDirection: TextDirection.ltr,
          style: TextStyle(color: muted, fontSize: 11),
        ),
        const Text('Weam for Digital Solutions',
            textDirection: TextDirection.ltr, style: TextStyle(color: muted, fontSize: 11)),
      ]),
    );
  }
}
