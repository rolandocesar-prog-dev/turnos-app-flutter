import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/slot_repository.dart';

/// Lee la ocupación del día con una consulta por rango de id: los ids son `yyyy-MM-ddTHH:mm`,
/// así que las franjas de un día quedan entre `fechaT00:00` y `fechaT23:59`.
class FirestoreSlotRepository implements SlotRepository {
  const FirestoreSlotRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<Set<String>> watchTaken(String resourceId, String dateKey) =>
      _firestore
          .collection('resources')
          .doc(resourceId)
          .collection('slots')
          .where(
            FieldPath.documentId,
            isGreaterThanOrEqualTo: '${dateKey}T00:00',
          )
          .where(FieldPath.documentId, isLessThanOrEqualTo: '${dateKey}T23:59')
          .snapshots()
          .map((snapshot) => {for (final doc in snapshot.docs) doc.id});
}
