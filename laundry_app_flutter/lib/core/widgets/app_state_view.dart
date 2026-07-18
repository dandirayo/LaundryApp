import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AppStateView extends StatelessWidget {
  const AppStateView({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  const AppStateView.empty({
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    Key? key,
  }) : this(
         key: key,
         icon: Icons.inbox_outlined,
         title: title,
         message: message,
         actionLabel: actionLabel,
         onAction: onAction,
       );

  const AppStateView.error({
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    Key? key,
  }) : this(
         key: key,
         icon: Icons.error_outline,
         title: title,
         message: message,
         actionLabel: actionLabel,
         onAction: onAction,
       );

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.softMint,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: AppColors.primaryNavy, size: 30),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.secondaryText,
                height: 1.35,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class LoadingStateView extends StatelessWidget {
  const LoadingStateView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox.square(
        dimension: 36,
        child: CircularProgressIndicator(strokeWidth: 3),
      ),
    );
  }
}
