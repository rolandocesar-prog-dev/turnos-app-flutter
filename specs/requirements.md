# Requisitos — App de reservas de turnos

> Spec Driven Development: **qué** debe hacer la app. El **cómo** está en
> [`design.md`](./design.md) y el plan en [`tasks.md`](./tasks.md).

## 1. Objetivo

Que un negocio con agenda (cancha deportiva, consultorio, peluquería, etc.) publique sus horarios
disponibles y que sus clientes reserven, cancelen y reciban recordatorios desde el celular, **sin
reservas duplicadas en el mismo horario**.

## 2. Roles

| Rol           | Puede                                                              |
| ------------- | ------------------------------------------------------------------ |
| Cliente       | Ver recursos y horarios, reservar, cancelar y ver sus reservas.    |
| Administrador | Todo lo anterior y además gestionar recursos, horarios y reservas. |

## 3. Alcance

**Incluye:** autenticación, catálogo de recursos, disponibilidad por franjas, reservas,
cancelaciones, recordatorios push y panel de administración dentro de la app. Android, iOS y web.

**Fuera de alcance (v1):** pagos en línea, varios negocios en una misma cuenta, chat.

## 4. Requisitos funcionales

Criterios de aceptación en formato EARS.

### RF-01 · Autenticación

- CUANDO un usuario se registra con correo y contraseña, la app DEBE crear su perfil con rol
  `cliente`.
- La app DEBE permitir iniciar sesión con Google.
- MIENTRAS no haya sesión iniciada, la app DEBE mostrar solo las pantallas públicas y de acceso.
- SI las credenciales son incorrectas, la app DEBE mostrar un mensaje claro sin revelar si el
  correo existe.

### RF-02 · Catálogo de recursos

- La app DEBE listar los recursos reservables (nombre, foto, descripción, duración del turno).
- CUANDO el usuario elige un recurso y una fecha, la app DEBE mostrar sus franjas horarias con el
  estado _disponible_ u _ocupada_, actualizado en tiempo real.

### RF-03 · Reservar

- CUANDO un cliente confirma una franja disponible, la app DEBE crear la reserva y mostrarla en
  "Mis reservas".
- SI dos clientes intentan reservar la misma franja al mismo tiempo, solo una reserva DEBE
  confirmarse; la otra persona DEBE recibir el aviso "Ese horario acaba de ocuparse".
- La app NO DEBE permitir reservar franjas en el pasado.
- Un cliente NO DEBE tener más de 3 reservas futuras activas a la vez.

### RF-04 · Cancelar

- CUANDO un cliente cancela una reserva con al menos 2 horas de anticipación, la app DEBE
  liberar la franja.
- SI faltan menos de 2 horas, la app DEBE impedir la cancelación y explicar el motivo.

### RF-05 · Recordatorios

- La app DEBE enviar una notificación push 1 hora antes del turno.
- CUANDO el administrador cancela una reserva, el cliente DEBE recibir una notificación.

### RF-06 · Administración

- El administrador DEBE poder crear, editar y desactivar recursos.
- El administrador DEBE poder definir horarios semanales y días bloqueados por recurso.
- El administrador DEBE ver las reservas del día y poder cancelarlas indicando un motivo.

## 5. Requisitos no funcionales

| ID     | Requisito                                                                                 |
| ------ | ----------------------------------------------------------------------------------------- |
| RNF-01 | Las reglas de seguridad de Firestore impiden leer o modificar datos ajenos (con pruebas). |
| RNF-02 | Las pantallas principales cargan en menos de 2 s en un celular de gama media.             |
| RNF-03 | Accesible: contraste AA, textos escalables y etiquetas semánticas en botones e íconos.    |
| RNF-04 | Funciona sin conexión en modo lectura (caché de Firestore).                               |
| RNF-05 | Cobertura de pruebas ≥ 70 % en dominio y aplicación; CI en cada push.                     |
| RNF-06 | Textos en español, preparados para traducción (`intl`/ARB).                               |
| RNF-07 | La versión de Flutter está fijada por proyecto con FVM y es la misma en local y en CI.    |

## 6. Criterio de "terminado"

- Todos los RF con pruebas (unitarias, de widgets o de integración).
- Demo instalable (Google Play en prueba interna o TestFlight, y versión web).
- README con capturas, GIF y arquitectura.
