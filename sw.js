// Keeps Selena Roller playable without a signal once it has been opened.
const CACHE = 'selena-roller-v3';
const CORE = [
  './', './index.html', './three.min.js', './manifest.webmanifest', './icon-180.png', './icon-192.png',
  './fonts/rubik.css', './fonts/rubik-latin.woff2', './fonts/rubik-latin-ext.woff2',
  './fonts/rubik-cyrillic.woff2', './fonts/rubik-cyrillic-ext.woff2', './fonts/rubik-hebrew.woff2', './fonts/rubik-arabic.woff2'
];

self.addEventListener('install', event => {
  // 'reload' skips the browser's own HTTP cache, so a new version never saves files left over from the old one.
  event.waitUntil(
    caches.open(CACHE)
      .then(cache => cache.addAll(CORE.map(url => new Request(url, { cache: 'reload' }))))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

// The page itself: network first, so updates show up straight away; the saved copy is used offline.
// Everything else (3D library, icons, fonts): saved copy first.
self.addEventListener('fetch', event => {
  const req = event.request;
  if (req.method !== 'GET') return;
  if (req.mode === 'navigate') {
    // Only the game's own address is saved as the game. Other pages here (privacy.html, support.html) load
    // normally and are never saved, or the game would open as one of them without a signal.
    const scope = new URL(self.registration.scope).pathname;
    const path = new URL(req.url).pathname;
    if (path !== scope && path !== scope + 'index.html') return;
    event.respondWith(
      fetch(req)
        .then(res => {
          if (res.ok) { const copy = res.clone(); caches.open(CACHE).then(c => c.put('./index.html', copy)); }
          return res;
        })
        .catch(() => caches.match('./index.html'))
    );
    return;
  }
  event.respondWith(
    caches.match(req).then(hit => hit || fetch(req).then(res => {
      if (res.ok || res.type === 'opaque') { const copy = res.clone(); caches.open(CACHE).then(c => c.put(req, copy)); }
      return res;
    }))
  );
});
