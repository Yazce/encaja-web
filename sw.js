// Service worker de Encaja.
// De momento solo existe para que el navegador pueda instalar la web
// como app (icono en el móvil, pantalla completa) y para tener listo
// el manejo de notificaciones push cuando se active ese envío desde
// el servidor más adelante. No cachea agresivamente: los datos de
// Encaja cambian todo el rato (pisos, compradores, coincidencias) y
// no queremos que nadie vea información vieja por un caché mal hecho.

const CACHE_NAME = 'encaja-shell-v1';
const SHELL_FILES = ['/', '/manifest.json', '/icon-192.png', '/icon-512.png'];

self.addEventListener('install', (event) => {
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(SHELL_FILES)).catch(() => {})
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((names) =>
      Promise.all(names.filter((n) => n !== CACHE_NAME).map((n) => caches.delete(n)))
    ).then(() => self.clients.claim())
  );
});

// Network-first: siempre intenta traer lo último de la red (para no
// mostrar pisos/compradores desactualizados); si no hay conexión,
// cae al caché del "shell" para que al menos abra algo.
self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return;
  event.respondWith(
    fetch(event.request)
      .then((response) => {
        const copy = response.clone();
        caches.open(CACHE_NAME).then((cache) => cache.put(event.request, copy)).catch(() => {});
        return response;
      })
      .catch(() => caches.match(event.request))
  );
});

// Preparado para cuando haya envío de avisos push desde el servidor.
self.addEventListener('push', (event) => {
  let data = {};
  try { data = event.data ? event.data.json() : {}; } catch (e) {}
  const title = data.title || 'Encaja';
  const options = {
    body: data.body || 'Hay una novedad en Encaja.',
    icon: '/icon-192.png',
    badge: '/icon-192.png',
    tag: data.tag || 'encaja-generic',
    data: { url: data.url || '/' },
  };
  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const url = (event.notification.data && event.notification.data.url) || '/';
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientsArr) => {
      for (const client of clientsArr) {
        if ('focus' in client) return client.focus();
      }
      if (self.clients.openWindow) return self.clients.openWindow(url);
    })
  );
});
