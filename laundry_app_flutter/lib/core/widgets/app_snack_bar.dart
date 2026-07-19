import 'package:flutter/material.dart';

final appScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void showAppSnackBar(String message) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final messenger = appScaffoldMessengerKey.currentState;
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  });
}
