import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/home/presentation/home_page.dart';

/// Raíz de la aplicación. La navegación con go_router y la inyección de
/// dependencias con Riverpod se incorporan en el hito M1 (ver specs/tasks.md).
class TurnosApp extends StatelessWidget {
  const TurnosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Turnos',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const HomePage(),
    );
  }
}
