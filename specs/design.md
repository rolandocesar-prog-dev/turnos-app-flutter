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
  resourceId, resourceName, slotId, uid, startAt, endAt (timestamps),
  status: "active" | "cancelled", createdAt, cancelledAt?, cancelReason?
```

`resourceName` se copia en la reserva para mostrar «Mis reservas» sin leer cada recurso.

### Cómo se evita la doble reserva (RF-03)

El id de cada franja es **determinista** (`recurso + fecha y hora`). Reservar es una
**transacción** que crea `slots/{id}` y `bookings/{id}` a la vez; las reglas de seguridad solo
permiten **crear** el slot si no existe. Si dos personas reservan a la vez, la segunda transacción
falla y la app muestra "Ese horario acaba de ocuparse".

## 4. Reglas de seguridad (RNF-01)

- Un cliente solo lee y escribe su `users/{uid}` y sus `bookings`.
- `users/{uid}` (M2): solo su dueño lo lee. Al crearlo, el rol **debe** ser `client` (nadie se
  da `admin` a sí mismo) y el correo, el de su sesión. Al actualizarlo no puede cambiar `role` ni
  `email`. No se borra desde la app. Los administradores se asignan fuera de la app. El dueño
  también actualiza `fcmTokens` (§13).
- `resources` (M2): lectura para usuarios autenticados; escritura solo para quien tiene
  `role == "admin"` en su `users/{uid}`.
- `resources/{id}/slots` (M2): **lectura** para usuarios autenticados, para mostrar qué franjas
  están ocupadas (RF-02). Como cualquiera con sesión las lee, un slot guarda solo datos opacos
  (`bookingId`, `uid`, `createdAt`), nunca nombre ni correo. La escritura sigue cerrada hasta M3.
- `slots` y `bookings` (M3), siempre **en la misma transacción**:
  - **Reservar**: el slot solo se *crea* si no existe (escribir sobre uno existente sería una
    actualización, y no está permitida), con el `uid` de la sesión y el `bookingId` de una reserva
    que se crea en la misma transacción (`getAfter`) a nombre del mismo usuario, para ese recurso
    y esa franja. La reserva exige: dueño = sesión, estado `active`, `startAt` **en el futuro**
    según el servidor (`request.time`), `endAt > startAt`, recurso existente y activo, y solo los
    campos del modelo.
  - **Cancelar**: el dueño pasa la reserva de `active` a `cancelled` (y solo toca `status` y
    `cancelledAt`) si faltan **al menos 2 horas** según el servidor; en la misma transacción borra
    su slot, lo que solo se permite si la reserva queda cancelada (`getAfter`).
  - Cada cliente lee solo sus reservas; las consultas deben filtrar por su `uid`. Nada se borra.
- Todo lo demás está cerrado.
- Las reglas se prueban con el emulador de Firestore y `@firebase/rules-unit-testing`, con el
  ejecutor de pruebas de Node (`node --test`, sin más dependencias): `npm run test:rules` levanta
  el emulador, corre `rules-tests/` y lo apaga. El CI lo ejecuta en un trabajo propio.

### Datos de ejemplo

`npm run seed` carga recursos de ejemplo (una cancha y un consultorio, con horario semanal y un
día bloqueado) en el emulador en marcha. Usa `@firebase/rules-unit-testing` con las reglas
desactivadas, así no hace falta el SDK de administración.

## 5. Estrategia de pruebas

| Nivel       | Qué se prueba                                                  |
| ----------- | -------------------------------------------------------------- |
| Unitarias   | Cálculo de franjas, límites de reservas, regla de las 2 horas. |
| Widgets     | Pantallas con repositorios simulados (mocktail + overrides).   |
| Integración | Flujo reservar → cancelar contra los emuladores de Firebase.   |
| Reglas      | Accesos permitidos y denegados en Firestore.                   |

## 6. Entornos de Firebase

- **Desarrollo y pruebas: emuladores locales** con el proyecto de demostración `demo-turnos`. Los
  proyectos `demo-*` solo existen en los emuladores: no hace falta una cuenta, no tienen costo y
  no hay riesgo de tocar datos reales. Las reglas de seguridad (RNF-01) se prueban ahí de todos
  modos.
- **Proyecto real** (M4): `turnos-rv-portafolio`, en el plan gratuito Spark, con Firestore en
  `southamerica-east1` (São Paulo, la región más cercana; no se puede cambiar). Pertenece a la
  cuenta personal del autor, no a la de ningún cliente.
  - `flutterfire configure --platforms=android,web` registra las apps y genera
    `lib/firebase_options.dart` y `android/app/google-services.json`. iOS se agrega cuando haya una
    Mac para compilarlo (M5, TestFlight).
  - Esas opciones (clave de API, id de app) **no son secretas**: identifican el proyecto ante
    Google y viajan dentro de toda app publicada. Lo que protege los datos son las reglas de
    seguridad (§4). Van al repositorio para que el CI y cualquiera puedan compilar.
  - Las Cloud Functions necesitan el plan Blaze (pago por uso): mientras el proyecto siga en
    Spark, se desarrollan y prueban en el emulador, y se despliegan cuando se active Blaze.
  - Las reglas y los índices se publican con `npm run deploy:firestore` (proyecto explícito en el
    comando, para no publicar nunca en otro).
- La app elige el entorno con `--dart-define=FIREBASE_ENV=…`: `emulators` (por defecto, con las
  opciones de `demo-turnos`: clave y app ficticias, que los emuladores aceptan, en
  `lib/src/core/firebase/`) o `production` (las opciones de `firebase_options.dart`, sin
  emuladores). Un valor desconocido falla al arrancar, en vez de conectarse a un lugar inesperado.
- Emuladores (`firebase.json`): Auth en el puerto 9099, Firestore en 8080 y la interfaz en 4000.
  La app se conecta a `localhost` (web y escritorio) o a `10.0.2.2` (emulador de Android).
- `firebase-tools` es una dependencia de desarrollo de npm (`package.json`), así su versión queda
  fijada: `npm run emulators` los levanta.
- Las pruebas de widgets no usan Firebase: reemplazan los providers de datos con overrides de
  Riverpod.

## 7. Navegación y sesión (RF-01)

- `AuthRepository` (dominio) expone el usuario actual como `Stream<AppUser?>`; su implementación
  con Firebase Auth vive en `data/`. `authStateProvider` lo publica con Riverpod.
- `routerProvider` crea el `GoRouter` y se vuelve a evaluar cuando cambia la sesión
  (`refreshListenable`). Redirección: sin sesión, cualquier ruta protegida lleva a `/login`; con
  sesión, `/login` lleva al inicio. Mientras la sesión todavía se está cargando se muestra una
  pantalla de espera, para no mandar al login a quien ya inició sesión.
- Rutas de M1: `/` (inicio, protegida) y `/login` (pública). Las pantallas de acceso reales llegan
  en M2.

## 8. Autenticación (RF-01, M2)

- `AuthRepository` suma `signInWithEmail`, `registerWithEmail`, `signInWithGoogle` y `signOut`.
  Los errores de Firebase se traducen a `AuthFailure` del dominio, con mensajes en español:
  **usuario inexistente, contraseña incorrecta y credencial inválida dan el mismo mensaje**
  («Correo o contraseña incorrectos»), para no revelar si el correo existe. Hay mensajes propios
  para correo ya registrado, contraseña débil, correo mal escrito, demasiados intentos y falta de
  conexión.
- Al registrarse, y la primera vez que alguien entra con Google, se crea `users/{uid}` con rol
  `client` (`UserProfileRepository.ensureProfile`, que no pisa un perfil existente).
- Google: `signInWithPopup` en web; el emulador de Auth muestra su propio selector de cuentas de
  prueba. En Android e iOS hace falta el proyecto real (M4): ahí el botón no se muestra.
  `signInWithPopup` exige `authDomain` en las opciones de Firebase, aun con los emuladores (sin él
  falla antes de abrir la ventana); las de `demo-turnos` lo incluyen. Si el navegador bloquea la
  ventana emergente, el mensaje dice cómo permitirla.
- La pantalla de acceso valida antes de enviar (correo con formato, contraseña de 6 caracteres o
  más), desactiva el botón mientras espera y alterna entre «Iniciar sesión» y «Crear cuenta».

## 9. Catálogo y franjas (RF-02, M2)

- `Resource` (dominio) refleja `resources/{id}`; el catálogo muestra solo los `active`.
- **Cálculo de franjas** (`domain/slot_calculator.dart`, función pura): para un recurso y una
  fecha, recorre los intervalos del horario semanal de ese día y los corta en franjas de
  `slotMinutes`; una franja que no entra completa al final del intervalo se descarta. Un día de
  `blockedDates` no tiene franjas. Cada franja tiene id determinista `yyyy-MM-ddTHH:mm` (§3).
- Las horas son las **locales del negocio**, sin zona horaria (`DateTime` local); la zona del
  negocio se modela cuando haga falta (M4, recordatorios).
- **Estado en tiempo real**: la vista escucha `resources/{id}/slots` del día (consulta por rango de
  id) y marca cada franja como *ocupada* si tiene documento. Las franjas pasadas se muestran como
  no disponibles (el bloqueo al reservar es de M3). El estado de cada franja (`disponible`,
  `ocupada`, `pasada`) lo decide una función pura con la hora actual de un provider de reloj,
  que las pruebas fijan.
- La vista ofrece los próximos 7 días («Hoy», «Mañana», «mié 11»…). Cada franja muestra la hora
  y su estado con texto e ícono, no solo con color (RNF-03); reservar llega en M3.
- `npm run seed` agrega dos franjas ocupadas de mañana en la cancha, para ver el estado en la
  demo.
- **Robustez** (hallada al probar contra el emulador con un recurso mal cargado):
  - En el catálogo, un documento mal formado **se omite y se registra**; los demás se muestran.
    En el detalle de ese recurso sí se informa el error.
  - Los `StreamProvider` de Firestore usan `retry: noRetry`. El reintento automático de Riverpod
    3 reintenta las `Exception` y, mientras tanto, el estado vuelve a «cargando»: en la app real
    el catálogo quedaba cargando para siempre en lugar de mostrar el error. Firestore ya maneja la
    reconexión por su cuenta.
- Cada franja es un nodo de accesibilidad propio («09:00, disponible»), para que un lector de
  pantalla la anuncie por separado.
- Las pruebas de reglas no deben correr contra el emulador de desarrollo: dejan datos de prueba.
  Se corren con `npm run test:rules`, que levanta su propio emulador.

## 10. Reservas (RF-03, RF-04, M3)

- **Reservar** (`BookingRepository.book`): una transacción lee el slot; si existe, falla con
  `BookingFailure.slotTaken` («Ese horario acaba de ocuparse»); si no, crea el slot y la reserva
  (id generado) juntos. Si otra persona confirma la misma franja un instante antes, Firestore
  reintenta la transacción, que entonces ve el slot y falla con ese mismo aviso; y si una escritura
  directa intentara pisarlo, las reglas la rechazan (§4).
- **Límite de 3 reservas futuras activas** (RF-03): antes de la transacción, la app cuenta las
  reservas `active` del usuario con `startAt` futuro (las transacciones de los SDK móviles y web no
  admiten consultas). **Limitación conocida**: las reglas de Firestore no pueden contar documentos,
  así que un cliente modificado podría saltarse el límite, y dos reservas simultáneas del mismo
  usuario también. El control en el servidor llega en M4 con Cloud Functions. La doble reserva de
  una franja, en cambio, sí la impide el servidor.
  - El conteo (`countActiveUpcoming`) consulta `uid ==` y `startAt >` ahora, y filtra el estado en
    la app: así usa el mismo índice compuesto (`uid`, `startAt`) que «Mis reservas», declarado en
    `firestore.indexes.json`.
- **Franjas pasadas** (RF-03): la app no ofrece reservarlas (§9); si la franja empieza mientras el
  diálogo está abierto, al confirmar se rechaza con «Ese horario ya pasó». Las reglas rechazan
  igual una reserva con `startAt` en el pasado según la hora del servidor.
- Ambas comprobaciones son una función pura del dominio (`bookingBlocker`, con
  `maxActiveBookings = 3`), con pruebas unitarias.
- **Cancelar** (RF-04, `BookingRepository.cancel`): un lote atómico (*batch*; no hace falta leer
  nada antes, así que no es una transacción) marca la reserva `cancelled` y borra su slot, que
  vuelve a estar disponible. Faltando menos de 2 horas, la app no ofrece
  cancelar y explica el motivo («Solo se puede cancelar hasta 2 horas antes»); las reglas lo
  rechazan igual con la hora del servidor. La regla de las 2 horas es una función pura del
  dominio (`canCancel`), con la misma frontera que las reglas.
- **Mis reservas** (`/mis-reservas`, desde el ícono de la barra del catálogo): las próximas
  activas, de la más cercana a la más lejana, con su botón de cancelar (o el motivo por el que ya
  no se puede); y las anteriores (pasadas o canceladas), de la más reciente a la más vieja, sin
  acciones. Escucha en tiempo real las reservas del usuario (`uid ==`, ordenadas por `startAt`),
  con el índice compuesto de `firestore.indexes.json`. Cancelar pide confirmación y avisa el
  resultado; una reserva mal formada se omite, como en el catálogo.
- **Errores**: `BookingFailure` con mensajes en español (franja ocupada, franja no disponible,
  límite alcanzado, franja pasada, fuera de plazo para cancelar, sin conexión, desconocido); un
  rechazo de las reglas (`permission-denied`) se traduce según la acción: al reservar, «Ese horario
  ya no está disponible» (franja pasada según el servidor, recurso desactivado); al cancelar, el
  plazo de 2 horas.
- La transacción **devuelve** si reservó en lugar de lanzar el error desde adentro, para que el
  aviso de franja ocupada llegue igual en todas las plataformas.
- **Interfaz**: una franja disponible es un botón («Reservar a las 15:00»); al tocarla, un diálogo
  pide confirmar con el recurso, el día y la hora, y un aviso informa el resultado. Mientras se
  reserva, las demás franjas no se pueden tocar.
- **Prueba de integración** (reservar → cancelar): con `integration_test` sobre la app real en
  Chrome (`flutter drive`), contra los emuladores con datos de ejemplo. Recorre iniciar sesión,
  reservar una franja, verla en «Mis reservas», cancelarla y comprobar que vuelve a estar
  disponible. El CI la ejecuta en un trabajo propio.
  - `flutter test` no corre pruebas de integración en web, por eso se usa `flutter drive` con
    chromedriver en el puerto 4444 (`-d web-server --browser-name=chrome`, sin ventana). En el CI,
    el runner de Ubuntu ya trae Chrome y su chromedriver (`CHROMEWEBDRIVER`).
  - `npm run test:e2e` usa `firebase emulators:exec`: emuladores nuevos y vacíos en cada
    ejecución, datos de `scripts/seed.mjs` y una cuenta nueva. Reserva la primera franja libre de
    mañana, que siempre está a más de 2 horas, así que se puede cancelar a cualquier hora.
  - Control: quitando el borrado de la franja al cancelar, las reglas rechazan la cancelación y la
    prueba falla.

## 11. Administración (RF-06, M4)

Se hace antes que el proyecto real de Firebase: todo funciona contra los emuladores.

- **Quién es administrador**: el rol de `users/{uid}` (§4). Nadie se lo da desde la app; en
  desarrollo, `npm run seed` crea en el emulador de Auth la cuenta `admin@turnos.test` con perfil
  `admin` (contraseña de prueba en el README; solo existe en los emuladores).
- **Rol en la app**: `UserProfileRepository.watchRole(uid)` publica el rol en tiempo real
  (`currentRoleProvider`); sin perfil, el rol es `client`. Un administrador ve en el catálogo el
  ícono «Administración».
- **Rutas**: `/admin` (recursos, activos e inactivos), `/admin/recursos/nuevo`,
  `/admin/recursos/:id` y `/admin/reservas`. Una función pura (`adminRedirect`) manda al inicio a
  quien no es administrador; mientras el rol carga, la página espera. Las reglas son el control
  real: la redirección solo evita mostrar pantallas que fallarían.
- **Reglas**:
  - `resources`: el administrador crea y edita con **validación** (solo los campos del modelo;
    `name` de 1 a 60 caracteres; `description` hasta 300; `slotMinutes` entero de 5 a 240;
    `active` booleano; `weeklySchedule` mapa; `blockedDates` lista). Un recurso **no se borra**: se
    desactiva (`active: false`), así las reservas que lo nombran siguen teniendo sentido.
  - `users`: el administrador puede leer los perfiles, para saber de quién es cada reserva.
  - `bookings`: el administrador lee todas y cancela una activa que **todavía no empezó**, sin el
    plazo de 2 horas, con `cancelReason` obligatorio (de 3 a 200 caracteres), en el mismo lote que
    borra su franja. El cliente no puede escribir `cancelReason`.
- **Formulario de recurso**: nombre, descripción, duración del turno (15, 30, 45, 60, 90 o 120
  minutos), activo, horario y días bloqueados. El horario de cada día se escribe como texto
  («09:00-13:00, 15:00-19:00»; vacío = cerrado) y lo valida una función pura del dominio
  (`parseDayRanges`: formato, fin después del inicio, intervalos en orden y sin solaparse), con
  mensajes por campo. Los días bloqueados se agregan con un selector de fecha y se quitan desde su
  chip. Un recurso nuevo recibe un id generado. Para que el selector de fecha esté en español, la
  app carga las traducciones de Material (`flutter_localizations`, locale `es`); los textos
  propios pasan a ARB en M5 (RNF-06).
- `resourceToFirestore` es el inverso del mapper de lectura (con prueba de ida y vuelta) y solo
  escribe los campos que aceptan las reglas; guardar reemplaza el documento entero.
- **Reservas del día**: consulta por rango de `startAt` del día elegido (índice simple), en tiempo
  real, con flechas para el día anterior y el siguiente. Cada reserva muestra hora, recurso,
  cliente (correo del perfil) y estado. Cancelar pide el motivo; el cliente lo ve en «Mis
  reservas» («Cancelada por el negocio: …»). La notificación push al cliente llega con FCM (M4,
  proyecto real).

## 12. Cloud Functions (M4)

- **Código**: `functions/`, TypeScript estricto, Node 22, Firebase Functions de 2.ª generación y
  el SDK de administración. La lógica de decisión es **pura** (sin Firebase) y tiene pruebas
  unitarias; los disparadores solo leen, llaman a esa lógica y escriben.
- **Pruebas**: unitarias con Vitest; de integración contra los emuladores de Functions y
  Firestore (`npm run test:functions` en la raíz, con `firebase emulators:exec`). El CI las corre
  en el trabajo de reglas, que ya tiene Node y Java.
- **Despliegue**: necesita el plan Blaze. Mientras el proyecto siga en Spark, las funciones solo
  corren en el emulador (decisión del 2026-11-10).
- **Límite de 3 reservas en el servidor** (RF-03): las reglas no pueden contar documentos (§10),
  así que un disparador `onDocumentCreated('bookings/{id}')` revisa las reservas activas futuras
  del mismo cliente después de cada reserva.
  - Las ordena por `createdAt` (y por id si empatan) y cancela las que queden **después de la
    tercera**. Como todos los disparadores calculan el mismo orden, dos reservas simultáneas del
    mismo cliente terminan igual: se conservan las 3 primeras, sin importar cuál disparador corra
    antes.
  - Cancela como la app: `status: cancelled`, `cancelledAt`, `cancelledBy: "system"` y un
    `cancelReason`, y borra la franja en el mismo lote, que vuelve a estar libre. El cliente lo ve
    en «Mis reservas» como «Cancelada automáticamente: …».
  - Es un control **posterior**: durante unos segundos la reserva de más existe. La app ya lo
    impide antes (§10), así que solo actúa ante un cliente modificado o dos reservas simultáneas.
  - `cancelledBy` lo escribe solo el servidor; las reglas no dejan que el cliente ni el
    administrador lo escriban (el administrador cancela con `cancelReason`, §11).

## 13. Notificaciones push (RF-05, M4)

- **Tokens**: cada dispositivo donde el cliente activa los avisos guarda su identificador de FCM
  en `users/{uid}.fcmTokens` (`arrayUnion`, sin duplicados). Desde firebase_messaging 17 ese
  identificador es el id de instalación (FID) que entrega `register()` por `onRegistered`
  (`getToken` quedó obsoleto); el SDK de administración envía a un FID con `FidMessage`. Las reglas dejan que el dueño agregue o
  quite tokens (lista de hasta 10 elementos) y nada más; el servidor borra los que FCM rechace al
  enviar.
- **Cuándo se pide el permiso**: no al iniciar sesión, sino cuando el cliente toca «Activar
  avisos» en «Mis reservas», que explica para qué sirven (recordatorio 1 hora antes y aviso si el
  negocio cancela). Si el navegador o el sistema niega el permiso, se explica cómo habilitarlo.
  Un token renovado (`onTokenRefresh`) se guarda solo.
- **Dónde funciona**: con el entorno `production` en web y Android (`pushAvailableProvider`). Con
  los emuladores no hay FCM (el proyecto `demo-turnos` no existe en Google), así que la tarjeta
  no se muestra. En web, `web/firebase-messaging-sw.js` recibe los avisos con la pestaña cerrada;
  se usa la clave VAPID por defecto de Firebase.
- `PushRepository` (dominio) pide el permiso y entrega el token; su implementación con
  `firebase_messaging` vive en `data/`. Las pruebas usan un repositorio simulado.

### Envío (Cloud Functions)

- **Recordatorio** (RF-05): `reminders`, una función programada cada 5 minutos, busca las reservas
  que empiezan dentro de la próxima hora (rango de `startAt`, índice simple; el estado se filtra
  en código) que siguen activas y no tienen `reminderSentAt`. Marca `reminderSentAt` en una
  transacción **antes** de enviar: si algo falla, el cliente se queda sin un aviso, pero nunca
  recibe dos. Como mira toda la hora siguiente y no solo una franja de 5 minutos, una ejecución
  perdida no deja turnos sin recordatorio.
- **Aviso de cancelación** (RF-05): `bookingCancelledNotice`, un disparador
  `onDocumentUpdated('bookings/{id}')`, avisa cuando una reserva pasa de `active` a `cancelled`
  con `cancelReason` y sin `cancelledBy` (la canceló el negocio, §11). Las que cancela el cliente
  no se avisan; las del límite automático tampoco (el cliente acaba de reservar y lo ve en la
  app).
- **Textos**: «Tu turno es en 1 hora» / «Cancha de fútbol 5, hoy a las 18:00.» y «Tu reserva fue
  cancelada» / «Cancha de fútbol 5, mar 10 nov a las 18:00. Motivo: …». Las horas se escriben en
  la **zona del negocio**, `America/La_Paz` (parámetro `BUSINESS_TIME_ZONE`), no en la del
  servidor, que corre en UTC. Funciones puras, con pruebas.
- **Destinatarios**: los ids de `users/{uid}.fcmTokens`. Los que FCM rechaza como no registrados
  o inválidos se quitan del perfil (`arrayRemove`).
- **Emulador**: no hay FCM, así que el envío pasa por una interfaz (`PushSender`). En producción
  usa `sendEach` del SDK de administración con `FidMessage`; en el emulador
  (`FUNCTIONS_EMULATOR`) guarda cada aviso en la colección `devOutbox`, que las pruebas leen y
  que las reglas mantienen cerrada.
- `reminderSentAt` solo lo escribe el servidor (las reglas de `bookings` no lo permiten a nadie
  más).
