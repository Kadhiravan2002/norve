import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:norve/core/auth/application_role_provider.dart';
import 'package:norve/core/supabase/backend_connection_provider.dart';
import 'package:norve/core/supabase/supabase_config.dart';
import 'package:norve/core/supabase/supabase_providers.dart';
import 'package:norve/core/theme/norve_admin_tokens.dart';
import 'package:norve/core/theme/norve_theme.dart';
import 'package:norve/features/admin/admin_shell.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockHttpClient extends http.BaseClient {
  _MockHttpClient(this._handler);

  Future<http.Response> Function(http.Request request) _handler;

  void setHandler(Future<http.Response> Function(http.Request request) handler) {
    _handler = handler;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final httpRequest = request as http.Request;
    final response = await _handler(httpRequest);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}

void main() {
  const testUrl = 'https://test-project.supabase.co';
  const testPublishableKey = 'sb_publishable_test_key_123';

  final testClient = SupabaseClient(
    testUrl,
    testPublishableKey,
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );

  Widget createTestWidget({
    required List<dynamic> overrides,
    String initialLocation = '/admin',
  }) {
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/admin',
          builder: (context, state) => const AdminShell(
            child: Text('Dashboard Content'),
          ),
        ),
      ],
    );

    return ProviderScope(
      overrides: overrides.cast(),
      child: MaterialApp.router(
        theme: NorveTheme.light,
        routerConfig: router,
      ),
    );
  }

  group('defaultBackendProbe Endpoint & Response Classification Tests', () {
    test('1. HTTP 200 health response classifies as healthy', () async {
      String? capturedPath;
      Map<String, String>? capturedHeaders;

      final mockClient = _MockHttpClient((request) async {
        capturedPath = request.url.toString();
        capturedHeaders = request.headers;
        return http.Response('{"version":"2.158.0","name":"GoTrue"}', 200);
      });

      final result = await defaultBackendProbe(
        url: testUrl,
        publishableKey: testPublishableKey,
        httpClient: mockClient,
      );

      expect(result.outcome, HealthProbeOutcome.healthy);
      expect(result.isHealthy, isTrue);
      expect(result.statusCode, 200);
      expect(capturedPath, '$testUrl/auth/v1/health');
      expect(capturedHeaders?['apikey'], testPublishableKey);
      expect(capturedHeaders?['authorization'], isNull); // No JWT or user session required
    });

    test('2. HTTP 500/503 responses classify as serverError', () async {
      final mock500 = _MockHttpClient(
        (_) async => http.Response('Internal Server Error', 500),
      );
      final result500 = await defaultBackendProbe(
        url: testUrl,
        publishableKey: testPublishableKey,
        httpClient: mock500,
      );
      expect(result500.outcome, HealthProbeOutcome.serverError);
      expect(result500.isHealthy, isFalse);
      expect(result500.statusCode, 500);

      final mock503 = _MockHttpClient(
        (_) async => http.Response('Service Unavailable', 503),
      );
      final result503 = await defaultBackendProbe(
        url: testUrl,
        publishableKey: testPublishableKey,
        httpClient: mock503,
      );
      expect(result503.outcome, HealthProbeOutcome.serverError);
      expect(result503.isHealthy, isFalse);
      expect(result503.statusCode, 503);
    });

    test('3. Network failure classifies as transportError', () async {
      final mockClient = _MockHttpClient((_) async {
        throw http.ClientException('Failed host lookup / DNS error');
      });

      final result = await defaultBackendProbe(
        url: testUrl,
        publishableKey: testPublishableKey,
        httpClient: mockClient,
      );

      expect(result.outcome, HealthProbeOutcome.transportError);
      expect(result.isHealthy, isFalse);
      expect(result.errorMessage, contains('Transport error'));
    });

    test('4. Request timeout classifies as transportError', () async {
      final mockClient = _MockHttpClient((_) async {
        throw TimeoutException('Request timed out after 7s');
      });

      final result = await defaultBackendProbe(
        url: testUrl,
        publishableKey: testPublishableKey,
        httpClient: mockClient,
      );

      expect(result.outcome, HealthProbeOutcome.transportError);
      expect(result.isHealthy, isFalse);
      expect(result.errorMessage, contains('Connection timed out'));
    });

    test('5. Unexpected HTTP response (e.g. 404, 301) classifies as unexpectedStatus', () async {
      final mock404 = _MockHttpClient(
        (_) async => http.Response('Not Found', 404),
      );
      final result404 = await defaultBackendProbe(
        url: testUrl,
        publishableKey: testPublishableKey,
        httpClient: mock404,
      );

      expect(result404.outcome, HealthProbeOutcome.unexpectedStatus);
      expect(result404.isHealthy, isFalse);
      expect(result404.statusCode, 404);
    });

    test('10. Flutter Web CORS headers compliance verification', () async {
      final mockClient = _MockHttpClient((request) async {
        // In browser web clients, simple GET requests to Auth endpoints
        // pass apikey and Accept headers without non-standard preflight triggers
        expect(request.method, 'GET');
        expect(request.url.path, '/auth/v1/health');
        expect(request.headers['Accept'], 'application/json');
        return http.Response(
          '{"status":"ok"}',
          200,
          headers: {'access-control-allow-origin': '*'},
        );
      });

      final result = await defaultBackendProbe(
        url: '$testUrl/', // Verifies trailing slash normalization
        publishableKey: testPublishableKey,
        httpClient: mockClient,
      );

      expect(result.outcome, HealthProbeOutcome.healthy);
      expect(result.statusCode, 200);
    });
  });

  group('BackendConnectionNotifier State Machine & Consecutive Failures', () {
    test('initial state is connected when config is valid and probe succeeds', () async {
      final container = ProviderContainer(
        overrides: [
          supabaseConfigProvider.overrideWithValue(
            const SupabaseConfig(url: testUrl, publishableKey: testPublishableKey),
          ),
          supabaseClientProvider.overrideWithValue(testClient),
          backendProbeProvider.overrideWithValue(
            ({required url, required publishableKey, required httpClient}) async =>
                const HealthProbeResult(outcome: HealthProbeOutcome.healthy, statusCode: 200),
          ),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(backendConnectionProvider);
      expect(state.status, BackendConnectionStatus.connected);
      expect(state.label, 'Connected');
      expect(state.dotColor, AdminColors.success);

      await container.read(backendConnectionProvider.notifier).checkConnection();

      final updated = container.read(backendConnectionProvider);
      expect(updated.status, BackendConnectionStatus.connected);
      expect(updated.lastSuccessfulCheck, isNotNull);
      expect(updated.consecutiveFailures, 0);
      expect(updated.tooltip, contains('Backend connection healthy'));
    });

    test('7. Consecutive failure threshold: 1st failure = issue, 2nd failure = disconnected', () async {
      final container = ProviderContainer(
        overrides: [
          supabaseConfigProvider.overrideWithValue(
            const SupabaseConfig(url: testUrl, publishableKey: testPublishableKey),
          ),
          supabaseClientProvider.overrideWithValue(testClient),
          backendProbeProvider.overrideWithValue(
            ({required url, required publishableKey, required httpClient}) async =>
                const HealthProbeResult(
                  outcome: HealthProbeOutcome.serverError,
                  statusCode: 503,
                  errorMessage: 'Service Unavailable',
                ),
          ),
        ],
      );
      addTearDown(container.dispose);

      // 1st failure -> Connection issue (amber)
      await container.read(backendConnectionProvider.notifier).checkConnection();
      final state1 = container.read(backendConnectionProvider);
      expect(state1.status, BackendConnectionStatus.connectionIssue);
      expect(state1.label, 'Connection issue');
      expect(state1.dotColor, AdminColors.warning);
      expect(state1.consecutiveFailures, 1);
      expect(state1.tooltip, contains('Auth service error (HTTP 503)'));

      // 2nd consecutive failure -> Disconnected (red)
      await container.read(backendConnectionProvider.notifier).checkConnection();
      final state2 = container.read(backendConnectionProvider);
      expect(state2.status, BackendConnectionStatus.disconnected);
      expect(state2.label, 'Disconnected');
      expect(state2.dotColor, AdminColors.error);
      expect(state2.consecutiveFailures, 2);
      expect(state2.tooltip, contains('Backend unreachable'));
    });

    test('6. Recovery after successful response resets failures to 0 and status to connected', () async {
      var returnHealthy = false;
      final container = ProviderContainer(
        overrides: [
          supabaseConfigProvider.overrideWithValue(
            const SupabaseConfig(url: testUrl, publishableKey: testPublishableKey),
          ),
          supabaseClientProvider.overrideWithValue(testClient),
          backendProbeProvider.overrideWithValue(
            ({required url, required publishableKey, required httpClient}) async {
              if (returnHealthy) {
                return const HealthProbeResult(outcome: HealthProbeOutcome.healthy, statusCode: 200);
              }
              return const HealthProbeResult(outcome: HealthProbeOutcome.transportError);
            },
          ),
        ],
      );
      addTearDown(container.dispose);

      // Trigger 2 failures to force disconnected
      await container.read(backendConnectionProvider.notifier).checkConnection();
      await container.read(backendConnectionProvider.notifier).checkConnection();
      expect(container.read(backendConnectionProvider).status, BackendConnectionStatus.disconnected);

      // Network recovers
      returnHealthy = true;
      await container.read(backendConnectionProvider.notifier).checkConnection();

      final recovered = container.read(backendConnectionProvider);
      expect(recovered.status, BackendConnectionStatus.connected);
      expect(recovered.label, 'Connected');
      expect(recovered.dotColor, AdminColors.success);
      expect(recovered.consecutiveFailures, 0);
      expect(recovered.tooltip, contains('Backend connection healthy'));
    });

    test('9. Timer cancellation and provider disposal does not throw or leak', () async {
      final container = ProviderContainer(
        overrides: [
          supabaseConfigProvider.overrideWithValue(
            const SupabaseConfig(url: testUrl, publishableKey: testPublishableKey),
          ),
          supabaseClientProvider.overrideWithValue(testClient),
        ],
      );

      // Read to instantiate
      container.read(backendConnectionProvider);

      // Disposing container cancels timers and closes http client
      expect(() => container.dispose(), returnsNormally);
    });
  });

  group('AdminShell Backend Connection Indicator UI Integration Tests', () {
    testWidgets('renders connected state in bottom-left sidebar with green dot and "Connected"',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestWidget(
          overrides: [
            applicationRoleProvider.overrideWithValue(
              const AsyncData(ApplicationRole.administrator),
            ),
            supabaseConfigProvider.overrideWithValue(
              const SupabaseConfig(url: testUrl, publishableKey: testPublishableKey),
            ),
            supabaseClientProvider.overrideWithValue(testClient),
            backendProbeProvider.overrideWithValue(
              ({required url, required publishableKey, required httpClient}) async =>
                  const HealthProbeResult(outcome: HealthProbeOutcome.healthy, statusCode: 200),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('backend-connection-indicator')), findsOneWidget);
      expect(find.text('Connected'), findsOneWidget);

      final dot = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byKey(const ValueKey('backend-connection-indicator')),
          matching: find.byType(AnimatedContainer),
        ),
      );
      final decoration = dot.decoration as BoxDecoration;
      expect(decoration.color, AdminColors.success);
    });

    testWidgets('8. Manual refresh: tapping indicator triggers connectivity probe', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      var checkCount = 0;
      await tester.pumpWidget(
        createTestWidget(
          overrides: [
            applicationRoleProvider.overrideWithValue(
              const AsyncData(ApplicationRole.administrator),
            ),
            supabaseConfigProvider.overrideWithValue(
              const SupabaseConfig(url: testUrl, publishableKey: testPublishableKey),
            ),
            supabaseClientProvider.overrideWithValue(testClient),
            backendProbeProvider.overrideWithValue(
              ({required url, required publishableKey, required httpClient}) async {
                checkCount++;
                return const HealthProbeResult(outcome: HealthProbeOutcome.healthy, statusCode: 200);
              },
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final initialChecks = checkCount;

      // Tap indicator to trigger manual check
      await tester.tap(find.byKey(const ValueKey('backend-connection-indicator')));
      await tester.pumpAndSettle();

      expect(checkCount, greaterThan(initialChecks));
    });

    testWidgets('displays connection issue on 500 error and disconnected on second failure',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestWidget(
          overrides: [
            applicationRoleProvider.overrideWithValue(
              const AsyncData(ApplicationRole.administrator),
            ),
            supabaseConfigProvider.overrideWithValue(
              const SupabaseConfig(url: testUrl, publishableKey: testPublishableKey),
            ),
            supabaseClientProvider.overrideWithValue(testClient),
            backendProbeProvider.overrideWithValue(
              ({required url, required publishableKey, required httpClient}) async =>
                  const HealthProbeResult(
                    outcome: HealthProbeOutcome.serverError,
                    statusCode: 500,
                  ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Initial check failed once -> Connection issue
      expect(find.text('Connection issue'), findsOneWidget);

      final element = tester.element(find.byKey(const ValueKey('backend-connection-indicator')));
      final container = ProviderScope.containerOf(element);

      // 2nd failure -> Disconnected
      await container.read(backendConnectionProvider.notifier).checkConnection();
      await tester.pumpAndSettle();
      expect(find.text('Disconnected'), findsOneWidget);

      final dot = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byKey(const ValueKey('backend-connection-indicator')),
          matching: find.byType(AnimatedContainer),
        ),
      );
      final decoration = dot.decoration as BoxDecoration;
      expect(decoration.color, AdminColors.error);
    });

    testWidgets('tooltip explains connection state and includes last verified timestamp',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestWidget(
          overrides: [
            applicationRoleProvider.overrideWithValue(
              const AsyncData(ApplicationRole.administrator),
            ),
            supabaseConfigProvider.overrideWithValue(
              const SupabaseConfig(url: testUrl, publishableKey: testPublishableKey),
            ),
            supabaseClientProvider.overrideWithValue(testClient),
            backendProbeProvider.overrideWithValue(
              ({required url, required publishableKey, required httpClient}) async =>
                  const HealthProbeResult(outcome: HealthProbeOutcome.healthy, statusCode: 200),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final element = tester.element(find.byKey(const ValueKey('backend-connection-indicator')));
      final container = ProviderScope.containerOf(element);
      await container.read(backendConnectionProvider.notifier).checkConnection();
      await tester.pumpAndSettle();

      final tooltip = tester.widget<Tooltip>(
        find.ancestor(
          of: find.byKey(const ValueKey('backend-connection-indicator')),
          matching: find.byType(Tooltip),
        ),
      );

      expect(tooltip.message, contains('Backend connection healthy'));
      expect(tooltip.message, contains('Last verified at'));
    });
  });
}
