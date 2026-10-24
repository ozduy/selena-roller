// Keeps Selena Roller playable without a signal once it has been opened.
const CACHE = 'selena-roller-v2';
const CORE = [
  './', './index.html', './three.min.js', './manifest.webmanifest', './icon-180.png', './icon-192.png',
  './fonts/rubik.css', './fonts/rubik-latin.woff2', './fonts/rubik-latin-ext.woff2',
  './fonts/rubik-cyrillic.woff2', './fonts/rubik-cyrillic-ext.woff2', './fonts/rubik-hebrew.woff2', './fonts/rubik-arabic.woff2'
];

self.addEventListener('install', event => {
  event.waitUntil(caches.open(CACHE).then(cache => cache.addAll(CORE)).then(() => self.skipWaiting()));
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
