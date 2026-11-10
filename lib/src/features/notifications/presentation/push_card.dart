import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
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
    final l10n = context.l10n;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: enabled
            ? Row(
                children: [
                  const Icon(Icons.notifications_active),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(l10n.pushEnabled),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.notifications_none),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(l10n.pushIntro),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed:
                        state.isLoading ? null : () => _enable(context, ref),
                    child: Text(
                      state.isLoading ? l10n.pushEnabling : l10n.pushEnable,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _enable(BuildContext context, WidgetRef ref) async {
    await ref.read(pushControllerProvider.notifier).enable();
    if (!context.mounted) return;
    final l10n = context.l10n;
    final message = switch (ref.read(pushControllerProvider)) {
      AsyncError(error: final PushFailure failure) =>
        l10n.pushFailure(failure.reason),
      AsyncError() => l10n.pushUnknown,
      _ => l10n.pushEnabledMessage,
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
