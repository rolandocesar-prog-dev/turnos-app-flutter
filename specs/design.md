# Diseño — App de reservas de turnos

Responde al **cómo** de [`requirements.md`](./requirements.md).

## 1. Arquitectura

Organización **por funcionalidad** (_feature-first_) y, dentro de cada una, **por capas**:

```
lib/
├── main.dart
└── src/
    ├── app.dart                 # MaterialApp.router, tema, rutas
    ├── core/                    # tema, errores, utilidades, constantes
    ├── routing/                 # go_router y redirecciones por sesión/rol
    └── features/
        ├── auth/
        ├── resources/           # catálogo y franjas (RF-02)
        ├── bookings/            # reservar, cancelar, mis reservas (RF-03, RF-04)
        └── admin/               # gestión (RF-06)
            ├── domain/          # entidades y reglas puras (sin Flutter ni Firebase)
            ├── data/            # repositorios: Firestore ⇄ entidades
            ├── application/     # casos de uso / controladores (Riverpod)
            └── presentation/    # pantallas y widgets
```

Regla de dependencias: `presentation → application → domain ← data`. El dominio no importa nada
de Flutter ni de Firebase, por lo que se prueba con pruebas unitarias puras.

## 2. Tecnologías

| Necesidad          | Elección                                   | Motivo                                                  |
| ------------------ | ------------------------------------------ | ------------------------------------------------------- |
| Estado y DI        | Riverpod                                   | Testeable, sin `BuildContext`, estándar actual.         |
| Navegación         | go_router                                  | Rutas declarativas, _deep links_ y redirección por rol. |
| Backend            | Firebase Auth + Cloud Firestore            | Tiempo real (RF-02) y sin servidor propio.              |
| Lógica de servidor | Cloud Functions (TypeScript)               | Recordatorios programados y notificaciones (RF-05).     |
| Notificaciones     | Firebase Cloud Messaging                   | Push en Android, iOS y web.                             |
| Modelos inmutables | `freezed` + `json_serializable` (opcional) | Igualdad por valor y serialización segura.              |
| Pruebas            | flutter_test, mocktail, integration_test   | Unitarias, de widgets y de integración.                 |
| Versión de Flutter | FVM (`.fvmrc`)                             | Misma versión por proyecto, en local y en CI.           |

Las dependencias se agregan con `fvm flutter pub add` cuando la tarea lo requiera, para usar
siempre la versión estable vigente.

La versión de Flutter (RNF-07) se declara en `.fvmrc`, que va al repositorio; `.fvm/` es local y se
ignora. El CI lee ese mismo archivo con `flutter-version-file`, de modo que subir de versión es un
único cambio.

## 3. Modelo de datos (Firestore)

```
users/{uid}
  displayName, email, role: "client" | "admin", fcmTokens: string[]

resources/{resourceId}
  name, description, photoUrl, slotMinutes, active: bool
  weeklySchedule: { mon: [{ start: "08:00", end: "22:00" }], ... }
  blockedDates: string[]                         // "2026-12-25"

resources/{resourceId}/slots/{yyyy-MM-ddTHH:mm}  // id determinista = una franja
  bookingId, uid, createdAt

bookings/{bookingId}
  resourceId, uid, start, end, status: "active" | "cancelled", cancelReason?, createdAt
```

### Cómo se evita la doble reserva (RF-03)

El id de cada franja es **determinista** (`recurso + fecha y hora`). Reservar es una
**transacción** que crea `slots/{id}` y `bookings/{id}` a la vez; las reglas de seguridad solo
permiten **crear** el slot si no existe. Si dos personas reservan a la vez, la segunda transacción
falla y la app muestra "Ese horario acaba de ocuparse".

## 4. Reglas de seguridad (RNF-01)

- Un cliente solo lee y escribe su `users/{uid}` y sus `bookings`.
- `resources` es de lectura pública para usuarios autenticados y de escritura solo para `admin`.
- La creación de `slots` exige que no exista y que `uid == request.auth.uid`.
- Las reglas se prueban con el emulador de Firebase y `@firebase/rules-unit-testing` en CI.

## 5. Estrategia de pruebas

| Nivel       | Qué se prueba                                                  |
| ----------- | -------------------------------------------------------------- |
| Unitarias   | Cálculo de franjas, límites de reservas, regla de las 2 horas. |
| Widgets     | Pantallas con repositorios simulados (mocktail + overrides).   |
| Integración | Flujo reservar → cancelar contra los emuladores de Firebase.   |
| Reglas      | Accesos permitidos y denegados en Firestore.                   |
