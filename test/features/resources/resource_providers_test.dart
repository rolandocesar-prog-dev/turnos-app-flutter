import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_app/src/features/resources/application/resource_providers.dart';

void main() {
  // En la app real, con el reintento automático de Riverpod 3 (que reintenta las Exception, como
  // FormatException o un permiso denegado), el catálogo quedaba «cargando» para siempre en vez de
  // mostrar el error (design.md §9). Esta prueba fija la decisión.
  test('los flujos de Firestore no se reintentan', () {
    final retries = {
      'catálogo': activeResourcesProvider.retry,
      'recurso': resourceProvider.retry,
      'franjas ocupadas': takenSlotsProvider.retry,
    };

    for (final MapEntry(key: name, value: retry) in retries.entries) {
      expect(retry, isNotNull, reason: name);
      expect(
        retry!(0, const FormatException('documento roto')),
        isNull,
        reason: name,
      );
      expect(retry(3, Exception('permission-denied')), isNull, reason: name);
    }
  });
}
