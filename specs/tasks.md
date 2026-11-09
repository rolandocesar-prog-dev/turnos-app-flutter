# Tareas — App de reservas de turnos

Cada tarea referencia su requisito. Marca `[x]` al terminar y haz un commit por tarea.

## M0 · Base del proyecto

- [x] Estructura _feature-first_, tema Material 3 claro/oscuro y pantalla inicial.
- [x] Análisis estático estricto y primera prueba de widget.
- [x] CI en GitHub Actions (formato, análisis, pruebas).
- [x] Especificaciones SDD.
- [x] Fijar la versión de Flutter con FVM, en local y en CI (RNF-07).
- [x] Generar las carpetas de plataforma con `fvm flutter create` (ver README) y verificar
      `fvm flutter analyze` y `fvm flutter test` en local.

## M1 · Fundamentos

- [x] `fvm flutter pub add flutter_riverpod go_router` y `ProviderScope` en `main.dart`.
- [x] Firebase con los emuladores (Auth y Firestore) y el proyecto de demostración
      `demo-turnos`; `firebase-tools` como dependencia de desarrollo (design.md §6).
- [x] Rutas con go_router y redirección según sesión (RF-01).

## M2 · Autenticación y catálogo (RF-01, RF-02)

- [x] Reglas de Firestore para `users` y `resources`, con pruebas en el emulador y en el CI
      (RNF-01; se adelanta de M3 porque M2 ya escribe y lee esas colecciones).
- [x] Registro e inicio de sesión con correo; perfil con rol `client`.
- [x] Inicio de sesión con Google (web contra el emulador; en móvil necesita el proyecto real,
      M4).
- [x] Datos de ejemplo para el emulador; listado de recursos y detalle.
- [x] Cálculo de franjas desde el horario semanal (dominio, con pruebas unitarias).
- [x] Vista de franjas por fecha en tiempo real.

## M3 · Reservas (RF-03, RF-04)

- [x] Transacción de reserva con id de franja determinista.
- [x] Reglas de Firestore para `slots` y `bookings`, con sus pruebas (RNF-01).
- [ ] Límite de 3 reservas activas (en la app; en el servidor, M4) y bloqueo de franjas pasadas.
- [ ] "Mis reservas" y cancelación con la regla de 2 horas.
- [ ] Prueba de integración: reservar → cancelar.

## M4 · Notificaciones y administración (RF-05, RF-06)

- [ ] Proyecto real de Firebase y `flutterfire configure` (lo necesitan FCM, Cloud Functions y
      Hosting; design.md §6).
- [ ] FCM: registro de tokens por usuario.
- [ ] Cloud Function programada: recordatorio 1 h antes.
- [ ] Límite de 3 reservas activas también en el servidor (Cloud Functions; design.md §10).
- [ ] Panel de administración: recursos, horarios, días bloqueados y reservas del día.

## M5 · Entrega

- [ ] Accesibilidad (RNF-03) y textos en ARB (RNF-06).
- [ ] Versión web desplegada en Firebase Hosting.
- [ ] Publicación en prueba interna de Google Play o TestFlight.
- [ ] README final con capturas, GIF y arquitectura.
- [ ] Agregar el proyecto, con enlaces, a la sección Proyectos del CV.
