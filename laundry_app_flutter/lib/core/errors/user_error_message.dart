import 'failure.dart';

/// Converts technical failures into messages that are safe and useful in the UI.
String userErrorMessage(Object? error, {required String fallback}) {
  if (error is Failure && !_looksTechnical(error.message)) {
    return error.message;
  }

  final text = error?.toString().toLowerCase() ?? '';
  if (_containsAny(text, const [
    'socketexception',
    'clientexception',
    'failed host lookup',
    'connection reset',
    'connection refused',
    'network is unreachable',
    'timeout',
  ])) {
    return 'Koneksi ke server terputus. Coba lagi beberapa saat.';
  }

  return fallback;
}

bool _looksTechnical(String value) {
  final text = value.toLowerCase();
  return _containsAny(text, const [
    'postgrestexception',
    'authexception',
    'functionexception',
    'pgrst',
    'sqlstate',
    'schema cache',
    'relation ',
    'rpc',
    'stack trace',
  ]);
}

bool _containsAny(String text, List<String> markers) {
  return markers.any(text.contains);
}
