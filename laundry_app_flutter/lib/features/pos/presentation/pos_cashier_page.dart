import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/user_error_message.dart';
import '../../../core/extensions/currency_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_action_queue.dart';
import '../../../core/widgets/app_bottom_sheet_body.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/responsive_page.dart';
import '../domain/pos_models.dart';
import 'pos_controller.dart';

class PosCashierPage extends ConsumerStatefulWidget {
  const PosCashierPage({super.key});

  @override
  ConsumerState<PosCashierPage> createState() => _PosCashierPageState();
}

class _PosCashierPageState extends ConsumerState<PosCashierPage> {
  final Map<String, int> _cart = {};

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(posControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Kasir Es Teh')),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppStateView.error(
          title: 'Kasir gagal dimuat',
          message: '$error',
          actionLabel: 'Coba lagi',
          onAction: () => ref.read(posControllerProvider.notifier).refresh(),
        ),
        data: (data) {
          final products = data.products
              .where((item) => item.isActive)
              .toList();
          final total = _cart.entries.fold<int>(0, (sum, entry) {
            final product = products.where((item) => item.id == entry.key);
            return sum +
                (product.isEmpty ? 0 : product.first.price * entry.value);
          });
          return Column(
            children: [
              if (!data.isOpenToday)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: const Color(0xFFFFF3CD),
                  child: const Text(
                    'Tandai “Hari ini berjualan” dari Beranda sebelum memakai kasir.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              Expanded(
                child: products.isEmpty
                    ? AppStateView.empty(
                        title: 'Menu masih kosong',
                        message:
                            'Owner dapat menambahkan produk dari menu Menu.',
                      )
                    : ResponsivePage(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 210,
                                childAspectRatio: 1.22,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                          itemCount: products.length,
                          itemBuilder: (context, index) {
                            final product = products[index];
                            final quantity = _cart[product.id] ?? 0;
                            return _ProductCard(
                              product: product,
                              quantity: quantity,
                              enabled: data.isOpenToday,
                              onAdd: () => setState(
                                () => _cart[product.id] = quantity + 1,
                              ),
                              onRemove: quantity == 0
                                  ? null
                                  : () => setState(() {
                                      if (quantity == 1) {
                                        _cart.remove(product.id);
                                      } else {
                                        _cart[product.id] = quantity - 1;
                                      }
                                    }),
                            );
                          },
                        ),
                      ),
              ),
              if (_cart.isNotEmpty)
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: AppColors.outline)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${_cart.values.fold(0, (sum, value) => sum + value)} item',
                                style: const TextStyle(
                                  color: AppColors.secondaryText,
                                ),
                              ),
                              Text(
                                total.toRupiah(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () => _checkout(context, products, total),
                          icon: const Icon(Icons.payments_outlined),
                          label: const Text('Bayar'),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _checkout(
    BuildContext context,
    List<PosProduct> products,
    int total,
  ) async {
    var method = 'Tunai';
    final notes = TextEditingController();
    final confirmed = await showAppModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AppBottomSheetBody(
          children: [
            const Text(
              'Selesaikan Penjualan',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 8),
            for (final entry in _cart.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${products.firstWhere((item) => item.id == entry.key).name} × ${entry.value}',
                      ),
                    ),
                    Text(
                      (products
                                  .firstWhere((item) => item.id == entry.key)
                                  .price *
                              entry.value)
                          .toRupiah(),
                    ),
                  ],
                ),
              ),
            const Divider(height: 24),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Total',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                Text(
                  total.toRupiah(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Tunai', label: Text('Tunai')),
                ButtonSegment(value: 'Transfer', label: Text('Transfer')),
                ButtonSegment(value: 'QRIS', label: Text('QRIS')),
              ],
              selected: {method},
              showSelectedIcon: false,
              onSelectionChanged: (value) =>
                  setModalState(() => method = value.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notes,
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Simpan Transaksi'),
            ),
          ],
        ),
      ),
    );
    final noteValue = notes.text;
    notes.dispose();
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(posControllerProvider.notifier)
          .checkout(
            quantities: {..._cart},
            paymentMethod: method,
            notes: noteValue,
          );
      if (!mounted) return;
      setState(_cart.clear);
      showAppSnackBar('Transaksi ${total.toRupiah()} berhasil disimpan.');
    } catch (error) {
      if (mounted) {
        showAppSnackBar(
          userErrorMessage(error, fallback: 'Transaksi gagal disimpan.'),
        );
      }
    }
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.quantity,
    required this.enabled,
    required this.onAdd,
    required this.onRemove,
  });

  final PosProduct product;
  final int quantity;
  final bool enabled;
  final VoidCallback onAdd;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: enabled ? onAdd : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.local_cafe, color: Color(0xFF0F8B67)),
            const Spacer(),
            Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            Text(product.price.toRupiah()),
            if (quantity > 0)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: onRemove,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text(
                    '$quantity',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_circle),
                  ),
                ],
              ),
          ],
        ),
      ),
    ),
  );
}
