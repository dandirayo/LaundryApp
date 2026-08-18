import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/responsive_page.dart';
import '../../../shared/preview_data.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/shop_repository.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final data = ref.read(previewDataProvider);
    _nameController = TextEditingController(text: data.shopName);
    _addressController = TextEditingController(text: data.shopAddress);
    _phoneController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOnline());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan Toko')),
      body: ResponsivePage(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: ListView(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nama toko'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Alamat toko'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Nomor telepon'),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loading ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadOnline() async {
    final user = ref.read(authControllerProvider).value?.user;
    final repository = ShopRepository();
    if (!repository.isOnline ||
        user == null ||
        user.shopId.startsWith('preview-shop')) {
      return;
    }
    setState(() => _loading = true);
    try {
      final settings = await repository.fetch(user.shopId);
      if (!mounted) return;
      _nameController.text = settings.name;
      _phoneController.text = settings.phone;
      _addressController.text = settings.address;
    } catch (error) {
      if (mounted) showAppSnackBar('Pengaturan gagal dimuat: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final user = ref.read(authControllerProvider).value?.user;
    final repository = ShopRepository();
    setState(() => _loading = true);
    try {
      if (repository.isOnline &&
          user != null &&
          !user.shopId.startsWith('preview-shop')) {
        await repository.update(
          shopId: user.shopId,
          name: _nameController.text,
          phone: _phoneController.text,
          address: _addressController.text,
        );
      } else {
        ref
            .read(previewDataProvider.notifier)
            .updateShopSettings(
              name: _nameController.text,
              address: _addressController.text,
            );
      }
      if (mounted) showAppSnackBar('Pengaturan toko tersimpan.');
    } catch (error) {
      if (mounted) showAppSnackBar('Pengaturan gagal disimpan: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
