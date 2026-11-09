import 'dart:async';

import 'package:turnos_app/src/features/auth/domain/app_user.dart';
import 'package:turnos_app/src/features/auth/domain/auth_failure.dart';
import 'package:turnos_app/src/features/auth/domain/auth_repository.dart';
import 'package:turnos_app/src/features/auth/domain/user_profile_repository.dart';
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

/// Reservas en memoria: reservar ocupa la franja en [slots], como la transacción real.
class FakeBookingRepository implements BookingRepository {
  FakeBookingRepository(this.slots);

  final FakeSlotRepository slots;
  final booked = <String>[];
  final _starts = <DateTime>[];

  /// Reservas futuras activas que la persona ya tenía antes de la prueba.
  int existingActive = 0;

  @override
  Future<int> countActiveUpcoming(String uid, DateTime now) async =>
      existingActive + _starts.where((start) => start.isAfter(now)).length;

  /// Si no es `null`, la próxima reserva falla con este error.
  BookingFailure? failWith;

  /// Si no es `null`, las acciones esperan este futuro antes de responder.
  Completer<void>? hold;

  @override
  Future<void> book({
    required String uid,
    required Resource resource,
    required Slot slot,
  }) async {
    await hold?.future;
    final failure = failWith;
    if (failure != null) {
      failWith = null;
      throw failure;
    }
    booked.add('$uid:${resource.id}/${slot.id}');
    _starts.add(slot.start);
    slots.take(resource.id, dateKey(slot.start), slot.id);
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

/// Registra los perfiles creados.
class FakeUserProfileRepository implements UserProfileRepository {
  final ensured = <AppUser>[];

  @override
  Future<void> ensureProfile(AppUser user) async => ensured.add(user);
}
