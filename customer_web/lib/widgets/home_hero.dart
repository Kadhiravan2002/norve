import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:norve/core/theme/norve_theme.dart';
import 'package:norve/features/products/widgets/product_image.dart';

import '../app/breakpoints.dart';

// The same hero image as the mobile app.
const _heroImageUrl =
    'https://images.unsplash.com/photo-1539109136881-3be0616acf4b?auto=format&fit=crop&w=1600&q=90';

class HomeHero extends StatelessWidget {
  const HomeHero({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final phone = StorefrontBreakpoints.isPhone(width);
    final desktop = StorefrontBreakpoints.isDesktop(width);
    final gutter = StorefrontBreakpoints.gutter(width);
    final textTheme = Theme.of(context).textTheme;

    // The height is a minimum, so larger text grows the hero, not overflows it.
    final minHeight = width < 380
        ? 410.0
        : desktop
        ? 600.0
        : phone
        ? 440.0
        : 490.0;

    final hero = Stack(
      key: const ValueKey('home-hero'),
      children: [
        const Positioned.fill(child: ProductImage(url: _heroImageUrl)),
        Positioned.fill(
          child: ColoredBox(
            color: NorveColors.charcoal.withValues(alpha: 0.30),
          ),
        ),
        Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: minHeight),
          alignment: Alignment.bottomLeft,
          padding: EdgeInsets.fromLTRB(
            phone ? 24 : gutter,
            24,
            phone ? 24 : gutter,
            desktop ? 64 : 32,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'THE EVERYDAY EDIT',
                  style: textTheme.labelSmall?.copyWith(
                    color: NorveColors.white,
                    letterSpacing: 2.1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'A New Perspective on Everyday Style',
                  style: textTheme.headlineMedium?.copyWith(
                    color: NorveColors.white,
                    fontSize: width < 380
                        ? 31
                        : desktop
                        ? 56
                        : phone
                        ? 36
                        : 44,
                    height: 1.12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Considered essentials. Timeless silhouettes. Made for your everyday.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: NorveColors.white,
                    fontSize: desktop ? 16 : (phone ? 13 : 15),
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    key: const ValueKey('discover-collection'),
                    onPressed: () => context.go('/shop'),
                    style: FilledButton.styleFrom(
                      backgroundColor: NorveColors.ivory,
                      foregroundColor: NorveColors.charcoal,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      shape: const RoundedRectangleBorder(),
                    ),
                    child: Text(
                      'Discover the Collection',
                      style: textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    return phone
        ? Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: hero,
          )
        : hero;
  }
}
