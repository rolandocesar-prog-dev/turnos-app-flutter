# Turnos — App de reservas con Flutter y Firebase

[![CI](https://github.com/rolandocesar-prog-dev/turnos-app-flutter/actions/workflows/ci.yml/badge.svg)](https://github.com/rolandocesar-prog-dev/turnos-app-flutter/actions/workflows/ci.yml)

App para que canchas, consultorios y otros negocios con agenda publiquen sus horarios y sus
clientes reserven, cancelen y reciban recordatorios, **sin reservas duplicadas**.

> 🚧 Proyecto en desarrollo. El avance está en [`specs/tasks.md`](./specs/tasks.md).

## Qué demuestra

- Flutter multiplataforma (Android, iOS y web) con arquitectura por funcionalidad y por capas.
- Estado con Riverpod y navegación con go_router.
- Firestore en tiempo real con **transacciones** para evitar la doble reserva.
- Reglas de seguridad de Firestore **con pruebas automatizadas**.
- Notificaciones push con Cloud Functions y Firebase Cloud Messaging.
- Pruebas unitarias, de widgets y de integración, con CI.

## Stack

Flutter · Dart · Riverpod · go_router · Firebase (Auth, Firestore, Cloud Functions, FCM, Hosting) ·
GitHub Actions

## Primeros pasos

La versión de Flutter está fijada en `.fvmrc` y se usa con [FVM](https://fvm.app). En Windows, FVM
necesita el Modo de desarrollador activado. Instala esa versión con:

```bash
fvm install
```

En desarrollo, la app usa los **emuladores de Firebase** con el proyecto de demostración
`demo-turnos`: no hace falta una cuenta de Firebase (ver
[`specs/design.md`](./specs/design.md) §6). Los emuladores necesitan Java 11 o superior y Node.js:

```bash
npm ci                 # firebase-tools, fijado en package.json
npm run emulators      # Auth :9099, Firestore :8080, interfaz en http://localhost:4000
```

En otra terminal:

```bash
fvm flutter pub get
fvm flutter run -d chrome
```

Calidad (lo mismo que corre el CI):

```bash
fvm dart format --output=none --set-exit-if-changed .
fvm flutter analyze
fvm flutter test --coverage
npm run test:rules     # reglas de Firestore en su propio emulador
```

### Prueba de integración

`integration_test/` recorre la app real en Chrome contra los emuladores: crear una cuenta,
reservar una franja, verla en «Mis reservas», cancelarla y comprobar que vuelve a estar libre.
`npm run test:e2e` levanta sus propios emuladores (con los de desarrollo apagados), carga los datos
de ejemplo y corre `flutter drive`. Necesita un
[chromedriver](https://googlechromelabs.github.io/chrome-for-testing/) de la misma versión que tu
Chrome, escuchando en el puerto 4444:

```bash
chromedriver --port=4444
```

En otra terminal (en PowerShell: `$env:FLUTTER = "fvm flutter"`):

```bash
FLUTTER="fvm flutter" npm run test:e2e
```

## Cómo se desarrolla

El proyecto sigue **Spec Driven Development**:

- [`specs/requirements.md`](./specs/requirements.md): qué debe hacer, con criterios de aceptación.
- [`specs/design.md`](./specs/design.md): arquitectura, modelo de datos y decisiones.
- [`specs/tasks.md`](./specs/tasks.md): plan por hitos.

## Licencia

[MIT](./LICENSE)
