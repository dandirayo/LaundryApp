import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/extensions/currency_extensions.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/responsive_page.dart';
import '../../auth/presentation/auth_controller.dart';

class ProjectsPage extends ConsumerStatefulWidget {
  const ProjectsPage({super.key});

  @override
  ConsumerState<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends ConsumerState<ProjectsPage> {
  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _batches = [];
  List<Map<String, dynamic>> _payments = [];
  List<Map<String, dynamic>> _customers = [];
  RealtimeChannel? _channel;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    final channel = _channel;
    final client = SupabaseService.maybeClient;
    if (channel != null && client != null) {
      unawaited(client.removeChannel(channel).then((_) {}));
    }
    super.dispose();
  }

  Future<void> _refresh() async {
    final user = ref.read(authControllerProvider).value?.user;
    final client = SupabaseService.maybeClient;
    if (user == null || client == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Proyek membutuhkan koneksi Supabase.';
        });
      }
      return;
    }
    try {
      final results = await Future.wait([
        client
            .from('laundry_projects')
            .select()
            .eq('shop_id', user.shopId)
            .order('created_at', ascending: false),
        client
            .from('laundry_project_batches')
            .select()
            .eq('shop_id', user.shopId)
            .order('processed_at', ascending: false),
        client
            .from('laundry_project_payments')
            .select()
            .eq('shop_id', user.shopId)
            .order('created_at', ascending: false),
        client
            .from('customers')
            .select('id,name')
            .eq('shop_id', user.shopId)
            .isFilter('deleted_at', null)
            .order('name'),
      ]);
      if (!mounted) return;
      setState(() {
        _projects = results[0];
        _batches = results[1];
        _payments = results[2];
        _customers = results[3];
        _loading = false;
        _error = null;
      });
      _subscribe(user.shopId);
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Data proyek belum dapat dimuat: $error';
        });
      }
    }
  }

  void _subscribe(String shopId) {
    if (_channel != null) return;
    final client = SupabaseService.maybeClient!;
    _channel = client
        .channel('laundry-projects:$shopId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'laundry_projects',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'shop_id',
            value: shopId,
          ),
          callback: (_) => _refresh(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'laundry_project_batches',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'shop_id',
            value: shopId,
          ),
          callback: (_) => _refresh(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'laundry_project_payments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'shop_id',
            value: shopId,
          ),
          callback: (_) => _refresh(),
        )
        .subscribe();
  }

  int _number(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  double _decimal(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).value?.user;
    final isOwner = user?.isOwner == true;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Proyek Laundry'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Perbarui proyek',
          ),
        ],
      ),
      floatingActionButton: isOwner
          ? FloatingActionButton.extended(
              onPressed: () => _editProject(),
              icon: const Icon(Icons.add),
              label: const Text('Proyek'),
            )
          : null,
      body: ResponsivePage(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(child: Text(_error!, textAlign: TextAlign.center))
            : _projects.isEmpty
            ? const Center(child: Text('Belum ada proyek laundry.'))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                itemCount: _projects.length,
                itemBuilder: (context, index) =>
                    _projectCard(_projects[index], isOwner),
              ),
      ),
    );
  }

  Widget _projectCard(Map<String, dynamic> project, bool isOwner) {
    final id = project['id'] as String;
    final batches = _batches.where((row) => row['project_id'] == id).toList();
    final payments = _payments.where((row) => row['project_id'] == id).toList();
    final pieces = batches.fold<int>(
      0,
      (sum, row) => sum + _number(row['pieces']),
    );
    final kg = batches.fold<double>(
      0,
      (sum, row) => sum + _decimal(row['weight_kg']),
    );
    final subtotal = project['pricing_unit'] == 'KG'
        ? (kg * _number(project['unit_price'])).round()
        : pieces * _number(project['unit_price']);
    final billed = subtotal == 0 ? 0 : ((subtotal + 999) ~/ 1000) * 1000;
    final paid = payments.fold<int>(
      0,
      (sum, row) => sum + _number(row['amount']),
    );
    final target = _number(project['target_pieces']);
    final customer = _customers
        .where((row) => row['id'] == project['customer_id'])
        .firstOrNull;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text('${project['title']}'),
        subtitle: Text(
          '${customer?['name'] ?? 'Pelanggan'} • $pieces/$target pcs • ${kg.toStringAsFixed(2)} kg',
        ),
        trailing: Text(
          '${(target == 0 ? 0 : pieces / target * 100).clamp(0, 100).toStringAsFixed(0)}%',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          LinearProgressIndicator(
            value: target == 0 ? 0 : (pieces / target).clamp(0, 1),
          ),
          const SizedBox(height: 12),
          Text(
            'Tarif ${_number(project['unit_price']).toRupiah()} / ${project['pricing_unit'] == 'KG' ? 'kg' : 'pcs'}',
          ),
          Text(
            'Tagihan berjalan ${billed.toRupiah()} • Dibayar ${paid.toRupiah()}',
          ),
          Text(
            'Sisa ${((billed - paid).clamp(0, 1 << 31)).toRupiah()} • Status ${project['status']}',
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: project['status'] == 'cancelled'
                    ? null
                    : () => _editBatch(project),
                icon: const Icon(Icons.scale),
                label: const Text('Catat batch'),
              ),
              OutlinedButton.icon(
                onPressed: project['status'] == 'cancelled'
                    ? null
                    : () => _editPayment(project),
                icon: const Icon(Icons.payments),
                label: const Text('Catat pembayaran'),
              ),
              if (isOwner)
                TextButton.icon(
                  onPressed: () => _editProject(project),
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit proyek'),
                ),
            ],
          ),
          const Divider(),
          for (final row in batches)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${row['pieces']} pcs • ${row['weight_kg']} kg'),
              subtitle: Text(
                '${row['note'] ?? ''} • ${DateTime.tryParse('${row['processed_at']}')?.toLocal().toString().substring(0, 16) ?? ''}',
              ),
              trailing: isOwner
                  ? IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Edit batch',
                      onPressed: () => _editBatch(project, row),
                    )
                  : null,
            ),
          for (final row in payments)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${_number(row['amount']).toRupiah()} • ${row['method']}',
              ),
              subtitle: Text(
                'Pembayaran ${DateTime.tryParse('${row['created_at']}')?.toLocal().toString().substring(0, 16) ?? ''}',
              ),
              trailing: isOwner
                  ? IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Koreksi pembayaran',
                      onPressed: () => _editPayment(project, row),
                    )
                  : null,
            ),
        ],
      ),
    );
  }

  Future<void> _editProject([Map<String, dynamic>? current]) async {
    final user = ref.read(authControllerProvider).value?.user;
    if (user == null || !user.isOwner) return;
    final title = TextEditingController(text: '${current?['title'] ?? ''}');
    final target = TextEditingController(
      text: '${current?['target_pieces'] ?? ''}',
    );
    final rate = TextEditingController(text: '${current?['unit_price'] ?? ''}');
    final note = TextEditingController(text: '${current?['note'] ?? ''}');
    String? customerId =
        current?['customer_id'] as String? ??
        _customers.firstOrNull?['id'] as String?;
    String unit = '${current?['pricing_unit'] ?? 'KG'}';
    String status = '${current?['status'] ?? 'active'}';
    final save = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, refresh) => AlertDialog(
          title: Text(current == null ? 'Proyek baru' : 'Edit proyek'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: customerId,
                    decoration: const InputDecoration(labelText: 'Pelanggan'),
                    items: [
                      for (final c in _customers)
                        DropdownMenuItem(
                          value: c['id'] as String,
                          child: Text('${c['name']}'),
                        ),
                    ],
                    onChanged: current == null
                        ? (value) => refresh(() => customerId = value)
                        : null,
                  ),
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Nama proyek'),
                  ),
                  TextField(
                    controller: target,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Target pcs'),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: unit,
                    decoration: const InputDecoration(labelText: 'Dasar harga'),
                    items: const [
                      DropdownMenuItem(value: 'KG', child: Text('Per kg')),
                      DropdownMenuItem(value: 'PIECE', child: Text('Per pcs')),
                    ],
                    onChanged: (value) => refresh(() => unit = value ?? 'KG'),
                  ),
                  TextField(
                    controller: rate,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Harga per satuan (Rp)',
                    ),
                  ),
                  TextField(
                    controller: note,
                    decoration: const InputDecoration(labelText: 'Catatan'),
                  ),
                  if (current != null)
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: const [
                        DropdownMenuItem(value: 'active', child: Text('Aktif')),
                        DropdownMenuItem(
                          value: 'completed',
                          child: Text('Selesai'),
                        ),
                        DropdownMenuItem(
                          value: 'cancelled',
                          child: Text('Dibatalkan'),
                        ),
                      ],
                      onChanged: (value) =>
                          refresh(() => status = value ?? 'active'),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    if (save != true || customerId == null) return;
    final targetValue = int.tryParse(target.text);
    final rateValue = int.tryParse(rate.text);
    if (title.text.trim().isEmpty ||
        targetValue == null ||
        targetValue <= 0 ||
        rateValue == null ||
        rateValue < 0) {
      _notice('Isi nama, target pcs, dan harga yang valid.');
      return;
    }
    try {
      final values = {
        'title': title.text.trim(),
        'target_pieces': targetValue,
        'pricing_unit': unit,
        'unit_price': rateValue,
        'note': note.text.trim(),
        'status': status,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (current == null) {
        await SupabaseService.maybeClient!.from('laundry_projects').insert({
          ...values,
          'shop_id': user.shopId,
          'customer_id': customerId,
          'created_by': user.userId,
        });
      } else {
        await SupabaseService.maybeClient!
            .from('laundry_projects')
            .update(values)
            .eq('id', current['id'])
            .eq('shop_id', user.shopId);
      }
      await _refresh();
    } catch (error) {
      _notice('Proyek belum tersimpan: $error');
    }
  }

  Future<void> _editBatch(
    Map<String, dynamic> project, [
    Map<String, dynamic>? current,
  ]) async {
    final user = ref.read(authControllerProvider).value?.user;
    if (user == null) return;
    final pieces = TextEditingController(text: '${current?['pieces'] ?? ''}');
    final kg = TextEditingController(text: '${current?['weight_kg'] ?? ''}');
    final note = TextEditingController(text: '${current?['note'] ?? ''}');
    final save = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(current == null ? 'Catat batch harian' : 'Edit batch'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: pieces,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Jumlah pcs'),
              ),
              TextField(
                controller: kg,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Berat aktual (kg)',
                ),
              ),
              TextField(
                controller: note,
                decoration: const InputDecoration(
                  labelText: 'Catatan pekerjaan',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (save != true) return;
    final count = int.tryParse(pieces.text);
    final weight = double.tryParse(kg.text.replaceAll(',', '.'));
    if (count == null || count <= 0 || weight == null || weight <= 0) {
      _notice('Jumlah pcs dan kg harus lebih dari nol.');
      return;
    }
    try {
      final values = {
        'pieces': count,
        'weight_kg': weight,
        'note': note.text.trim(),
      };
      if (current == null) {
        await SupabaseService.maybeClient!
            .from('laundry_project_batches')
            .insert({
              ...values,
              'shop_id': user.shopId,
              'project_id': project['id'],
              'employee_id': user.employeeId,
            });
      } else {
        await SupabaseService.maybeClient!
            .from('laundry_project_batches')
            .update(values)
            .eq('id', current['id'])
            .eq('shop_id', user.shopId);
      }
      await _refresh();
    } catch (error) {
      _notice('Batch belum tersimpan: $error');
    }
  }

  Future<void> _editPayment(
    Map<String, dynamic> project, [
    Map<String, dynamic>? current,
  ]) async {
    final user = ref.read(authControllerProvider).value?.user;
    if (user == null) return;
    final amount = TextEditingController(text: '${current?['amount'] ?? ''}');
    String method = '${current?['method'] ?? 'Tunai'}';
    final save = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, refresh) => AlertDialog(
          title: Text(
            current == null ? 'Pembayaran proyek' : 'Koreksi pembayaran',
          ),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Nominal diterima (Rp)',
                  ),
                ),
                DropdownButtonFormField<String>(
                  initialValue: method,
                  decoration: const InputDecoration(labelText: 'Metode'),
                  items: const [
                    DropdownMenuItem(value: 'Tunai', child: Text('Tunai')),
                    DropdownMenuItem(
                      value: 'Transfer',
                      child: Text('Transfer'),
                    ),
                    DropdownMenuItem(value: 'QRIS', child: Text('QRIS')),
                  ],
                  onChanged: (value) =>
                      refresh(() => method = value ?? 'Tunai'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    if (save != true) return;
    final value = int.tryParse(amount.text);
    if (value == null || value <= 0) {
      _notice('Nominal harus lebih dari nol.');
      return;
    }
    try {
      if (current == null) {
        await SupabaseService.maybeClient!
            .from('laundry_project_payments')
            .insert({
              'shop_id': user.shopId,
              'project_id': project['id'],
              'amount': value,
              'method': method,
              'created_by': user.userId,
            });
      } else {
        await SupabaseService.maybeClient!
            .from('laundry_project_payments')
            .update({'amount': value, 'method': method})
            .eq('id', current['id'])
            .eq('shop_id', user.shopId);
      }
      await _refresh();
    } catch (error) {
      _notice('Pembayaran belum tersimpan: $error');
    }
  }

  void _notice(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }
}
