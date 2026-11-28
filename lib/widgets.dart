import 'package:flutter/material.dart';

import 'api.dart';
import 'data.dart';
import 'theme.dart';

/// Small rounded label (bonus, Hot Item, available...).
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
        Flexible(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: solid ? Colors.white : color)),
        ),
      ]),
    );
  }
}

/// Product picture from Odoo, with a branded placeholder.
class ProductImage extends StatelessWidget {
  const ProductImage(this.p, {super.key, this.size = 72});
  final Product p;
  final double size;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [HootColors.blue.withOpacity(0.14), HootColors.green.withOpacity(0.2)],
        ),
      ),
      child: Icon(Icons.medication_rounded, size: size * 0.48, color: HootColors.blue),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.26),
      child: SizedBox(
        width: size,
        height: size,
        child: Image.network(
          p.imageUrl,
          headers: api.cookieHeader,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder,
          loadingBuilder: (_, child, progress) => progress == null ? child : placeholder,
        ),
      ),
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
                  decoration: BoxDecoration(gradient: HootColors.brandGradient, borderRadius: BorderRadius.circular(30)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    _btn(Icons.remove_rounded, () => cart.remove(p)),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                      child: Text('$q',
                          key: ValueKey(q),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
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

Widget priceText(Product p, {double size = 15}) => Text(
      p.price == null ? 'السعر بعد اختيار القائمة' : money(p.price!),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontWeight: FontWeight.w900,
        fontSize: p.price == null ? 11 : size,
        color: p.price == null ? HootColors.muted : HootColors.blue,
      ),
    );

/// Vertical card used in grids and horizontal lists.
class ProductCard extends StatelessWidget {
  const ProductCard(this.p, {super.key});
  final Product p;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
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
              Flexible(
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  if (p.hot) const Pill('Hot', color: HootColors.hot, icon: Icons.local_fire_department_rounded, solid: true),
                  if (p.bonus.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Pill('بونص ${p.bonus}', color: HootColors.greenDark),
                  ],
                ]),
              ),
            ]),
            const SizedBox(height: 10),
            Text(p.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, height: 1.25, color: HootColors.navy)),
            const SizedBox(height: 2),
            Text(p.vendor,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5, color: HootColors.muted)),
            const Spacer(),
            if (p.batchExp.isNotEmpty)
              Text('Batch & Exp: ${p.batchExp}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(fontSize: 10.5, color: HootColors.muted)),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: priceText(p)),
              QtyControl(p, compact: true),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// Horizontal row used in lists and the cart.
class ProductRow extends StatelessWidget {
  const ProductRow(this.p, {super.key});
  final Product p;

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
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: HootColors.navy)),
                Text(p.vendor,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: HootColors.muted)),
                const SizedBox(height: 4),
                Wrap(spacing: 4, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  if (p.hot) const Pill('Hot', color: HootColors.hot, icon: Icons.local_fire_department_rounded, solid: true),
                  if (p.bonus.isNotEmpty) Pill('بونص ${p.bonus}', color: HootColors.greenDark),
                  priceText(p, size: 13),
                ]),
              ]),
            ),
            const SizedBox(width: 6),
            QtyControl(p, compact: true),
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
          ProductImage(p, size: 96),
          const SizedBox(width: 16),
          Expanded(
            child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: HootColors.navy)),
          ),
        ]),
        const SizedBox(height: 16),
        Wrap(spacing: 6, runSpacing: 6, children: [
          Pill(p.hot ? 'Hot Item: نعم' : 'Hot Item: لا', color: p.hot ? HootColors.hot : HootColors.muted),
          Pill(p.bonus.isNotEmpty ? 'بونص ${p.bonus}' : 'بونص: لا يوجد', color: HootColors.greenDark),
        ]),
        const SizedBox(height: 14),
        _info('المورد', p.vendor),
        _info('Batch & Exp', p.batchExp.isEmpty ? '-' : p.batchExp),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: priceText(p, size: 22)),
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
        Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w700, color: HootColors.navy, fontSize: 13))),
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
        Container(
            width: 5,
            height: 20,
            decoration: BoxDecoration(gradient: HootColors.brandGradient, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 8),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: HootColors.navy))),
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
      builder: (_, v, c) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 24 * (1 - v)), child: c)),
      child: child,
    );
  }
}

/// Generic empty / error state.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.sub, this.action});
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
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(sub, textAlign: TextAlign.center, style: const TextStyle(color: HootColors.muted)),
          if (action != null) ...[const SizedBox(height: 18), action!],
        ]),
      ),
    );
  }
}

/// Pricelist chooser (mandatory before prices and ordering).
Future<void> showPricelistSheet(BuildContext context) async {
  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('اختر قائمة الأسعار', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const Text('لازم تختار قائمة عشان تظهر الأسعار والبونص وتقدر ترسل الطلب',
              style: TextStyle(color: HootColors.muted, fontSize: 12.5)),
          const SizedBox(height: 14),
          for (final pl in api.pricelists)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: cart.pricelistId == pl.id ? HootColors.blue.withOpacity(0.07) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                      color: cart.pricelistId == pl.id ? HootColors.blue : HootColors.line,
                      width: cart.pricelistId == pl.id ? 1.8 : 1),
                ),
                child: ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: Icon(
                      cart.pricelistId == pl.id ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                      color: HootColors.blue),
                  title: Text(pl.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      await cart.choosePricelist(pl.id);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                      }
                    }
                  },
                ),
              ),
            ),
        ]),
      ),
    ),
  );
}
