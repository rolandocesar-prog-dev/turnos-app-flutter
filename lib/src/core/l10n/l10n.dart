import 'package:flutter/widgets.dart';

import '../../../l10n/app_localizations.dart';
import '../../features/admin/domain/resource_input.dart';
import '../../features/auth/domain/auth_failure.dart';
import '../../features/auth/domain/credential_validators.dart';
import '../../features/bookings/domain/booking.dart';
import '../../features/bookings/domain/booking_failure.dart';
import '../../features/notifications/domain/push_repository.dart';
import '../../features/resources/domain/slot_status.dart';

export '../../../l10n/app_localizations.dart';

/// Acceso corto a los textos: `context.l10n.loginTitle` (design.md §14).
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Traducción de los motivos del dominio, que no tiene textos (design.md §14). Los que terminan en
/// `Issue` devuelven `null` si no hay problema, para usarlos directo como `validator`.
extension DomainMessages on AppLocalizations {
  String authFailure(AuthFailureReason reason) => switch (reason) {
        AuthFailureReason.invalidCredentials => authInvalidCredentials,
        AuthFailureReason.emailInUse => authEmailInUse,
        AuthFailureReason.weakPassword => authWeakPassword,
        AuthFailureReason.invalidEmail => emailInvalid,
        AuthFailureReason.tooManyRequests => authTooManyRequests,
        AuthFailureReason.network => networkError,
        AuthFailureReason.cancelled => authCancelled,
        AuthFailureReason.popupBlocked => authPopupBlocked,
        AuthFailureReason.unknown => genericError,
      };

  String? credentialIssue(CredentialIssue? issue) => switch (issue) {
        null => null,
        CredentialIssue.emailMissing => emailMissing,
        CredentialIssue.emailInvalid => emailInvalid,
        CredentialIssue.passwordMissing => passwordMissing,
        CredentialIssue.passwordTooShort =>
          passwordTooShort('${CredentialValidators.minPasswordLength}'),
      };

  String bookingFailure(BookingFailureReason reason) => switch (reason) {
        BookingFailureReason.slotTaken => bookingSlotTaken,
        BookingFailureReason.slotUnavailable => bookingSlotUnavailable,
        BookingFailureReason.limitReached => bookingLimitReached,
        BookingFailureReason.slotPast => bookingSlotPast,
        BookingFailureReason.tooLateToCancel => bookingTooLateToCancel,
        BookingFailureReason.notCancellable => bookingNotCancellable,
        BookingFailureReason.invalidReason => bookingInvalidReason,
        BookingFailureReason.network => networkError,
        BookingFailureReason.unknown => genericError,
      };

  /// El mensaje de una acción de reserva fallida: un [BookingFailure] o cualquier otro error.
  String bookingError(Object? error) => bookingFailure(
        error is BookingFailure ? error.reason : BookingFailureReason.unknown,
      );

  String pushFailure(PushFailureReason reason) => switch (reason) {
        PushFailureReason.denied => pushDenied,
        PushFailureReason.unknown => pushUnknown,
      };

  String slotStatusLabel(SlotStatus status) => slotStatus(status.name);

  /// Estado de una reserva cancelada, según quién la canceló.
  String cancellation(Booking booking) => switch (booking.cancelledBy) {
        CancelledBy.system => statusCancelledBySystem(
            booking.cancelReason ?? systemCancelDefaultReason,
          ),
        CancelledBy.business =>
          statusCancelledByBusiness(booking.cancelReason!),
        CancelledBy.client || null => statusCancelled,
      };

  String? cancelReasonIssue(CancelReasonIssue? issue) => switch (issue) {
        null => null,
        CancelReasonIssue.tooShort => reasonTooShort('$cancelReasonMinLength'),
        CancelReasonIssue.tooLong => tooLong('$cancelReasonMaxLength'),
      };

  String? resourceInputIssue(ResourceInputIssue? issue) => switch (issue) {
        null => null,
        ResourceInputIssue.nameMissing => nameMissing,
        ResourceInputIssue.nameTooLong =>
          tooLong('${ResourceInput.maxNameLength}'),
        ResourceInputIssue.descriptionTooLong =>
          tooLong('${ResourceInput.maxDescriptionLength}'),
      };

  String? dayRangesIssue(DayRangesException? error) => switch (error?.issue) {
        null => null,
        DayRangesIssue.notARange => rangeNotARange(error!.text),
        DayRangesIssue.invalidTime => rangeInvalidTime,
        DayRangesIssue.endBeforeStart => rangeEndBeforeStart,
        DayRangesIssue.overlap => rangeOverlap,
      };
}
