import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../application/auth_controller.dart';
import '../application/auth_providers.dart';
import '../domain/auth_failure.dart';
import '../domain/credential_validators.dart';

/// Pantalla pública de acceso: iniciar sesión o crear cuenta con correo (RF-01, design.md §8).
/// Al iniciar sesión, la redirección por sesión lleva al inicio sola.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _registering = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final controller = ref.read(authControllerProvider.notifier);
    final email = _email.text.trim();
    final password = _password.text;
    if (_registering) {
      await controller.register(email: email, password: password);
    } else {
      await controller.signIn(email: email, password: password);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final action = ref.watch(authControllerProvider);
    final busy = action.isLoading;
    // En Riverpod 3, el estado de carga conserva el error anterior: mientras hay un intento en
    // curso no se muestra, para no confundirlo con el resultado del intento nuevo.
    final error =
        action.hasError && !busy ? _messageFor(l10n, action.error) : null;
    final title = _registering ? l10n.registerTitle : l10n.loginTitle;
    final googleAvailable = ref.watch(googleSignInAvailableProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.event_available,
                      size: 56,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: theme.textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.loginSubtitle,
                      style: theme.textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _email,
                      decoration: InputDecoration(
                        labelText: l10n.emailLabel,
                        prefixIcon: const Icon(Icons.mail_outline),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      enabled: !busy,
                      validator: (value) => l10n
                          .credentialIssue(CredentialValidators.email(value)),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      decoration: InputDecoration(
                        labelText: l10n.passwordLabel,
                        prefixIcon: const Icon(Icons.lock_outline),
                      ),
                      obscureText: true,
                      autofillHints: [
                        _registering
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      enabled: !busy,
                      onFieldSubmitted: (_) => _submit(),
                      validator: (value) => l10n.credentialIssue(
                        CredentialValidators.password(value),
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        error,
                        style: TextStyle(color: theme.colorScheme.error),
                        textAlign: TextAlign.center,
                        semanticsLabel: l10n.errorSemantics(error),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: busy ? null : _submit,
                      child: busy
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _registering
                                  ? l10n.registerButton
                                  : l10n.signInButton,
                            ),
                    ),
                    if (googleAvailable) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () => ref
                                .read(authControllerProvider.notifier)
                                .signInWithGoogle(),
                        icon: const Icon(Icons.account_circle_outlined),
                        label: Text(l10n.googleButton),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => setState(() => _registering = !_registering),
                      child: Text(
                        _registering
                            ? l10n.switchToSignIn
                            : l10n.switchToRegister,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _messageFor(AppLocalizations l10n, Object? error) =>
      l10n.authFailure(
        error is AuthFailure ? error.reason : AuthFailureReason.unknown,
      );
}
