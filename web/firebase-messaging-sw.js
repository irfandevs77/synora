importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBlmzzrP5-jwWA3T93VW-eYfyvUL6-vFUc',
  authDomain: 'synora-9c49e.firebaseapp.com',
  projectId: 'synora-9c49e',
  storageBucket: 'synora-9c49e.firebasestorage.app',
  messagingSenderId: '1002344068231',
  appId: '1:1002344068231:web:9f8c04900200b1a1b27422'
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const notification = payload.notification || {};
  const title = notification.title || 'Synora';
  const options = {
    body: notification.body || '',
    icon: '/icons/Icon-192.png',
    data: payload.data || {}
  };

  self.registration.showNotification(title, options);
});
