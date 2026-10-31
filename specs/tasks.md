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

- [ ] `fvm flutter pub add flutter_riverpod go_router` y `ProviderScope` en `main.dart`.
- [ ] Rutas con go_router y redirección según sesión.
- [ ] Proyecto de Firebase (desarrollo) y `flutterfire configure`.
- [ ] Emuladores de Firebase configurados para desarrollo y pruebas.

## M2 · Autenticación y catálogo (RF-01, RF-02)

- [ ] Registro e inicio de sesión con correo; perfil con rol `client`.
- [ ] Inicio de sesión con Google.
- [ ] Listado de recursos y detalle.
- [ ] Cálculo de franjas desde el horario semanal (dominio, con pruebas unitarias).
- [ ] Vista de franjas por fecha en tiempo real.

## M3 · Reservas (RF-03, RF-04)

- [ ] Transacción de reserva con id de franja determinista.
- [ ] Reglas de Firestore y pruebas de reglas en el emulador (RNF-01).
- [ ] Límite de 3 reservas activas y bloqueo de franjas pasadas.
- [ ] "Mis reservas" y cancelación con la regla de 2 horas.
- [ ] Prueba de integración: reservar → cancelar.

## M4 · Notificaciones y administración (RF-05, RF-06)

- [ ] FCM: registro de tokens por usuario.
- [ ] Cloud Function programada: recordatorio 1 h antes.
- [ ] Panel de administración: recursos, horarios, días bloqueados y reservas del día.

## M5 · Entrega

- [ ] Accesibilidad (RNF-03) y textos en ARB (RNF-06).
- [ ] Versión web desplegada en Firebase Hosting.
- [ ] Publicación en prueba interna de Google Play o TestFlight.
- [ ] README final con capturas, GIF y arquitectura.
- [ ] Agregar el proyecto, con enlaces, a la sección Proyectos del CV.
