import 'package:flutter/widgets.dart';

import '../../../l10n/app_localizations.dart';
import '../../features/auth/domain/auth_failure.dart';
import '../../features/auth/domain/credential_validators.dart';

export '../../../l10n/app_localizations.dart';

/// Acceso corto a los textos: `context.l10n.loginTitle` (design.md §14).
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Traducción de los motivos del dominio, que no tiene textos (design.md §14).
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

  /// `null` si no hay problema, para usarlo directo como `validator` de un campo.
  String? credentialIssue(CredentialIssue? issue) => switch (issue) {
        null => null,
        CredentialIssue.emailMissing => emailMissing,
        CredentialIssue.emailInvalid => emailInvalid,
        CredentialIssue.passwordMissing => passwordMissing,
        CredentialIssue.passwordTooShort =>
          passwordTooShort(CredentialValidators.minPasswordLength),
      };
}
