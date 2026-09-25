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
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/pos_models.dart';
import 'pos_controller.dart';

class PosProductsPage extends ConsumerWidget {
  const PosProductsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwner =
        ref.watch(authControllerProvider).value?.user?.role == UserRole.owner;
    final state = ref.watch(posControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Menu Es Teh')),
      floatingActionButton: isOwner
          ? FloatingActionButton.extended(
              onPressed: () => _showProductForm(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Tambah Menu'),
            )
          : null,
      body: ResponsivePage(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => AppStateView.error(
            title: 'Menu gagal dimuat',
            message: '$error',
            actionLabel: 'Coba lagi',
            onAction: () => ref.read(posControllerProvider.notifier).refresh(),
          ),
          data: (data) => data.products.isEmpty
              ? AppStateView.empty(
                  title: 'Menu masih kosong',
                  message: isOwner
                      ? 'Tekan Tambah Menu untuk membuat produk pertama.'
                      : 'Owner belum menambahkan produk.',
                )
              : ListView.separated(
                  itemCount: data.products.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 7),
                  itemBuilder: (context, index) {
                    final product = data.products[index];
                    return Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(
                            0xFF0F8B67,
                          ).withValues(alpha: 0.10),
                          child: const Icon(
                            Icons.local_cafe,
                            color: Color(0xFF0F8B67),
                          ),
                        ),
                        title: Text(
                          product.name,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          '${product.category} · ${product.price.toRupiah()}',
                        ),
                        trailing: isOwner
                            ? Switch(
                                value: product.isActive,
                                onChanged: (value) =>
                                    _toggle(context, ref, product, value),
                              )
                            : Text(
                                product.isActive ? 'Aktif' : 'Nonaktif',
                                style: TextStyle(
                                  color: product.isActive
                                      ? const Color(0xFF16794A)
                                      : AppColors.secondaryText,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                        onTap: isOwner
                            ? () => _showProductForm(context, ref, product)
                            : null,
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    PosProduct product,
    bool value,
  ) async {
    try {
      await ref
          .read(posControllerProvider.notifier)
          .saveProduct(
            product: product,
            name: product.name,
            category: product.category,
            price: product.price,
            isActive: value,
          );
    } catch (error) {
      if (context.mounted) showAppSnackBar('Menu gagal diperbarui: $error');
    }
  }

  Future<void> _showProductForm(
    BuildContext context,
    WidgetRef ref, [
    PosProduct? product,
  ]) async {
    final name = TextEditingController(text: product?.name ?? '');
    final category = TextEditingController(
      text: product?.category ?? 'Minuman',
    );
    final price = TextEditingController(text: product?.price.toString() ?? '');
    final formKey = GlobalKey<FormState>();
    var isActive = product?.isActive ?? true;
    final saved = await showAppModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Form(
          key: formKey,
          child: AppBottomSheetBody(
            children: [
              Text(
                product == null ? 'Tambah Menu' : 'Edit Menu',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nama produk'),
                validator: (value) => (value ?? '').trim().length < 2
                    ? 'Nama produk minimal 2 karakter.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: category,
                decoration: const InputDecoration(labelText: 'Kategori'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Harga'),
                validator: (value) => (int.tryParse(value ?? '') ?? 0) <= 0
                    ? 'Harga harus lebih dari 0.'
                    : null,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: isActive,
                title: const Text('Tersedia di kasir'),
                onChanged: (value) => setModalState(() => isActive = value),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () {
                  if (formKey.currentState?.validate() != true) return;
                  Navigator.of(context).pop(true);
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('Simpan'),
              ),
            ],
          ),
        ),
      ),
    );
    final nameValue = name.text;
    final categoryValue = category.text;
    final priceValue = int.tryParse(price.text) ?? 0;
    name.dispose();
    category.dispose();
    price.dispose();
    if (saved != true || !context.mounted) return;
    try {
      await ref
          .read(posControllerProvider.notifier)
          .saveProduct(
            product: product,
            name: nameValue,
            category: categoryValue,
            price: priceValue,
            isActive: isActive,
          );
      if (context.mounted) showAppSnackBar('Menu berhasil disimpan.');
    } catch (error) {
      if (context.mounted) {
        showAppSnackBar(
          userErrorMessage(error, fallback: 'Menu gagal disimpan.'),
        );
      }
    }
  }
}
