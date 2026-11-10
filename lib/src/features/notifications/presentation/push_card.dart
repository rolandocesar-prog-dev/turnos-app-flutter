import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/push_providers.dart';
import '../domain/push_repository.dart';

/// Tarjeta de «Mis reservas» para activar los avisos en este dispositivo (design.md §13). Solo
/// aparece donde hay FCM.
class PushCard extends ConsumerWidget {
  const PushCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(pushAvailableProvider)) return const SizedBox.shrink();
    final state = ref.watch(pushControllerProvider);
    final enabled = state.value == true && !state.hasError;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: enabled
            ? const Row(
                children: [
                  Icon(Icons.notifications_active),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('Avisos activados en este dispositivo.'),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.notifications_none),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Recibe un recordatorio 1 hora antes de tu turno y un aviso si el '
                          'negocio lo cancela.',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed:
                        state.isLoading ? null : () => _enable(context, ref),
                    child:
                        Text(state.isLoading ? 'Activando…' : 'Activar avisos'),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _enable(BuildContext context, WidgetRef ref) async {
    await ref.read(pushControllerProvider.notifier).enable();
    if (!context.mounted) return;
    final message = switch (ref.read(pushControllerProvider)) {
      AsyncError(error: final PushFailure failure) => failure.message,
      AsyncError() => PushFailureReason.unknown.message,
      _ => 'Listo: te avisaremos 1 hora antes de cada turno.',
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
