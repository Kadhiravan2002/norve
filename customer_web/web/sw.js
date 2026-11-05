'use strict';

// NORVÉ service worker. It makes the app installable and lets it open with a
// poor connection. It never holds customer or shop data.
//
// - Requests to other sites pass straight through, untouched and uncached. That
//   covers Supabase (catalogue, stock, sign-in, checkout, orders) and product
//   images. The one exception is Flutter's versioned rendering engine.
// - Only GET requests are handled, so nothing that writes data comes near it.
// - The app's own files always come from the network first, so a new release
//   arrives straight away. The saved copy is used only when the network fails.

// Change this when this file's caching rules change.
const CACHE_NAME = 'norve-app-shell-v1';

const ENGINE_PREFIX = 'https://www.gstatic.com/flutter-canvaskit/';

// Saved on install, so the app can open offline after its first visit.
const APP_SHELL = [
  '/',
  '/flutter_bootstrap.js',
  '/flutter.js',
  '/main.dart.js',
  '/manifest.json',
  '/favicon.png',
  '/icons/Icon-192.png',
  '/icons/Icon-512.png',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    (async () => {
      const cache = await caches.open(CACHE_NAME);
      // One missing file should not stop the app from being installable.
      await Promise.allSettled(APP_SHELL.map((path) => cache.add(path)));
      await self.skipWaiting();
    })(),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      const names = await caches.keys();
      await Promise.all(
        names
          .filter((name) => name.startsWith('norve-') && name !== CACHE_NAME)
          .map((name) => caches.delete(name)),
      );
      await self.clients.claim();
    })(),
  );
});

async function networkFirst(request, cacheKey) {
  const cache = await caches.open(CACHE_NAME);
  try {
    const response = await fetch(request);
    if (response.ok && response.type === 'basic') {
      await cache.put(cacheKey, response.clone());
    }
    return response;
  } catch (error) {
    const saved = await cache.match(cacheKey);
    if (saved) return saved;
    throw error;
  }
}

async function cacheFirst(request) {
  const cache = await caches.open(CACHE_NAME);
  const saved = await cache.match(request);
  if (saved) return saved;
  const response = await fetch(request);
  if (response.ok) await cache.put(request, response.clone());
  return response;
}

self.addEventListener('fetch', (event) => {
  const { request } = event;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);

  if (url.origin !== self.location.origin) {
    // The engine's address includes its version, so a saved copy cannot go stale.
    if (url.href.startsWith(ENGINE_PREFIX)) {
      event.respondWith(cacheFirst(request));
    }
    return;
  }

  // Every page is the same app. A single saved copy also keeps a password reset
  // link's one-time code out of the cache.
  if (request.mode === 'navigate') {
    event.respondWith(networkFirst(request, '/'));
    return;
  }

  if (url.pathname === '/sw.js' || url.search) return;

  event.respondWith(networkFirst(request, request));
});
