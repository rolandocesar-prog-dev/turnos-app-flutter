import 'package:flutter/material.dart';

/// Pantalla pública de acceso. El registro y el inicio de sesión llegan en M2 (RF-01).
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text('Inicia sesión', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  'Necesitas una cuenta para ver los horarios y reservar.',
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
