// Service worker de FCM para la web (design.md §13): muestra los avisos con la pestaña cerrada.
// La versión del SDK es la que usa firebase_core_web (supportedFirebaseJsSdkVersion); las
// opciones son las de lib/firebase_options.dart (web), que no son secretas (design.md §6).
importScripts('https://www.gstatic.com/firebasejs/13.1.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/13.1.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyCJMPDgFJjL7v0u13oPzGjC9vA2KbLrCkE',
  appId: '1:902487711242:web:98b7df4280ab35dbbb89f3',
  messagingSenderId: '902487711242',
  projectId: 'turnos-rv-portafolio',
});

// Los mensajes con «notification» los muestra el SDK solo; no hace falta más código.
firebase.messaging();
