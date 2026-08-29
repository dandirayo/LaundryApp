import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/widgets/responsive_page.dart';
import '../../../core/widgets/app_snack_bar.dart';
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
  bool _isOwnerMode = false;
  String _pin = '';

  List<Map<String, dynamic>> _employees = [];
  Map<String, dynamic>? _selectedEmployee;

  @override
  void initState() {
    super.initState();
    _restoreSavedAccount();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    final supabase = SupabaseService.maybeClient;
    if (supabase == null) return;
    try {
      final response = await supabase.rpc('get_login_employees');
      if (mounted) {
        setState(() {
          _employees = List<Map<String, dynamic>>.from(response as List);
        });
      }
    } catch (e) {
      debugPrint('Failed to load employees: $e');
    }
  }

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onPinKeyTapped(String value) {
    if (_pin.length < 4) {
      setState(() => _pin += value);
      if (_pin.length == 4) {
        _submitPin();
      }
    }
  }

  void _onPinBackspace() {
    if (_pin.isNotEmpty) {
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
    }
  }

  Future<void> _submitPin() async {
    if (_selectedEmployee == null) {
      showAppSnackBar('Silakan pilih nama karyawan terlebih dahulu.');
      setState(() => _pin = '');
      return;
    }

    final username = _selectedEmployee!['username'] as String;
    final email = username.contains('@') ? username : '$username@idola.local';

    ref
        .read(authControllerProvider.notifier)
        .signInWithEmailPassword(email: email, password: _pin);

    // Kosongkan PIN agar siap diketik ulang jika gagal
    setState(() => _pin = '');
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.center,
                          child: Image.asset(
                            'assets/images/idola_one_logo_app.png',
                            width: 150,
                            cacheWidth: 450,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Toggle Peran (Owner / Karyawan)
                        Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.outline.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _RoleTab(
                                  title: 'Owner',
                                  isSelected: _isOwnerMode,
                                  onTap: () =>
                                      setState(() => _isOwnerMode = true),
                                ),
                              ),
                              Expanded(
                                child: _RoleTab(
                                  title: 'Karyawan',
                                  isSelected: !_isOwnerMode,
                                  onTap: () =>
                                      setState(() => _isOwnerMode = false),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        if (!config.isSupabaseConfigured) ...[
                          _SetupNotice(
                            message: kDebugMode
                                ? strings.supabasePreviewNotice
                                : strings.supabaseMissingNotice,
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Area Utama (PIN atau Email)
                        if (!_isOwnerMode)
                          _buildPinSection(strings, error)
                        else
                          _buildOwnerSection(strings, isLoading, error),

                        const SizedBox(height: 24),
                        Align(
                          alignment: Alignment.center,
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
                      ],
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

  Widget _buildPinSection(AppStrings strings, String? error) {
    return Column(
      children: [
        // Dropdown pilih karyawan
        if (_employees.isNotEmpty) ...[
          Container(
            decoration: BoxDecoration(
              color: AppColors.softBlue.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.outline.withValues(alpha: 0.5),
              ),
            ),
            child: DropdownButtonFormField<Map<String, dynamic>>(
              initialValue: _selectedEmployee,
              decoration: InputDecoration(
                labelText: 'Pilih Karyawan',
                labelStyle: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
                prefixIcon: const Icon(
                  Icons.badge_outlined,
                  color: AppColors.gold,
                  size: 22,
                ),
                filled: true,
                fillColor: Colors.transparent,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.primaryBlue,
              ),
              dropdownColor: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              style: const TextStyle(
                color: AppColors.mainText,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              items: _employees.map((emp) {
                return DropdownMenuItem<Map<String, dynamic>>(
                  value: emp,
                  child: Text(emp['name'] as String),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedEmployee = value;
                  _pin = '';
                });
              },
            ),
          ),
          const SizedBox(height: 20),
        ] else if (_employees.isEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryBlue,
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'Memuat daftar karyawan...',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],

        // Label "Masukkan PIN"
        const Text(
          'MASUKKAN PIN',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.secondaryText,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 14),

        // PIN dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            final isFilled = index < _pin.length;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              width: isFilled ? 16 : 14,
              height: isFilled ? 16 : 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isFilled ? AppColors.gold : Colors.transparent,
                border: Border.all(
                  color: isFilled ? AppColors.gold : AppColors.outline,
                  width: 2.5,
                ),
                boxShadow: isFilled
                    ? [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
            );
          }),
        ),

        // Error message
        if (error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 16,
                  color: AppColors.error,
                ),
                const SizedBox(width: 6),
                Text(
                  error.contains('Invalid login credentials')
                      ? 'PIN salah. Coba lagi.'
                      : error,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),
        _buildNumpad(),
      ],
    );
  }

  Widget _buildNumpad() {
    return Column(
      children: [
        for (var i = 0; i < 3; i++)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var j = 1; j <= 3; j++)
                _NumpadButton(
                  text: '${i * 3 + j}',
                  onTap: () => _onPinKeyTapped('${i * 3 + j}'),
                ),
            ],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 64, height: 64), // Empty space
            _NumpadButton(text: '0', onTap: () => _onPinKeyTapped('0')),
            _NumpadButton(
              icon: Icons.backspace_outlined,
              onTap: _onPinBackspace,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOwnerSection(AppStrings strings, bool isLoading, String? error) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
              if (text.isEmpty) return 'Username atau email wajib diisi.';
              return null;
            },
          ),
          const SizedBox(height: 16),
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
              if ((value ?? '').isEmpty) return strings.passwordRequired;
              return null;
            },
          ),
          const SizedBox(height: 8),
          Material(
            color: Colors.transparent,
            child: CheckboxListTile(
              value: _rememberAccount,
              onChanged: isLoading
                  ? null
                  : (value) =>
                        setState(() => _rememberAccount = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text('Simpan akun'),
              subtitle: const Text(
                'Username & password tersimpan untuk otomatis.',
              ),
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
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: isLoading ? null : _submit,
            icon: isLoading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.login),
            label: Text(strings.signIn),
          ),
        ],
      ),
    );
  }

  Future<void> _restoreSavedAccount() async {
    final storage = ref.read(secureStorageProvider);
    final remember = await storage.read(key: _rememberAccountKey);
    if (!mounted || remember != 'true') return;

    _loginController.text = await storage.read(key: _savedLoginKey) ?? '';
    _passwordController.text = await storage.read(key: _savedPasswordKey) ?? '';
    if (!mounted) return;

    setState(() {
      _rememberAccount = true;
      _isOwnerMode =
          true; // Auto-switch to owner if they have saved credentials
    });

    if (!_autoLoginAttempted &&
        _loginController.text.trim().isNotEmpty &&
        _passwordController.text.isNotEmpty) {
      _autoLoginAttempted = true;
      // Fitur auto-login dimatikan sementara sesuai permintaan
      // await Future<void>.delayed(const Duration(milliseconds: 250));
      // if (mounted) await _submit();
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
    if (!_formKey.currentState!.validate()) return;
    await _saveAccountPreference();
    if (!mounted) return;

    String loginEmail = _loginController.text.trim();
    if (!loginEmail.contains('@')) {
      loginEmail = '$loginEmail@idola.local';
    }

    ref
        .read(authControllerProvider.notifier)
        .signInWithEmailPassword(
          email: loginEmail,
          password: _passwordController.text,
        );
  }
}

class _RoleTab extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleTab({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryNavy : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primaryNavy.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.secondaryText,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

class _NumpadButton extends StatelessWidget {
  final String? text;
  final IconData? icon;
  final VoidCallback onTap;

  const _NumpadButton({this.text, this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        splashColor: AppColors.gold.withValues(alpha: 0.1),
        highlightColor: AppColors.gold.withValues(alpha: 0.05),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface,
            border: Border.all(
              color: AppColors.outline.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.mainText.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: icon != null
              ? Icon(icon, size: 24, color: AppColors.secondaryText)
              : Text(
                  text!,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mainText,
                  ),
                ),
        ),
      ),
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
