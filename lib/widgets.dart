import 'package:flutter/material.dart';

import 'data.dart';
import 'theme.dart';

/// Small rounded label (bonus, Hot Item, new...).
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, required this.color, this.icon, this.solid = false});
  final String text;
  final Color color;
  final IconData? icon;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: solid ? color : color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: solid ? Colors.white : color),
          const SizedBox(width: 3),
        ],
        Text(text,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: solid ? Colors.white : color)),
      ]),
    );
  }
}

/// Product picture placeholder: gradient tile with the product icon.
class ProductImage extends StatelessWidget {
  const ProductImage(this.p, {super.key, this.size = 72});
  final Product p;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cat = categories.firstWhere((c) => c.name == p.category, orElse: () => categories.first);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cat.color.withOpacity(0.16), HootColors.green.withOpacity(0.18)],
        ),
      ),
      child: Icon(p.icon, size: size * 0.5, color: cat.color),
    );
  }
}

/// Add button that turns into a - qty + stepper, animated.
class QtyControl extends StatelessWidget {
  const QtyControl(this.p, {super.key, this.compact = false});
  final Product p;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: cart,
      builder: (context, _) {
        final q = cart.qtyOf(p);
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
          child: q == 0
              ? Material(
                  key: const ValueKey('add'),
                  color: HootColors.blue,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => cart.add(p),
                    child: Padding(
                      padding: EdgeInsets.all(compact ? 6 : 8),
                      child: Icon(Icons.add_rounded, color: Colors.white, size: compact ? 18 : 22),
                    ),
                  ),
                )
              : Container(
                  key: const ValueKey('stepper'),
                  decoration: BoxDecoration(
                    gradient: HootColors.brandGradient,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    _btn(Icons.remove_rounded, () => cart.remove(p)),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                      child: Text('$q',
                          key: ValueKey(q),
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                    ),
                    _btn(Icons.add_rounded, () => cart.add(p)),
                  ]),
                ),
        );
      },
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap) => InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(compact ? 5 : 7),
          child: Icon(icon, color: Colors.white, size: compact ? 16 : 18),
        ),
      );
}

/// Vertical card used in grids and horizontal lists.
class ProductCard extends StatelessWidget {
  const ProductCard(this.p, {super.key});
  final Product p;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => showProductSheet(context, p),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: HootColors.line),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ProductImage(p, size: 58),
              const Spacer(),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                if (p.hot) const Pill('Hot', color: HootColors.hot, icon: Icons.local_fire_department_rounded, solid: true),
                if (p.bonus.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Pill('بونص ${p.bonus}', color: HootColors.greenDark),
                ],
              ]),
            ]),
            const SizedBox(height: 10),
            Text(p.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.ltr,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, height: 1.25, color: HootColors.navy)),
            const SizedBox(height: 2),
            Text(p.vendor, style: const TextStyle(fontSize: 11.5, color: HootColors.muted)),
            const Spacer(),
            Text('Batch ${p.batch} · Exp ${p.exp}',
                textDirection: TextDirection.ltr,
                style: const TextStyle(fontSize: 10.5, color: HootColors.muted)),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: ListenableBuilder(
                  listenable: cart,
                  builder: (_, __) => Text(money(cart.priceOf(p)),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: HootColors.blue)),
                ),
              ),
              QtyControl(p, compact: true),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// Horizontal row used in search results and the cart.
class ProductRow extends StatelessWidget {
  const ProductRow(this.p, {super.key, this.trailing});
  final Product p;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => showProductSheet(context, p),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            ProductImage(p, size: 56),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: HootColors.navy)),
                Text('${p.vendor} · ${p.scientific}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: HootColors.muted)),
                const SizedBox(height: 4),
                Wrap(spacing: 4, runSpacing: 4, children: [
                  if (p.hot) const Pill('Hot', color: HootColors.hot, icon: Icons.local_fire_department_rounded, solid: true),
                  if (p.bonus.isNotEmpty) Pill('بونص ${p.bonus}', color: HootColors.greenDark),
                  ListenableBuilder(
                    listenable: cart,
                    builder: (_, __) => Pill(money(cart.priceOf(p)), color: HootColors.blue),
                  ),
                ]),
              ]),
            ),
            const SizedBox(width: 6),
            trailing ?? QtyControl(p, compact: true),
          ]),
        ),
      ),
    );
  }
}

/// Bottom sheet with the product details and a big add button.
Future<void> showProductSheet(BuildContext context, Product p) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(
          child: Container(
              width: 42, height: 5, decoration: BoxDecoration(color: HootColors.line, borderRadius: BorderRadius.circular(5))),
        ),
        const SizedBox(height: 18),
        Row(children: [
          ProductImage(p, size: 84),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: HootColors.navy)),
              const SizedBox(height: 4),
              Text(p.scientific, style: const TextStyle(color: HootColors.muted)),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        Wrap(spacing: 6, runSpacing: 6, children: [
          Pill(p.hot ? 'Hot Item: نعم' : 'Hot Item: لا', color: p.hot ? HootColors.hot : HootColors.muted),
          if (p.bonus.isNotEmpty) Pill('بونص ${p.bonus}', color: HootColors.greenDark),
          if (p.isNew) const Pill('وصل حديثاً', color: HootColors.blue),
          const Pill('متوفر', color: HootColors.greenDark, icon: Icons.check_circle_rounded),
        ]),
        const SizedBox(height: 14),
        _info('المورد', p.vendor),
        _info('Batch & Exp', '${p.batch}  ·  ${p.exp}'),
        _info('الباركود', p.barcode),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: ListenableBuilder(
              listenable: cart,
              builder: (_, __) => Text(money(cart.priceOf(p)),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: HootColors.blue)),
            ),
          ),
          QtyControl(p),
        ]),
      ]),
    ),
  );
}

Widget _info(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(width: 100, child: Text(k, style: const TextStyle(color: HootColors.muted, fontSize: 13))),
        Expanded(
            child: Text(v,
                style: const TextStyle(fontWeight: FontWeight.w700, color: HootColors.navy, fontSize: 13))),
      ]),
    );

/// Section title with an optional "see all" action.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.onMore});
  final String title;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 8, 8),
      child: Row(children: [
        Container(width: 5, height: 20, decoration: BoxDecoration(gradient: HootColors.brandGradient, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 8),
        Expanded(
            child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: HootColors.navy))),
        if (onMore != null) TextButton(onPressed: onMore, child: const Text('عرض الكل')),
      ]),
    );
  }
}

/// Fade + slide in, staggered by index.
class FadeIn extends StatelessWidget {
  const FadeIn({super.key, required this.child, this.index = 0});
  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 350 + (index.clamp(0, 8) * 60)),
      curve: Curves.easeOutCubic,
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 24 * (1 - v)), child: c),
      ),
      child: child,
    );
  }
}
