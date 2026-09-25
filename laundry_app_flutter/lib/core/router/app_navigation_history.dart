/// Remembers visited app pages even when navigation uses GoRouter.go, which
/// replaces the route stack. Modal sheets remain managed by Navigator.
class AppNavigationHistory {
  AppNavigationHistory();

  static final instance = AppNavigationHistory();
  final List<String> _paths = [];
  bool _returning = false;

  String? get previous => _paths.length < 2 ? null : _paths[_paths.length - 2];

  void record(String path) {
    if (path == '/splash' || path == '/sign-in') {
      _paths.clear();
      _returning = false;
      return;
    }
    if (_returning) {
      _returning = false;
      if (_paths.isNotEmpty && _paths.last == path) return;
    }
    if (_paths.isNotEmpty && _paths.last == path) return;
    _paths.add(path);
    if (_paths.length > 40) _paths.removeAt(0);
  }

  String? takePrevious() {
    if (_paths.length < 2) return null;
    _paths.removeLast();
    _returning = true;
    return _paths.last;
  }
}
