import 'package:flutter/material.dart';

import '../../../core/extensions/currency_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/payment_method_totals.dart';

class PaymentMethodSummaryCard extends StatelessWidget {
  const PaymentMethodSummaryCard({
    super.key,
    required this.title,
    required this.totals,
    this.hybridOrderCount,
    this.hybridAmount,
  });

  final String title;
  final PaymentMethodTotals totals;
  final int? hybridOrderCount;
  final int? hybridAmount;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _AmountBox(
                    label: 'Tunai / Cash',
                    value: totals['Tunai'],
                    icon: Icons.payments_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _AmountBox(
                    label: 'Transfer / TF',
                    value: totals['Transfer'],
                    icon: Icons.account_balance_outlined,
                  ),
                ),
              ],
            ),
            if (totals['QRIS'] > 0 || totals['Lainnya'] > 0) ...[
              const SizedBox(height: 10),
              Text(
                'QRIS ${totals['QRIS'].toRupiah()}  •  Lainnya ${totals['Lainnya'].toRupiah()}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.secondaryText),
              ),
            ],
            if (hybridOrderCount != null && hybridAmount != null) ...[
              const SizedBox(height: 12),
              Text(
                'Hybrid: $hybridOrderCount pesanan • ${hybridAmount!.toRupiah()} pada periode ini',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              const Text(
                'Hybrid adalah pesanan yang dibayar Tunai dan Transfer; nominalnya sudah termasuk di kedua angka di atas.',
                style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AmountBox extends StatelessWidget {
  const _AmountBox({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.softBlue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primaryBlue),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value.toRupiah(),
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: AppColors.primaryNavy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
