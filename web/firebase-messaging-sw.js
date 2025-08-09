importScripts('https://www.gstatic.com/firebasejs/10.10.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.10.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyD31PUKCR1HRCZYsSxxE-XZZVSx9An_Uj4",
  authDomain: "profit-league-documents.firebaseapp.com",
  projectId: "profit-league-documents",
  storageBucket: "profit-league-documents.firebasestorage.app",
  messagingSenderId: "555319309212",
  appId: "1:555319309212:web:e0ce8b6d75336697578e59",
});

const messaging = firebase.messaging();

// ОБЯЗАТЕЛЬНО: обрабатываем пуш в фоновом режиме
messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);

  const notificationTitle = payload.notification?.title || 'Уведомление';
  const notificationOptions = {
    body: payload.notification?.body || '',
    icon: payload.notification?.icon || 'https://exchange.pr-lg.ru/Icons/Icon-192.png',
    data: {
      click_action: payload.notification?.click_action || 'https://exchange.pr-lg.ru/ProfitLeagueDocuments/'
    }
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});

// ОБЯЗАТЕЛЬНО: обработка клика по уведомлению
self.addEventListener('notificationclick', function(event) {
  event.notification.close();
  const url = event.notification.data?.click_action || 'https://exchange.pr-lg.ru/ProfitLeagueDocuments/';
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(windowClients => {
      for (let client of windowClients) {
        if (client.url === url && 'focus' in client) {
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow(url);
      }
    })
  );
});
