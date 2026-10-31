import 'package:flutter/material.dart';

/// Pantalla inicial provisional. Se reemplaza por el listado de recursos
/// reservables en el hito M2 (RF-02).
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Turnos')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.event_available, size: 64),
              const SizedBox(height: 16),
              Text(
                'Reserva tu turno en segundos',
                style: textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Canchas, consultorios y servicios con horarios en tiempo real.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
