String formatQuantityForUnit(double quantity, String unit) {
  final normalizedUnit = unit.trim().toUpperCase();
  final hasFraction = quantity % 1 != 0;
  final quantityText = hasFraction
      ? quantity.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '')
      : quantity.round().toString();
  return '$quantityText $normalizedUnit';
}
