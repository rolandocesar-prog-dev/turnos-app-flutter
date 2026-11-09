import 'dart:async';

import 'package:turnos_app/src/features/auth/domain/app_user.dart';
import 'package:turnos_app/src/features/auth/domain/auth_failure.dart';
import 'package:turnos_app/src/features/auth/domain/auth_repository.dart';
import 'package:turnos_app/src/features/auth/domain/user_profile_repository.dart';
import 'package:turnos_app/src/features/resources/domain/resource.dart';
import 'package:turnos_app/src/features/resources/domain/resource_repository.dart';

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

  @override
  Stream<List<Resource>> watchActive() => Stream.value([
        for (final r in resources)
          if (r.active) r,
      ]);

  @override
  Stream<Resource?> watch(String id) =>
      Stream.value(resources.where((r) => r.id == id).firstOrNull);
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
