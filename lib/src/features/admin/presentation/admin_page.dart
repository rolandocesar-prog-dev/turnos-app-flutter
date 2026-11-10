import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/session_redirect.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/user_profile_repository.dart';
import '../../resources/application/resource_providers.dart';
import '../../resources/domain/resource.dart';
import '../../resources/domain/schedule_format.dart';

/// Panel de administración (RF-06, design.md §11): todos los recursos, activos e inactivos.
class AdminPage extends ConsumerWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(currentRoleProvider).value == UserRole.admin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Administración'),
        actions: [
          if (isAdmin)
            IconButton(
              tooltip: 'Reservas del día',
              icon: const Icon(Icons.today),
              onPressed: () => context.go('${AppRoutes.admin}/reservas'),
            ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => context.go('${AppRoutes.admin}/recursos/nuevo'),
              icon: const Icon(Icons.add),
              label: const Text('Nuevo recurso'),
            )
          : null,
      // Mientras el rol carga, se espera; con otro rol, la redirección ya llevó al inicio.
      body: isAdmin
          ? const _ResourceList()
          : const Center(
              child: CircularProgressIndicator(semanticsLabel: 'Cargando'),
            ),
    );
  }
}

class _ResourceList extends ConsumerWidget {
  const _ResourceList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resources = ref.watch(allResourcesProvider);
    final textTheme = Theme.of(context).textTheme;

    return resources.when(
      loading: () => const Center(
        child: CircularProgressIndicator(semanticsLabel: 'Cargando recursos'),
      ),
      error: (_, __) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No se pudieron cargar los recursos. Revisa tu conexión.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (items) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Recursos', style: textTheme.titleLarge),
          const SizedBox(height: 8),
          if (items.isEmpty) const Text('Todavía no hay recursos.'),
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
    return Card(
      child: ListTile(
        leading: Icon(
          resource.active ? Icons.event_available : Icons.visibility_off,
        ),
        title: Text(resource.name),
        subtitle: Text(
          '${ScheduleFormat.slotDuration(resource.slotMinutes)} · '
          '${resource.active ? 'Activo' : 'Inactivo: no aparece en el catálogo'}',
        ),
        trailing: const Icon(Icons.edit),
        onTap: () => context.go('${AppRoutes.admin}/recursos/${resource.id}'),
      ),
    );
  }
}
