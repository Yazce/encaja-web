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
    // Para que un aviso importante (cliente en caliente, recordatorio de
    // inactividad) no pase desapercibido: que vibre, que suene (silent:
    // false es lo normal, pero lo dejamos explícito) y que se quede en
    // pantalla hasta que alguien lo toque, en vez de desaparecer solo.
    vibrate: [200, 100, 200, 100, 200],
    requireInteraction: true,
    silent: false,
    renotify: true,
  };
  event.waitUntil(self.registration.showNotification(title, options));
});

// Construye, solo para Android, un enlace "intent://" que pide abrir
// directamente WhatsApp Business (com.whatsapp.w4b, que es la app que
// usamos en la oficina) en vez de dejar que el enlace https://wa.me/...
// caiga en la página web de "Descargar WhatsApp" (esa página solo
// reconoce el WhatsApp normal, no el Business). Si el aviso apunta a
// otra cosa que no sea WhatsApp, o si no estamos en Android, se deja
// el enlace tal cual.
//
// Usa el esquema propio "whatsapp://send?phone=...&text=..." (el que
// documenta el propio WhatsApp para enlaces "Click to Chat"), envuelto
// en un intent:// que fuerza el paquete com.whatsapp.w4b. La primera
// versión usaba el esquema "https" con el dominio wa.me, pero esa
// verificación de dominio (Android App Links) solo está registrada
// para el WhatsApp normal, no para el Business, así que nunca abría
// la app: se quedaba en la web. Con el esquema propio de WhatsApp no
// hace falta esa verificación.
function urlParaAbrir(url) {
  const m = /^https:\/\/wa\.me\/([0-9+]+)(?:\?text=(.*))?$/.exec(url) ||
            /^https:\/\/api\.whatsapp\.com\/send\?phone=([0-9+]+)(?:&text=(.*))?$/.exec(url);
  if (!m) return url;
  const esAndroid = /Android/i.test((self.navigator && self.navigator.userAgent) || '');
  if (!esAndroid) return url;
  const tel = m[1];
  const textoParam = m[2] ? `&text=${m[2]}` : '';
  return `intent://send?phone=${tel}${textoParam}#Intent;scheme=whatsapp;package=com.whatsapp.w4b;S.browser_fallback_url=${encodeURIComponent(url)};end`;
}

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const url = (event.notification.data && event.notification.data.url) || '/';
  const esWhatsApp = /^https:\/\/(wa\.me|api\.whatsapp\.com\/send)/.test(url);
  const destino = urlParaAbrir(url);

  if (esWhatsApp) {
    // Los enlaces de WhatsApp siempre se abren en una ventana/pestaña
    // nueva: si en vez de eso navegamos una pestaña de Encaja que ya
    // estaba abierta (con client.navigate), Android no lo trata como
    // una apertura de enlace de verdad y no ofrece abrir la app, así
    // que se queda en la página web y pide instalar WhatsApp.
    event.waitUntil(self.clients.openWindow(destino));
    return;
  }

  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientsArr) => {
      for (const client of clientsArr) {
        if ('focus' in client) {
          // Si Encaja ya estaba abierta (aunque fuera en otra pantalla),
          // antes solo se enfocaba la ventana tal cual estaba, sin llevarla
          // a la coincidencia del aviso. Ahora, si el navegador lo permite,
          // la navegamos primero a la URL del aviso (con el comprador) y
          // luego la enfocamos.
          if ('navigate' in client) {
            return client.navigate(destino).then((c) => (c || client).focus()).catch(() => client.focus());
          }
          return client.focus();
        }
      }
      if (self.clients.openWindow) return self.clients.openWindow(destino);
    })
  );
});
