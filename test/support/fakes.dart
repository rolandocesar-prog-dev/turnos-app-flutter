import 'dart:async';

import 'package:turnos_app/src/features/auth/domain/app_user.dart';
import 'package:turnos_app/src/features/auth/domain/auth_failure.dart';
import 'package:turnos_app/src/features/auth/domain/auth_repository.dart';
import 'package:turnos_app/src/features/auth/domain/user_profile_repository.dart';
import 'package:turnos_app/src/features/bookings/domain/booking.dart';
import 'package:turnos_app/src/features/bookings/domain/booking_failure.dart';
import 'package:turnos_app/src/features/bookings/domain/booking_repository.dart';
import 'package:turnos_app/src/features/resources/domain/resource.dart';
import 'package:turnos_app/src/features/resources/domain/resource_repository.dart';
import 'package:turnos_app/src/features/resources/domain/slot_calculator.dart';
import 'package:turnos_app/src/features/resources/domain/slot_repository.dart';

/// Recursos de ejemplo para las pruebas.
const testCancha = Resource(
  id: 'cancha',
  name: 'Cancha de fútbol 5',
  description: 'Cancha techada.',
  slotMinutes: 60,
  active: true,
  weeklySchedule: {
    DateTime.monday: [TimeRange(8 * 60, 22 * 60)],
  },
);

const testConsultorio = Resource(
  id: 'consultorio',
  name: 'Consultorio dental',
  description: 'Consulta general.',
  slotMinutes: 30,
  active: true,
  weeklySchedule: {
    DateTime.monday: [TimeRange(9 * 60, 13 * 60), TimeRange(15 * 60, 19 * 60)],
    DateTime.saturday: [TimeRange(9 * 60, 12 * 60)],
  },
);

/// Catálogo en memoria; [resources] se puede cambiar antes de mostrar la pantalla.
class FakeResourceRepository implements ResourceRepository {
  FakeResourceRepository([
    this.resources = const [testCancha, testConsultorio],
  ]);

  List<Resource> resources;

  /// Si no es `null`, el catálogo falla con este error (p. ej. permiso denegado).
  Object? failWith;

  @override
  Stream<List<Resource>> watchActive() => failWith != null
      ? Stream.error(failWith!)
      : Stream.value([
          for (final r in resources)
            if (r.active) r,
        ]);

  @override
  Stream<List<Resource>> watchAll() => failWith != null
      ? Stream.error(failWith!)
      : Stream.value(
          [...resources]..sort((a, b) => a.name.compareTo(b.name)),
        );

  @override
  Stream<Resource?> watch(String id) =>
      Stream.value(resources.where((r) => r.id == id).firstOrNull);
}

/// Ocupación de franjas controlada por la prueba: [setTaken] la cambia «en vivo».
class FakeSlotRepository implements SlotRepository {
  final _taken = <String, Set<String>>{};
  final _controllers = <String, StreamController<Set<String>>>{};

  void setTaken(String resourceId, String dateKey, Set<String> ids) {
    final key = '$resourceId/$dateKey';
    _taken[key] = ids;
    _controllers[key]?.add(ids);
  }

  /// Marca ocupada una franja más, como haría una reserva.
  void take(String resourceId, String dateKey, String slotId) => setTaken(
        resourceId,
        dateKey,
        {...?_taken['$resourceId/$dateKey'], slotId},
      );

  /// Libera una franja, como haría una cancelación.
  void release(String resourceId, String dateKey, String slotId) => setTaken(
        resourceId,
        dateKey,
        {...?_taken['$resourceId/$dateKey']}..remove(slotId),
      );

  @override
  Stream<Set<String>> watchTaken(String resourceId, String dateKey) {
    final key = '$resourceId/$dateKey';
    final controller =
        _controllers.putIfAbsent(key, StreamController<Set<String>>.broadcast);
    return Stream.multi((listener) {
      listener.add(_taken[key] ?? const {});
      final subscription = controller.stream.listen(listener.add);
      listener.onCancel = subscription.cancel;
    });
  }
}

/// Una reserva de ejemplo de [uid] que empieza en [start] y dura una hora.
Booking testBooking(
  String id,
  DateTime start, {
  String uid = 'u1',
  Resource resource = testConsultorio,
  BookingStatus status = BookingStatus.active,
}) =>
    Booking(
      id: id,
      resourceId: resource.id,
      resourceName: resource.name,
      slotId: slotId(start),
      uid: uid,
      startAt: start,
      endAt: start.add(const Duration(hours: 1)),
      status: status,
    );

/// Reservas en memoria: reservar ocupa la franja en [slots] y cancelar la libera, como la
/// transacción real; «Mis reservas» se actualiza en vivo.
class FakeBookingRepository implements BookingRepository {
  FakeBookingRepository(this.slots);

  final FakeSlotRepository slots;
  final _bookings = <Booking>[];
  final _changes = StreamController<void>.broadcast();

  /// Reservas hechas en la prueba, como `uid:recurso/franja`.
  final booked = <String>[];

  /// Ids de las reservas canceladas en la prueba.
  final cancelled = <String>[];

  /// Si no es `null`, la próxima acción falla con este error.
  BookingFailure? failWith;

  /// Si no es `null`, las acciones esperan este futuro antes de responder.
  Completer<void>? hold;

  /// Reserva que ya existía antes de la prueba.
  void add(Booking booking) {
    _bookings.add(booking);
    _changes.add(null);
  }

  List<Booking> _of(String uid) => [
        for (final b in _bookings)
          if (b.uid == uid) b,
      ]..sort((a, b) => a.startAt.compareTo(b.startAt));

  @override
  Stream<List<Booking>> watchMine(String uid) => Stream.multi((listener) {
        listener.add(_of(uid));
        final subscription =
            _changes.stream.listen((_) => listener.add(_of(uid)));
        listener.onCancel = subscription.cancel;
      });

  @override
  Future<int> countActiveUpcoming(String uid, DateTime now) async =>
      _of(uid).where((b) => b.isUpcoming(now)).length;

  @override
  Future<void> book({
    required String uid,
    required Resource resource,
    required Slot slot,
  }) async {
    await _act();
    booked.add('$uid:${resource.id}/${slot.id}');
    add(
      testBooking(
        'b${_bookings.length + 1}',
        slot.start,
        uid: uid,
        resource: resource,
      ),
    );
    slots.take(resource.id, dateKey(slot.start), slot.id);
  }

  @override
  Future<void> cancel(Booking booking) async {
    await _act();
    cancelled.add(booking.id);
    final index = _bookings.indexWhere((b) => b.id == booking.id);
    _bookings[index] = Booking(
      id: booking.id,
      resourceId: booking.resourceId,
      resourceName: booking.resourceName,
      slotId: booking.slotId,
      uid: booking.uid,
      startAt: booking.startAt,
      endAt: booking.endAt,
      status: BookingStatus.cancelled,
    );
    _changes.add(null);
    slots.release(booking.resourceId, dateKey(booking.startAt), booking.slotId);
  }

  Future<void> _act() async {
    await hold?.future;
    final failure = failWith;
    if (failure != null) {
      failWith = null;
      throw failure;
    }
  }
}

/// Sesión controlada por la prueba, sin Firebase (design.md §6). Iniciar sesión o registrarse
/// emite el usuario, como Firebase; [failWith] hace fallar la próxima acción.
class FakeAuthRepository implements AuthRepository {
  final _changes = StreamController<AppUser?>.broadcast();
  final calls = <String>[];
  AuthFailure? failWith;

  /// Si no es `null`, las acciones esperan este futuro antes de responder.
  Completer<void>? hold;

  void emit(AppUser? user) => _changes.add(user);

  Future<void> close() => _changes.close();

  @override
  Stream<AppUser?> authStateChanges() => _changes.stream;

  @override
  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) =>
      _act('signIn:$email', email);

  @override
  Future<AppUser> registerWithEmail({
    required String email,
    required String password,
  }) =>
      _act('register:$email', email);

  /// Simula la cuenta de Google elegida en la ventana emergente.
  @override
  Future<AppUser> signInWithGoogle() =>
      _act('google', 'google.user@ejemplo.com');

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    emit(null);
  }

  Future<AppUser> _act(String call, String email) async {
    calls.add(call);
    await hold?.future;
    final failure = failWith;
    if (failure != null) {
      failWith = null;
      throw failure;
    }
    final user = AppUser(uid: 'uid-$email', email: email);
    emit(user);
    return user;
  }
}

/// Registra los perfiles creados; los uids de [admins] tienen rol de administrador.
class FakeUserProfileRepository implements UserProfileRepository {
  FakeUserProfileRepository({this.admins = const {}});

  final Set<String> admins;
  final ensured = <AppUser>[];

  @override
  Future<void> ensureProfile(AppUser user) async => ensured.add(user);

  @override
  Stream<UserRole> watchRole(String uid) =>
      Stream.value(admins.contains(uid) ? UserRole.admin : UserRole.client);
}
