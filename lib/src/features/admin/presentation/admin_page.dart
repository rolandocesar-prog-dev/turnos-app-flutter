import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/l10n/schedule_labels.dart';
import '../../../routing/session_redirect.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/user_profile_repository.dart';
import '../../resources/application/resource_providers.dart';
import '../../resources/domain/resource.dart';

/// Panel de administración (RF-06, design.md §11): todos los recursos, activos e inactivos.
class AdminPage extends ConsumerWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isAdmin = ref.watch(currentRoleProvider).value == UserRole.admin;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminTitle),
        actions: [
          if (isAdmin)
            IconButton(
              tooltip: l10n.adminBookingsTooltip,
              icon: const Icon(Icons.today),
              onPressed: () => context.go('${AppRoutes.admin}/reservas'),
            ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => context.go('${AppRoutes.admin}/recursos/nuevo'),
              icon: const Icon(Icons.add),
              label: Text(l10n.newResource),
            )
          : null,
      // Mientras el rol carga, se espera; con otro rol, la redirección ya llevó al inicio.
      body: isAdmin
          ? const _ResourceList()
          : Center(
              child: CircularProgressIndicator(semanticsLabel: l10n.loading),
            ),
    );
  }
}

class _ResourceList extends ConsumerWidget {
  const _ResourceList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final resources = ref.watch(allResourcesProvider);
    final textTheme = Theme.of(context).textTheme;

    return resources.when(
      loading: () => Center(
        child: CircularProgressIndicator(semanticsLabel: l10n.resourcesLoading),
      ),
      error: (_, __) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l10n.resourcesError, textAlign: TextAlign.center),
        ),
      ),
      data: (items) => ListView(
        // Espacio abajo para que el botón flotante no tape el último recurso.
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Text(l10n.resourcesTitle, style: textTheme.titleLarge),
          const SizedBox(height: 8),
          if (items.isEmpty) Text(l10n.noResources),
          for (final resource in items) _ResourceTile(resource),
        ],
      ),
    );
  }
}

class _ResourceTile extends StatelessWidget {
  const _ResourceTile(this.resource);

  final Resource resource;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: ListTile(
        leading: Icon(
          resource.active ? Icons.event_available : Icons.visibility_off,
        ),
        title: Text(resource.name),
        subtitle: Text(
          l10n.resourceSummary(
            ScheduleLabels(l10n).slotDuration(resource.slotMinutes),
            resource.active ? l10n.resourceActive : l10n.resourceInactive,
          ),
        ),
        trailing: const Icon(Icons.edit),
        onTap: () => context.go('${AppRoutes.admin}/recursos/${resource.id}'),
      ),
    );
  }
}
