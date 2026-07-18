import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_state_view.dart';
import 'responsive_page.dart';

class FeatureStatusPage extends StatelessWidget {
  const FeatureStatusPage({
    required this.title,
    required this.phase,
    required this.icon,
    required this.description,
    this.actions = const [],
    super.key,
  });

  final String title;
  final String phase;
  final IconData icon;
  final String description;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ResponsivePage(
        child: ListView(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.softMint,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(icon, color: AppColors.primaryNavy),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              Text(
                                phase,
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: AppColors.primaryBlue,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.secondaryText,
                        height: 1.45,
                      ),
                    ),
                    if (actions.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Wrap(spacing: 12, runSpacing: 12, children: actions),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const AppStateView.empty(
              title: 'Belum ada data tersinkron',
              message:
                  'Halaman ini sudah memiliki route dan state valid. Data produksi akan tampil setelah modul transaksinya selesai.',
            ),
          ],
        ),
      ),
    );
  }
}
