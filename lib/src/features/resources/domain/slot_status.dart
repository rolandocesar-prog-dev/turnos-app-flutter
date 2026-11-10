import 'slot_calculator.dart';

/// Estado de una franja para quien la mira (RF-02, design.md §9). El texto lo pone la
/// presentación (design.md §14).
enum SlotStatus { available, taken, past }

/// Una franja con su estado.
typedef SlotView = ({Slot slot, SlotStatus status});

/// Estado de cada franja: pasada si ya empezó, ocupada si su id está en [takenIds], y si no,
/// disponible. «Pasada» gana sobre «ocupada»: una franja que ya empezó no se puede reservar.
List<SlotView> slotStatuses(
  List<Slot> slots,
  Set<String> takenIds,
  DateTime now,
) =>
    [
      for (final slot in slots)
        (
          slot: slot,
          status: !slot.start.isAfter(now)
              ? SlotStatus.past
              : takenIds.contains(slot.id)
                  ? SlotStatus.taken
                  : SlotStatus.available,
        ),
    ];
