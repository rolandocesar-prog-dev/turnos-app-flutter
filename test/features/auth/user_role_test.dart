import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_app/src/features/auth/data/firestore_user_profile_repository.dart';
import 'package:turnos_app/src/features/auth/domain/user_profile_repository.dart';

void main() {
  group('roleFromProfile (design.md §11)', () {
    test('solo role "admin" es administrador', () {
      expect(roleFromProfile({'role': 'admin'}), UserRole.admin);
      expect(roleFromProfile({'role': 'client'}), UserRole.client);
    });

    test('sin perfil, sin rol o con un valor raro, es cliente', () {
      expect(roleFromProfile(null), UserRole.client);
      expect(roleFromProfile({}), UserRole.client);
      expect(roleFromProfile({'role': 'Admin'}), UserRole.client);
      expect(roleFromProfile({'role': true}), UserRole.client);
    });
  });
}
