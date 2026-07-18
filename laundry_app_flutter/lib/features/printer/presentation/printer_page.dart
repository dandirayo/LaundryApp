import 'package:flutter/material.dart';

import '../../../core/widgets/responsive_page.dart';

class PrinterPage extends StatelessWidget {
  const PrinterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Printer')),
      body: ResponsivePage(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: ListView(
          children: [
            const Card(
              child: ListTile(
                leading: Icon(Icons.print_outlined),
                title: Text('Printer thermal belum dipilih'),
                subtitle: Text(
                  'Aplikasi tetap bisa preview struk, simpan PDF, dan share ringkasan.',
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Test koneksi printer akan aktif saat plugin Bluetooth dipasang.',
                  ),
                ),
              ),
              icon: const Icon(Icons.bluetooth_searching),
              label: const Text('Test Koneksi'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Preview struk siap dari detail pesanan.'),
                ),
              ),
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Preview Struk'),
            ),
          ],
        ),
      ),
    );
  }
}
