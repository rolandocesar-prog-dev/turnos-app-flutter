import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_app/src/core/firebase/firebase_setup.dart';

void main() {
  test('el emulador de Android usa la IP de la máquina anfitriona', () {
    expect(
      emulatorHost(isWeb: false, platform: TargetPlatform.android),
      '10.0.2.2',
    );
  });

  test('web, iOS y escritorio usan localhost', () {
    const cases = [
      (isWeb: true, platform: TargetPlatform.android),
      (isWeb: false, platform: TargetPlatform.iOS),
      (isWeb: false, platform: TargetPlatform.windows),
    ];
    for (final c in cases) {
      expect(
        emulatorHost(isWeb: c.isWeb, platform: c.platform),
        'localhost',
      );
    }
  });

  test('por defecto se usan los emuladores con el proyecto de demostración',
      () {
    expect(firebaseEnvironment, 'emulators');
    expect(demoProjectId, startsWith('demo-'));
  });
}
