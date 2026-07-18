import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/responsive_page.dart';
import '../domain/user_role.dart';
import 'auth_controller.dart';

class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final config = ref.watch(appConfigProvider);
    final isLoading = auth.isLoading;
    final error = auth.hasError ? auth.error.toString() : null;

    return Scaffold(
      body: SafeArea(
        child: ResponsivePage(
          maxWidth: 520,
          padding: const EdgeInsets.all(20),
          child: Center(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.primaryNavy,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Icon(
                          Icons.local_laundry_service,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Masuk Idola Laundry',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.mainText,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Gunakan akun Supabase Auth. PIN aplikasi hanya untuk quick unlock lokal setelah login utama.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.secondaryText,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (!config.isSupabaseConfigured) ...[
                      _SetupNotice(showPreviewHint: kDebugMode),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) {
                          return 'Email wajib diisi.';
                        }
                        if (!text.contains('@')) {
                          return 'Format email belum valid.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: (value) {
                        if ((value ?? '').isEmpty) {
                          return 'Password wajib diisi.';
                        }
                        return null;
                      },
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        error,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: isLoading ? null : _submit,
                      icon: isLoading
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: const Text('Masuk'),
                    ),
                    if (kDebugMode) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: isLoading
                                  ? null
                                  : () => ref
                                        .read(authControllerProvider.notifier)
                                        .signInPreview(UserRole.owner),
                              icon: const Icon(
                                Icons.admin_panel_settings_outlined,
                              ),
                              label: const Text('Preview Owner'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: isLoading
                                  ? null
                                  : () => ref
                                        .read(authControllerProvider.notifier)
                                        .signInPreview(UserRole.employee),
                              icon: const Icon(Icons.badge_outlined),
                              label: const Text('Preview Karyawan'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    ref
        .read(authControllerProvider.notifier)
        .signInWithEmailPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }
}

class _SetupNotice extends StatelessWidget {
  const _SetupNotice({required this.showPreviewHint});

  final bool showPreviewHint;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.42)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, color: AppColors.warning),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                showPreviewHint
                    ? 'Supabase belum dikonfigurasi. Mode preview debug tersedia untuk cek navigasi tanpa data produksi.'
                    : 'Supabase belum dikonfigurasi. Isi dart-define sebelum login.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.mainText,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
