String formatQuantityForUnit(double quantity, String unit) {
  final normalizedUnit = unit.trim().toUpperCase();
  final hasFraction = quantity % 1 != 0;
  final quantityText = hasFraction
      ? quantity.toStringAsFixed(1)
      : quantity.round().toString();
  return '$quantityText $normalizedUnit';
}
