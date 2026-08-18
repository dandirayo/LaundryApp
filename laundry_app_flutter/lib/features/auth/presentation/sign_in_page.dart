import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/widgets/responsive_page.dart';
import 'auth_controller.dart';

class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  static const _savedLoginKey = 'saved_login';
  static const _savedPasswordKey = 'saved_password';
  static const _rememberAccountKey = 'remember_account';

  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _rememberAccount = false;
  bool _autoLoginAttempted = false;

  @override
  void initState() {
    super.initState();
    _restoreSavedAccount();
  }

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final config = ref.watch(appConfigProvider);
    final language = ref.watch(appLanguageProvider);
    final strings = AppStrings(language);
    final isLoading = auth.isLoading;
    final error = auth.hasError ? auth.error.toString() : null;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppGradients.softBackground),
        child: SafeArea(
          child: ResponsivePage(
            maxWidth: 520,
            padding: const EdgeInsets.all(20),
            child: Center(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: AppColors.primaryBlue.withValues(alpha: 0.08),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryNavy.withValues(alpha: 0.1),
                          blurRadius: 34,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.center,
                            child: Image.asset(
                              'assets/images/idola_one_logo_app.png',
                              width: 240,
                              cacheWidth: 640,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 22),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: SegmentedButton<AppLanguage>(
                              segments: [
                                for (final item in AppLanguage.values)
                                  ButtonSegment(
                                    value: item,
                                    label: Text(item.label),
                                  ),
                              ],
                              selected: {language},
                              onSelectionChanged: (value) => ref
                                  .read(appLanguageProvider.notifier)
                                  .setLanguage(value.first),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            strings.signInTitle,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primaryNavy,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            strings.signInDescription,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppColors.primaryBlue,
                                  height: 1.4,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 24),
                          if (!config.isSupabaseConfigured) ...[
                            _SetupNotice(
                              message: kDebugMode
                                  ? strings.supabasePreviewNotice
                                  : strings.supabaseMissingNotice,
                            ),
                            const SizedBox(height: 16),
                          ],
                          TextFormField(
                            controller: _loginController,
                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Username atau email',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if (text.isEmpty) {
                                return 'Username atau email wajib diisi.';
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
                                return strings.passwordRequired;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          CheckboxListTile(
                            value: _rememberAccount,
                            onChanged: isLoading
                                ? null
                                : (value) => setState(
                                    () => _rememberAccount = value ?? false,
                                  ),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Simpan akun'),
                            subtitle: const Text(
                              'Username dan password tersimpan untuk login otomatis di HP ini.',
                            ),
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
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.login),
                            label: Text(strings.signIn),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _restoreSavedAccount() async {
    final storage = ref.read(secureStorageProvider);
    final remember = await storage.read(key: _rememberAccountKey);
    if (!mounted || remember != 'true') {
      return;
    }
    _loginController.text = await storage.read(key: _savedLoginKey) ?? '';
    _passwordController.text = await storage.read(key: _savedPasswordKey) ?? '';
    if (!mounted) {
      return;
    }
    setState(() => _rememberAccount = true);
    if (!_autoLoginAttempted &&
        _loginController.text.trim().isNotEmpty &&
        _passwordController.text.isNotEmpty) {
      _autoLoginAttempted = true;
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (mounted) {
        await _submit();
      }
    }
  }

  Future<void> _saveAccountPreference() async {
    final storage = ref.read(secureStorageProvider);
    if (_rememberAccount) {
      await storage.write(key: _rememberAccountKey, value: 'true');
      await storage.write(
        key: _savedLoginKey,
        value: _loginController.text.trim(),
      );
      await storage.write(
        key: _savedPasswordKey,
        value: _passwordController.text,
      );
      return;
    }

    await storage.delete(key: _rememberAccountKey);
    await storage.delete(key: _savedLoginKey);
    await storage.delete(key: _savedPasswordKey);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    await _saveAccountPreference();
    if (!mounted) {
      return;
    }
    ref
        .read(authControllerProvider.notifier)
        .signInWithEmailPassword(
          email: _loginController.text.trim(),
          password: _passwordController.text,
        );
  }
}

class _SetupNotice extends StatelessWidget {
  const _SetupNotice({required this.message});

  final String message;

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
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.primaryNavy,
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
