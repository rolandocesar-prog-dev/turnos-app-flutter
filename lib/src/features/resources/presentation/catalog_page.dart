import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/session_redirect.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/user_profile_repository.dart';
import '../application/resource_providers.dart';
import '../domain/resource.dart';
import '../domain/schedule_format.dart';

/// Inicio: catálogo de recursos activos, en tiempo real (RF-02).
class CatalogPage extends ConsumerWidget {
  const CatalogPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resources = ref.watch(activeResourcesProvider);
    final isAdmin = ref.watch(currentRoleProvider).value == UserRole.admin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Turnos'),
        actions: [
          if (isAdmin)
            IconButton(
              tooltip: 'Administración',
              icon: const Icon(Icons.admin_panel_settings),
              onPressed: () => context.go(AppRoutes.admin),
            ),
          IconButton(
            tooltip: 'Mis reservas',
            icon: const Icon(Icons.event_note),
            onPressed: () => context.go(AppRoutes.myBookings),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: resources.when(
        loading: () => const Center(
          child:
              CircularProgressIndicator(semanticsLabel: 'Cargando el catálogo'),
        ),
        error: (_, __) => const _Message(
          icon: Icons.cloud_off,
          text: 'No se pudo cargar el catálogo. Revisa tu conexión.',
        ),
        data: (items) => items.isEmpty
            ? const _Message(
                icon: Icons.event_busy,
                text: 'Todavía no hay lugares para reservar.',
              )
            : _CatalogList(items),
      ),
    );
  }
}

class _CatalogList extends StatelessWidget {
  const _CatalogList(this.resources);

  final List<Resource> resources;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Reserva tu turno en segundos', style: textTheme.titleLarge),
        const SizedBox(height: 4),
        Text('Elige dónde quieres reservar.', style: textTheme.bodyMedium),
        const SizedBox(height: 16),
        for (final resource in resources)
          Card(
            child: ListTile(
              leading: const Icon(Icons.event_available),
              title: Text(resource.name),
              subtitle: Text(
                '${resource.description}\n'
                '${ScheduleFormat.slotDuration(resource.slotMinutes)}',
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/recursos/${resource.id}'),
            ),
          ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
