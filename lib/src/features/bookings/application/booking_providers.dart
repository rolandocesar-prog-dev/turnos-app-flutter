import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/no_retry.dart';
import '../../auth/application/auth_providers.dart';
import '../../resources/application/resource_providers.dart';
import '../../resources/domain/resource.dart';
import '../../resources/domain/slot_calculator.dart';
import '../data/firestore_booking_repository.dart';
import '../domain/booking.dart';
import '../domain/booking_failure.dart';
import '../domain/booking_policy.dart';
import '../domain/booking_repository.dart';

/// Reservas en Firestore; las pruebas lo reemplazan con un override.
final bookingRepositoryProvider = Provider<BookingRepository>(
  (ref) => FirestoreBookingRepository(FirebaseFirestore.instance),
);

/// Reservas del usuario con sesión, en tiempo real (Mis reservas, RF-04).
final myBookingsProvider = StreamProvider<List<Booking>>(
  (ref) {
    final user = ref.watch(authStateProvider).value;
    if (user == null) return Stream.value(const []);
    return ref.watch(bookingRepositoryProvider).watchMine(user.uid);
  },
  retry: noRetry,
);

/// Acciones de reserva. Su estado es el de la última acción: en curso, error (`BookingFailure`)
/// o terminada.
final bookingControllerProvider =
    AsyncNotifierProvider<BookingController, void>(BookingController.new);

class BookingController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Reserva [slot] de [resource] para el usuario con sesión (RF-03). Antes comprueba que la
  /// franja no haya pasado y el límite de reservas activas (en la app; en el servidor, M4).
  Future<void> book(Resource resource, Slot slot) => _run(() async {
        final user = await ref.read(authStateProvider.future);
        if (user == null) {
          throw const BookingFailure(BookingFailureReason.unknown);
        }
        final repository = ref.read(bookingRepositoryProvider);
        final now = ref.read(clockProvider)();
        final blocker = bookingBlocker(
          slot: slot,
          now: now,
          activeUpcoming: await repository.countActiveUpcoming(user.uid, now),
        );
        if (blocker != null) throw BookingFailure(blocker);
        await repository.book(uid: user.uid, resource: resource, slot: slot);
      });

  /// Cancela [booking] si faltan al menos 2 horas (RF-04); las reglas lo vuelven a comprobar
  /// con la hora del servidor.
  Future<void> cancel(Booking booking) => _run(() async {
        if (!canCancel(booking, ref.read(clockProvider)())) {
          throw const BookingFailure(BookingFailureReason.tooLateToCancel);
        }
        await ref.read(bookingRepositoryProvider).cancel(booking);
      });

  Future<void> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(action);
    if (ref.mounted) state = result;
  }
}
