import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/no_retry.dart';
import '../../bookings/domain/booking.dart';
import '../../bookings/domain/booking_failure.dart';
import '../../resources/application/resource_providers.dart';
import '../data/firestore_admin_booking_repository.dart';
import '../data/firestore_resource_editor.dart';
import '../domain/admin_booking_repository.dart';
import '../domain/resource_editor.dart';

/// Escritura de recursos en Firestore; las pruebas lo reemplazan con un override.
final resourceEditorProvider = Provider<ResourceEditor>(
  (ref) => FirestoreResourceEditor(FirebaseFirestore.instance),
);

/// Reservas de todos, para el administrador; las pruebas lo reemplazan con un override.
final adminBookingRepositoryProvider = Provider<AdminBookingRepository>(
  (ref) => FirestoreAdminBookingRepository(FirebaseFirestore.instance),
);

/// Reservas de un día (a medianoche), en tiempo real (RF-06).
final dayBookingsProvider = StreamProvider.family<List<Booking>, DateTime>(
  (ref, day) => ref.watch(adminBookingRepositoryProvider).watchDay(day),
  retry: noRetry,
);

/// Correo de un cliente, para mostrar de quién es cada reserva.
final clientEmailProvider = FutureProvider.family<String?, String>(
  (ref, uid) => ref.watch(adminBookingRepositoryProvider).clientEmail(uid),
  retry: noRetry,
);

/// Cancelación por el administrador. Su estado es el de la última acción: en curso, error
/// (`BookingFailure`) o terminada.
final adminBookingControllerProvider =
    AsyncNotifierProvider<AdminBookingController, void>(
  AdminBookingController.new,
);

class AdminBookingController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Cancela [booking] con [reason] si todavía no empezó (RF-06); las reglas lo vuelven a
  /// comprobar con la hora del servidor.
  Future<void> cancel(Booking booking, String reason) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      final text = reason.trim();
      if (cancelReasonIssue(text) != null) {
        throw const BookingFailure(BookingFailureReason.invalidReason);
      }
      if (!canAdminCancel(booking, ref.read(clockProvider)())) {
        throw const BookingFailure(BookingFailureReason.notCancellable);
      }
      await ref.read(adminBookingRepositoryProvider).cancel(booking, text);
    });
    if (ref.mounted) state = result;
  }
}
