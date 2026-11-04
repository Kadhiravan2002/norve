import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../theme/norve_admin_tokens.dart';
import 'supabase_providers.dart';

/// Connection health status for the Supabase backend.
enum BackendConnectionStatus {
  connected,
  connectionIssue,
  disconnected,
}

/// Detailed classification of probe response.
enum HealthProbeOutcome {
  /// HTTP 200 with valid health response: Auth backend is reachable.
  healthy,

  /// HTTP 5xx or server gateway failure.
  serverError,

  /// Network drop, DNS resolution failure, socket error, or timeout.
  transportError,

  /// Unexpected HTTP status code (e.g. 3xx redirect, unexpected 4xx).
  unexpectedStatus,
}

/// Result produced by a backend health check probe.
class HealthProbeResult {
  const HealthProbeResult({
    required this.outcome,
    this.statusCode,
    this.errorMessage,
  });

  final HealthProbeOutcome outcome;
  final int? statusCode;
  final String? errorMessage;

  bool get isHealthy => outcome == HealthProbeOutcome.healthy;
}

/// Holds backend connectivity metadata and state.
class BackendConnectionState {
  const BackendConnectionState({
    required this.status,
    this.lastSuccessfulCheck,
    this.lastAttempt,
    this.consecutiveFailures = 0,
    this.outcome = HealthProbeOutcome.healthy,
    this.statusCode,
    this.errorMessage,
  });

  final BackendConnectionStatus status;
  final DateTime? lastSuccessfulCheck;
  final DateTime? lastAttempt;
  final int consecutiveFailures;
  final HealthProbeOutcome outcome;
  final int? statusCode;
  final String? errorMessage;

  bool get isConnected => status == BackendConnectionStatus.connected;
  bool get hasIssue => status == BackendConnectionStatus.connectionIssue;
  bool get isDisconnected => status == BackendConnectionStatus.disconnected;

  String get label => switch (status) {
    BackendConnectionStatus.connected => 'Connected',
    BackendConnectionStatus.connectionIssue => 'Connection issue',
    BackendConnectionStatus.disconnected => 'Disconnected',
  };

  Color get dotColor => switch (status) {
    BackendConnectionStatus.connected => AdminColors.success,
    BackendConnectionStatus.connectionIssue => AdminColors.warning,
    BackendConnectionStatus.disconnected => AdminColors.error,
  };

  String get tooltip {
    final timeStr = _formatTime(lastSuccessfulCheck);
    return switch (status) {
      BackendConnectionStatus.connected => timeStr != null
          ? 'Backend connection healthy.\nLast verified at $timeStr.'
          : 'Backend connection healthy.',
      BackendConnectionStatus.connectionIssue => _issueTooltip(timeStr),
      BackendConnectionStatus.disconnected => timeStr != null
          ? 'Backend unreachable.\nLast verified at $timeStr.\nCheck network connection.'
          : 'Backend unreachable. Check network connection.',
    };
  }

  String _issueTooltip(String? timeStr) {
    if (outcome == HealthProbeOutcome.unexpectedStatus && statusCode != null) {
      return timeStr != null
          ? 'Unexpected auth service response (HTTP $statusCode).\nLast verified at $timeStr.\nRetrying...'
          : 'Unexpected auth service response (HTTP $statusCode).\nRetrying...';
    }
    if (outcome == HealthProbeOutcome.serverError && statusCode != null) {
      return timeStr != null
          ? 'Auth service error (HTTP $statusCode).\nLast verified at $timeStr.\nRetrying...'
          : 'Auth service error (HTTP $statusCode).\nRetrying...';
    }
    return timeStr != null
        ? 'Temporary connection issue detected.\nLast verified at $timeStr.\nRetrying...'
        : 'Temporary connection issue detected. Retrying...';
  }

  static String? _formatTime(DateTime? dt) {
    if (dt == null) return null;
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

/// Function signature for probing backend connectivity.
typedef BackendProbe = Future<HealthProbeResult> Function({
  required String url,
  required String publishableKey,
  required http.Client httpClient,
});

/// Default health probe: calls GET {SUPABASE_URL}/auth/v1/health using an HTTP client.
Future<HealthProbeResult> defaultBackendProbe({
  required String url,
  required String publishableKey,
  required http.Client httpClient,
}) async {
  if (url.isEmpty) {
    return const HealthProbeResult(
      outcome: HealthProbeOutcome.transportError,
      errorMessage: 'Supabase URL is empty.',
    );
  }

  final normalizedUrl =
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  final healthUri = Uri.tryParse('$normalizedUrl/auth/v1/health');
  if (healthUri == null || !healthUri.hasScheme) {
    return const HealthProbeResult(
      outcome: HealthProbeOutcome.transportError,
      errorMessage: 'Invalid Supabase URL.',
    );
  }

  final headers = <String, String>{
    'Accept': 'application/json',
    if (publishableKey.isNotEmpty) 'apikey': publishableKey,
  };

  try {
    final response = await httpClient
        .get(healthUri, headers: headers)
        .timeout(const Duration(seconds: 7));

    if (response.statusCode == 200) {
      return HealthProbeResult(
        outcome: HealthProbeOutcome.healthy,
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode >= 500 && response.statusCode < 600) {
      return HealthProbeResult(
        outcome: HealthProbeOutcome.serverError,
        statusCode: response.statusCode,
        errorMessage: 'Server error: ${response.statusCode}',
      );
    }

    return HealthProbeResult(
      outcome: HealthProbeOutcome.unexpectedStatus,
      statusCode: response.statusCode,
      errorMessage: 'Unexpected status: ${response.statusCode}',
    );
  } on TimeoutException catch (e) {
    return HealthProbeResult(
      outcome: HealthProbeOutcome.transportError,
      errorMessage: 'Connection timed out: ${e.message}',
    );
  } catch (e) {
    return HealthProbeResult(
      outcome: HealthProbeOutcome.transportError,
      errorMessage: 'Transport error: $e',
    );
  }
}

/// Shared reusable HTTP client provider with lifecycle cleanup.
final backendHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// Injectable backend probe provider for testing connected, timeout, and failure scenarios.
final backendProbeProvider = Provider<BackendProbe>((ref) {
  return defaultBackendProbe;
});

/// Polling interval when backend connection is healthy (default 45s).
final backendConnectionCheckIntervalProvider = Provider<Duration>((ref) {
  return const Duration(seconds: 45);
});

/// Polling interval when recovering from an issue or disconnection (default 10s).
final backendConnectionRetryIntervalProvider = Provider<Duration>((ref) {
  return const Duration(seconds: 10);
});

/// Controller that monitors backend connectivity and updates connection state.
class BackendConnectionNotifier extends Notifier<BackendConnectionState> {
  Timer? _timer;
  bool _isChecking = false;
  bool _disposed = false;

  @override
  BackendConnectionState build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _timer?.cancel();
    });

    final config = ref.watch(supabaseConfigProvider);
    final startupError = ref.watch(supabaseStartupErrorProvider);

    if (config.url.isEmpty || startupError != null) {
      return BackendConnectionState(
        status: BackendConnectionStatus.disconnected,
        errorMessage: startupError ?? 'Supabase URL not configured',
        consecutiveFailures: 2,
        outcome: HealthProbeOutcome.transportError,
      );
    }

    // Schedule initial background verification
    _scheduleCheck(const Duration(milliseconds: 50));

    // Initially optimistic because reaching the admin shell already verified client and admin role
    return const BackendConnectionState(
      status: BackendConnectionStatus.connected,
      consecutiveFailures: 0,
      outcome: HealthProbeOutcome.healthy,
    );
  }

  void _scheduleCheck(Duration delay) {
    if (_disposed) return;
    _timer?.cancel();
    _timer = Timer(delay, () {
      if (!_disposed) {
        checkConnection();
      }
    });
  }

  void _scheduleNext() {
    if (_disposed) return;
    final interval = state.status == BackendConnectionStatus.connected
        ? ref.read(backendConnectionCheckIntervalProvider)
        : ref.read(backendConnectionRetryIntervalProvider);
    _scheduleCheck(interval);
  }

  /// Manually trigger a connectivity check or handle scheduled interval checks.
  Future<void> checkConnection() async {
    if (_isChecking || _disposed) return;
    _isChecking = true;
    _timer?.cancel();

    try {
      final config = ref.read(supabaseConfigProvider);
      if (config.url.isEmpty) {
        if (!_disposed) {
          state = BackendConnectionState(
            status: BackendConnectionStatus.disconnected,
            lastSuccessfulCheck: state.lastSuccessfulCheck,
            lastAttempt: DateTime.now(),
            consecutiveFailures: state.consecutiveFailures + 1,
            outcome: HealthProbeOutcome.transportError,
            errorMessage: 'Supabase URL unavailable',
          );
          _scheduleNext();
        }
        return;
      }

      final probe = ref.read(backendProbeProvider);
      final httpClient = ref.read(backendHttpClientProvider);
      final now = DateTime.now();

      final result = await probe(
        url: config.url,
        publishableKey: config.publishableKey,
        httpClient: httpClient,
      );

      if (_disposed) return;

      if (result.isHealthy) {
        state = BackendConnectionState(
          status: BackendConnectionStatus.connected,
          lastSuccessfulCheck: now,
          lastAttempt: now,
          consecutiveFailures: 0,
          outcome: HealthProbeOutcome.healthy,
          statusCode: result.statusCode,
          errorMessage: null,
        );
      } else {
        final failures = state.consecutiveFailures + 1;
        final status = switch (result.outcome) {
          HealthProbeOutcome.serverError || HealthProbeOutcome.transportError =>
            failures >= 2
                ? BackendConnectionStatus.disconnected
                : BackendConnectionStatus.connectionIssue,
          HealthProbeOutcome.unexpectedStatus =>
            failures >= 2
                ? BackendConnectionStatus.disconnected
                : BackendConnectionStatus.connectionIssue,
          HealthProbeOutcome.healthy => BackendConnectionStatus.connected,
        };

        state = BackendConnectionState(
          status: status,
          lastSuccessfulCheck: state.lastSuccessfulCheck,
          lastAttempt: now,
          consecutiveFailures: failures,
          outcome: result.outcome,
          statusCode: result.statusCode,
          errorMessage: result.errorMessage,
        );
      }

      _scheduleNext();
    } finally {
      _isChecking = false;
    }
  }
}

/// Provider exposing the reactive backend connectivity state.
final backendConnectionProvider =
    NotifierProvider<BackendConnectionNotifier, BackendConnectionState>(
      BackendConnectionNotifier.new,
    );
