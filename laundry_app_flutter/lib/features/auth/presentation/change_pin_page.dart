import 'package:flutter/material.dart';

import '../../../core/widgets/responsive_page.dart';

class ChangePinPage extends StatefulWidget {
  const ChangePinPage({super.key});

  @override
  State<ChangePinPage> createState() => _ChangePinPageState();
}

class _ChangePinPageState extends State<ChangePinPage> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ganti PIN')),
      body: ResponsivePage(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Card(
                child: ListTile(
                  leading: Icon(Icons.lock_outline),
                  title: Text('PIN quick unlock lokal'),
                  subtitle: Text(
                    'PIN bukan pengganti Supabase Auth dan tidak dipakai sebagai identitas user.',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'PIN baru'),
                validator: (value) {
                  final text = value ?? '';
                  if (text.length < 4 || text.length > 6) {
                    return 'PIN harus 4 sampai 6 digit.';
                  }
                  if (int.tryParse(text) == null) {
                    return 'PIN hanya boleh angka.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmController,
                keyboardType: TextInputType.number,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Ulangi PIN'),
                validator: (value) =>
                    value != _pinController.text ? 'PIN belum sama.' : null,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  if (!_formKey.currentState!.validate()) {
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('PIN preview tersimpan untuk sesi lokal.'),
                    ),
                  );
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('Simpan PIN'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
