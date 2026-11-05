/// Retries a failed provider once, quickly, to ride out a network blip.
///
/// Riverpod's default keeps retrying for about 40 seconds, and a screen shows
/// its spinner throughout, so a customer never reaches its error and Retry.
Duration? storefrontProviderRetry(int retryCount, Object error) =>
    retryCount == 0 ? const Duration(milliseconds: 300) : null;
