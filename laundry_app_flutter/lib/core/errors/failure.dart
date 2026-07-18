class Failure implements Exception {
  const Failure({required this.message, this.code, this.details});

  final String message;
  final String? code;
  final Object? details;

  @override
  String toString() {
    if (code == null) {
      return message;
    }
    return '$code: $message';
  }
}
