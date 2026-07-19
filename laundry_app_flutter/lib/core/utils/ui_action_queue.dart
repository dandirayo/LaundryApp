import 'package:flutter/material.dart';

const _bottomSheetSettleDelay = Duration(milliseconds: 350);

Future<T?> showAppModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool showDragHandle = false,
  bool useRootNavigator = false,
  bool isDismissible = true,
  bool enableDrag = true,
  ShapeBorder? shape,
  Color? backgroundColor,
  Clip? clipBehavior,
}) async {
  final result = await showModalBottomSheet<T>(
    context: context,
    builder: builder,
    isScrollControlled: isScrollControlled,
    showDragHandle: showDragHandle,
    useRootNavigator: useRootNavigator,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    shape: shape,
    backgroundColor: backgroundColor,
    clipBehavior: clipBehavior,
  );

  await waitForTransientUiDismissal(settleDelay: _bottomSheetSettleDelay);
  return result;
}

Future<void> waitForTransientUiDismissal({
  Duration settleDelay = const Duration(milliseconds: 16),
}) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await Future<void>.delayed(Duration.zero);
  await WidgetsBinding.instance.endOfFrame;
  await Future<void>.delayed(settleDelay);
}
