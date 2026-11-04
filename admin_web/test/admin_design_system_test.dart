import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:norve/core/auth/application_role_provider.dart';
import 'package:norve/core/supabase/supabase_providers.dart';
import 'package:norve/core/theme/norve_theme.dart';
import 'package:norve/features/admin/admin_shell.dart';
import 'package:norve/features/admin/widgets/admin_widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('Admin Design System Components', () {
    testWidgets('AdminPageHeader renders editorial title, subtitle and actions',
        (tester) async {
      var actionTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: NorveTheme.light,
          home: Scaffold(
            body: AdminPageHeader(
              title: 'Product Catalogue',
              subtitle: 'Manage seasonal releases and luxury inventory.',
              actions: [
                AdminButton.primary(
                  label: 'Add product',
                  icon: const Icon(Icons.add),
                  onPressed: () => actionTapped = true,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Product Catalogue'), findsOneWidget);
      expect(
        find.text('Manage seasonal releases and luxury inventory.'),
        findsOneWidget,
      );
      expect(find.text('Add product'), findsOneWidget);

      await tester.tap(find.text('Add product'));
      expect(actionTapped, isTrue);
    });

    testWidgets('AdminCard renders content with refined architectural borders',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: NorveTheme.light,
          home: const Scaffold(
            body: AdminCard(
              title: 'Catalogue Metrics',
              subtitle: 'Active inventory and variant units',
              child: Text('Card Body Content'),
            ),
          ),
        ),
      );

      expect(find.text('Catalogue Metrics'), findsOneWidget);
      expect(
        find.text('Active inventory and variant units'),
        findsOneWidget,
      );
      expect(find.text('Card Body Content'), findsOneWidget);
    });

    testWidgets('AdminButton variants (primary, secondary, destructive, ghost)',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: NorveTheme.light,
          home: const Scaffold(
            body: Column(
              children: [
                AdminButton.primary(label: 'Save Changes'),
                AdminButton.secondary(label: 'Cancel'),
                AdminButton.destructive(label: 'Delete Product'),
                AdminButton.ghost(label: 'View details'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Save Changes'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete Product'), findsOneWidget);
      expect(find.text('View details'), findsOneWidget);
    });

    testWidgets('AdminBadge renders appropriate status styling with dot',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: NorveTheme.light,
          home: const Scaffold(
            body: Column(
              children: [
                AdminBadge.success(label: 'Delivered', showDot: true),
                AdminBadge.warning(label: 'Low Stock', showDot: true),
                AdminBadge.error(label: 'Cancelled', showDot: true),
                AdminBadge.draft(label: 'Draft'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Delivered'), findsOneWidget);
      expect(find.text('Low Stock'), findsOneWidget);
      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.text('Draft'), findsOneWidget);
    });

    testWidgets('AdminSearchField manages queries and clear action',
        (tester) async {
      final controller = TextEditingController(text: 'Watch');
      String? updatedQuery;

      await tester.pumpWidget(
        MaterialApp(
          theme: NorveTheme.light,
          home: Scaffold(
            body: AdminSearchField(
              controller: controller,
              onChanged: (val) => updatedQuery = val,
            ),
          ),
        ),
      );

      expect(find.text('Watch'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(controller.text, isEmpty);
      expect(updatedQuery, isEmpty);
    });

    testWidgets('AdminTable renders structured headers and rows',
        (tester) async {
      var rowTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: NorveTheme.light,
          home: Scaffold(
            body: AdminTable(
              children: [
                const AdminTableHeader(
                  children: [
                    AdminTableHeaderCell(label: 'Product', flex: 2),
                    AdminTableHeaderCell(label: 'SKU', flex: 1),
                    AdminTableHeaderCell(label: 'Stock', flex: 1),
                  ],
                ),
                AdminTableRow(
                  onTap: () => rowTapped = true,
                  children: const [
                    AdminTableCell(
                      flex: 2,
                      child: Text('Cashmere Sweater'),
                    ),
                    AdminTableCell(
                      flex: 1,
                      child: Text('CSH-001'),
                    ),
                    AdminTableCell(
                      flex: 1,
                      child: Text('14 units'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('PRODUCT'), findsOneWidget);
      expect(find.text('SKU'), findsOneWidget);
      expect(find.text('STOCK'), findsOneWidget);
      expect(find.text('Cashmere Sweater'), findsOneWidget);
      expect(find.text('CSH-001'), findsOneWidget);

      await tester.tap(find.text('Cashmere Sweater'));
      expect(rowTapped, isTrue);
    });

    testWidgets('AdminEmptyState and AdminConfirmationDialog render accurately',
        (tester) async {
      var confirmed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: NorveTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  const AdminEmptyState(
                    title: 'No Orders Yet',
                    message: 'When customers purchase items, orders appear here.',
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final result = await AdminConfirmationDialog.show(
                        context,
                        title: 'Delete Product',
                        message: 'This cannot be undone.',
                        isDestructive: true,
                        confirmLabel: 'Delete',
                      );
                      if (result == true) confirmed = true;
                    },
                    child: const Text('Open Dialog'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('No Orders Yet'), findsOneWidget);
      expect(
        find.text('When customers purchase items, orders appear here.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Product'), findsOneWidget);
      expect(find.text('This cannot be undone.'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(confirmed, isTrue);
    });

    test('AdminMotion tokens adhere to timing and curve specifications', () {
      expect(AdminMotion.micro, const Duration(milliseconds: 120));
      expect(AdminMotion.hover, const Duration(milliseconds: 160));
      expect(AdminMotion.component, const Duration(milliseconds: 200));
      expect(AdminMotion.modal, const Duration(milliseconds: 220));
      expect(AdminMotion.expand, const Duration(milliseconds: 240));

      expect(AdminMotion.curveFast, Curves.easeOutCubic);
      expect(AdminMotion.curveStandard, Curves.easeInOutCubic);
      expect(AdminMotion.curveDecelerate, Curves.easeOutQuart);
    });

    testWidgets('AdminMotion respects reduced-motion accessibility preference', (tester) async {
      Duration? normalResult;
      Duration? reducedResult;
      bool? isReduced;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              normalResult = AdminMotion.duration(context, AdminMotion.hover);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(normalResult, AdminMotion.hover);

      // Now with disableAnimations set to true (Reduced Motion active)
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Builder(
              builder: (context) {
                reducedResult = AdminMotion.duration(context, AdminMotion.hover);
                isReduced = AdminMotion.isReducedMotion(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(reducedResult, Duration.zero);
      expect(isReduced, isTrue);
    });

    testWidgets('AdminButton triggers hover and pressed micro-interactions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: NorveTheme.light,
          home: Scaffold(
            body: Center(
              child: AdminButton.secondary(
                label: 'Action',
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      final containerFinder = find.byType(AnimatedContainer);
      expect(containerFinder, findsOneWidget);

      final initialContainer = tester.widget<AnimatedContainer>(containerFinder);
      final initialDec = initialContainer.decoration as BoxDecoration;
      expect(initialDec.color, AdminColors.white);

      // Simulate mouse enter
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.text('Action')));
      await tester.pumpAndSettle();

      final hoveredContainer = tester.widget<AnimatedContainer>(containerFinder);
      final hoveredDec = hoveredContainer.decoration as BoxDecoration;
      expect(hoveredDec.color, AdminColors.surfaceSubtle);
    });

    testWidgets('AdminIconButton triggers hover transitions and displays tooltip', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: NorveTheme.light,
          home: Scaffold(
            body: Center(
              child: AdminIconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh Catalogue',
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      final containerFinder = find.byType(AnimatedContainer);
      expect(containerFinder, findsOneWidget);

      final initialContainer = tester.widget<AnimatedContainer>(containerFinder);
      final initialDec = initialContainer.decoration as BoxDecoration;
      expect(initialDec.color, AdminColors.white);

      // Hover
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(containerFinder));
      await tester.pumpAndSettle();

      final hoveredContainer = tester.widget<AnimatedContainer>(containerFinder);
      final hoveredDec = hoveredContainer.decoration as BoxDecoration;
      expect(hoveredDec.color, AdminColors.surfaceSubtle);
    });

    testWidgets('AdminTableRow smoothly transitions background on mouse hover', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: NorveTheme.light,
          home: Scaffold(
            body: AdminTable(
              children: [
                AdminTableRow(
                  onTap: () {},
                  children: const [Text('Row Item')],
                ),
              ],
            ),
          ),
        ),
      );

      final containerFinder = find.descendant(
        of: find.byType(AdminTableRow),
        matching: find.byType(AnimatedContainer),
      );
      expect(containerFinder, findsOneWidget);

      final initialDec = tester.widget<AnimatedContainer>(containerFinder).decoration as BoxDecoration;
      expect(initialDec.color, AdminColors.white);

      // Mouse enter
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.text('Row Item')));
      await tester.pumpAndSettle();

      final hoveredDec = tester.widget<AnimatedContainer>(containerFinder).decoration as BoxDecoration;
      expect(hoveredDec.color, AdminColors.surfaceSubtle);
    });

    testWidgets('AdminSnackbar.show renders floating notification toast', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: NorveTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => AdminSnackbar.show(
                  context,
                  message: 'Catalogue updated successfully.',
                ),
                child: const Text('Show Toast'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Toast'));
      await tester.pump(); // Start entry animation

      expect(find.text('Catalogue updated successfully.'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('AdminShell renders sidebar nav item with active indicator and top-bar actions',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final testClient = SupabaseClient(
        'https://example.supabase.co',
        'sb_publishable_test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );

      final router = GoRouter(
        initialLocation: '/admin',
        routes: [
          GoRoute(
            path: '/admin',
            builder: (context, state) => const AdminShell(
              child: Text('Dashboard View'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            applicationRoleProvider.overrideWithValue(
              const AsyncData(ApplicationRole.administrator),
            ),
            supabaseClientProvider.overrideWithValue(testClient),
          ],
          child: MaterialApp.router(
            theme: NorveTheme.light,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('MANAGEMENT'), findsOneWidget);
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Products'), findsOneWidget);

      // Verify sign out button uses AdminIconButton with tooltip
      expect(find.byTooltip('Sign Out'), findsOneWidget);
    });

    testWidgets(
        'AdminMotion respects reduced-motion accessibility preference',
        (tester) async {
      Duration? normalDuration;
      Duration? reducedDuration;

      // Normal mode (reduced motion false)
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: false),
            child: Builder(
              builder: (context) {
                normalDuration = AdminMotion.duration(context, AdminMotion.hover);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      // Reduced motion mode (disableAnimations true)
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Builder(
              builder: (context) {
                reducedDuration = AdminMotion.duration(context, AdminMotion.hover);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(normalDuration, const Duration(milliseconds: 160));
      expect(reducedDuration, Duration.zero);
    });

    testWidgets(
        'AdminShell renders across tablet viewports (768px and 1024px) without overflow',
        (tester) async {
      final testClient = SupabaseClient(
        'https://example.supabase.co',
        'sb_publishable_test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );

      final router = GoRouter(
        initialLocation: '/admin',
        routes: [
          GoRoute(
            path: '/admin',
            builder: (context, state) => const AdminShell(
              child: Text('Tablet Content Area'),
            ),
          ),
        ],
      );

      Widget buildApp() => ProviderScope(
            overrides: [
              applicationRoleProvider.overrideWithValue(
                const AsyncData(ApplicationRole.administrator),
              ),
              supabaseClientProvider.overrideWithValue(testClient),
            ],
            child: MaterialApp.router(
              theme: NorveTheme.light,
              routerConfig: router,
            ),
          );

      // 1. Tablet Portrait Viewport (768 x 1024)
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Tablet Content Area'), findsOneWidget);

      // 2. Tablet Landscape Viewport (1024 x 768)
      tester.view.physicalSize = const Size(1024, 768);
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Tablet Content Area'), findsOneWidget);
    });
  });
}
