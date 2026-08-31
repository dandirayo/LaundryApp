import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/extensions/date_time_extensions.dart';
import '../../../core/widgets/app_bottom_sheet_body.dart';
import '../domain/request_kind.dart';

class RequestFormSheet extends StatefulWidget {
  const RequestFormSheet({this.initialType, super.key});

  final String? initialType;

  @override
  State<RequestFormSheet> createState() => _RequestFormSheetState();
}

class _RequestFormSheetState extends State<RequestFormSheet> {
  var _formKey = GlobalKey<FormState>();
  final _item = TextEditingController();
  final _unit = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _amount = TextEditingController();
  final _purpose = TextEditingController();
  final _note = TextEditingController();
  final _originalShift = TextEditingController();
  final _replacementShift = TextEditingController();
  final _colleague = TextEditingController();
  late RequestKind _kind;
  String? _leaveType;
  String? _expenseType;
  DateTime? _startDate;
  DateTime? _endDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _endsNextDay = false;

  @override
  void initState() {
    super.initState();
    _kind = RequestKind.fromStorage(widget.initialType) ?? RequestKind.stock;
  }

  @override
  void dispose() {
    for (final controller in [
      _item,
      _unit,
      _quantity,
      _amount,
      _purpose,
      _note,
      _originalShift,
      _replacementShift,
      _colleague,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _selectKind(RequestKind kind) {
    if (kind == _kind) return;
    setState(() {
      _kind = kind;
      _formKey = GlobalKey<FormState>();
      // Do not silently carry private notes, money or dates into another type.
      for (final controller in [
        _item,
        _unit,
        _amount,
        _purpose,
        _note,
        _originalShift,
        _replacementShift,
        _colleague,
      ]) {
        controller.clear();
      }
      _quantity.text = '1';
      _leaveType = null;
      _expenseType = null;
      _startDate = null;
      _endDate = null;
      _startTime = null;
      _endTime = null;
      _endsNextDay = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheetBody(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Buat Pengajuan',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 8),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('Pilih kebutuhan, lalu isi detailnya untuk Owner.'),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<RequestCategory>(
          key: ValueKey(_kind.category),
          initialValue: _kind.category,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Kategori pengajuan'),
          items: [
            for (final category in RequestCategory.values)
              DropdownMenuItem(value: category, child: Text(category.label)),
          ],
          onChanged: (category) {
            if (category == null) return;
            _selectKind(switch (category) {
              RequestCategory.stock => RequestKind.stock,
              RequestCategory.schedule => RequestKind.leave,
              RequestCategory.funds => RequestKind.cashAdvance,
            });
          },
        ),
        if (_kind.category == RequestCategory.funds) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final kind in [RequestKind.cashAdvance, RequestKind.expense])
                ChoiceChip(
                  label: Text(kind.label),
                  selected: _kind == kind,
                  onSelected: (_) => _selectKind(kind),
                ),
            ],
          ),
        ],
        if (_kind.category == RequestCategory.schedule) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: ChoiceChip(
              label: const Text('Izin'),
              selected: _kind == RequestKind.leave,
              onSelected: (_) => _selectKind(RequestKind.leave),
            ),
          ),
          ExpansionTile(
            key: const ValueKey('schedule-options'),
            tilePadding: EdgeInsets.zero,
            initiallyExpanded: _kind != RequestKind.leave,
            title: Text(
              _kind == RequestKind.leave
                  ? 'Pilihan jadwal lainnya'
                  : 'Pilihan jadwal: ${_kind.label}',
            ),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final kind in [
                    RequestKind.shiftSwap,
                    RequestKind.overtime,
                  ])
                    ChoiceChip(
                      label: Text(kind.label),
                      selected: _kind == kind,
                      onSelected: (_) => _selectKind(kind),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ],
        const SizedBox(height: 16),
        // Remount validation state when the request type changes.
        KeyedSubtree(
          key: ValueKey(_kind),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ..._detailFields(),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _note,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Catatan tambahan (opsional)',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('Kirim ke Owner'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _detailFields() {
    final fields = switch (_kind) {
      RequestKind.stock => [
        _textField(_item, 'Nama barang', hint: 'Contoh: Deterjen cair'),
        _numberField(_quantity, 'Jumlah'),
        _textField(_unit, 'Satuan', hint: 'Contoh: liter, botol, atau bungkus'),
      ],
      RequestKind.leave => [
        _selectionField(
          label: 'Jenis izin',
          value: _leaveType,
          options: const ['Sakit', 'Cuti', 'Keperluan pribadi', 'Lainnya'],
          onChanged: (value) => setState(() => _leaveType = value),
        ),
        _dateField('Tanggal mulai', isEnd: false),
        _dateField('Tanggal selesai', isEnd: true),
        const Text(
          'Tidak perlu menuliskan detail pribadi atau kondisi kesehatan.',
        ),
      ],
      RequestKind.shiftSwap => [
        _dateField('Tanggal tukar shift', isEnd: false),
        _textField(_originalShift, 'Shift asal', hint: 'Contoh: 06.00–14.00'),
        _textField(
          _replacementShift,
          'Shift tujuan',
          hint: 'Contoh: 12.00–20.00',
        ),
        _textField(_colleague, 'Rekan pengganti'),
      ],
      RequestKind.overtime => [
        _dateField('Tanggal lembur', isEnd: false),
        _timeField('Jam mulai', isEnd: false),
        _timeField('Jam selesai', isEnd: true),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Selesai pada hari berikutnya'),
          value: _endsNextDay,
          onChanged: (value) => setState(() => _endsNextDay = value),
        ),
        _textField(_purpose, 'Pekerjaan yang diselesaikan', maxLines: 2),
      ],
      RequestKind.cashAdvance => [
        _numberField(_amount, 'Nominal (Rp)'),
        const Text(
          'Alasan pribadi tidak wajib diisi. Pengembalian mengikuti kesepakatan dengan Owner.',
        ),
      ],
      RequestKind.expense => [
        _selectionField(
          label: 'Jenis biaya',
          value: _expenseType,
          options: const ['Dana operasional', 'Reimbursement (sudah dibayar)'],
          onChanged: (value) => setState(() => _expenseType = value),
        ),
        _numberField(_amount, 'Nominal (Rp)'),
        _textField(
          _purpose,
          'Tujuan penggunaan',
          maxLines: 2,
          hint: 'Contoh: Membeli plastik kemasan',
        ),
        const Text(
          'Gunakan pengajuan untuk biaya yang perlu persetujuan. Jangan ajukan ulang biaya yang sudah dicatat atau diganti.',
        ),
      ],
    };
    return [
      for (var i = 0; i < fields.length; i++) ...[
        if (i > 0) const SizedBox(height: 12),
        fields[i],
      ],
    ];
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    String? hint,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, hintText: hint),
      validator: (value) =>
          (value ?? '').trim().isEmpty ? '$label wajib diisi.' : null,
    );
  }

  Widget _numberField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        final number = int.tryParse(value ?? '');
        if (number == null || number <= 0) {
          return '$label harus lebih dari nol.';
        }
        if (number > 2147483647) return '$label terlalu besar.';
        return null;
      },
    );
  }

  Widget _selectionField({
    required String label,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final option in options)
          DropdownMenuItem(value: option, child: Text(option)),
      ],
      onChanged: onChanged,
      validator: (value) => value == null ? '$label wajib dipilih.' : null,
    );
  }

  Widget _dateField(String label, {required bool isEnd}) {
    final date = isEnd ? _endDate : _startDate;
    return FormField<DateTime>(
      key: ValueKey('date-$isEnd-$date'),
      initialValue: date,
      validator: (value) {
        if (value == null) return '$label wajib dipilih.';
        if (isEnd && _startDate != null && value.isBefore(_startDate!)) {
          return 'Tanggal selesai tidak boleh sebelum tanggal mulai.';
        }
        return null;
      },
      builder: (field) => InkWell(
        onTap: () async {
          final now = DateUtils.dateOnly(DateTime.now());
          final picked = await showDatePicker(
            context: context,
            initialDate: date ?? (isEnd ? _startDate : null) ?? now,
            firstDate: DateTime(now.year - 1),
            lastDate: DateTime(now.year + 2, 12, 31),
          );
          if (picked == null || !mounted) return;
          setState(() {
            if (isEnd) {
              _endDate = picked;
            } else {
              _startDate = picked;
              if (_endDate != null && _endDate!.isBefore(picked)) {
                _endDate = null;
              }
            }
          });
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            errorText: field.errorText,
            suffixIcon: const Icon(Icons.calendar_today_outlined),
          ),
          child: Text(date?.toIndonesianDate() ?? 'Pilih tanggal'),
        ),
      ),
    );
  }

  Widget _timeField(String label, {required bool isEnd}) {
    final time = isEnd ? _endTime : _startTime;
    return FormField<TimeOfDay>(
      key: ValueKey('time-$isEnd-$time-$_startTime-$_endsNextDay'),
      initialValue: time,
      validator: (value) {
        if (value == null) return '$label wajib dipilih.';
        if (isEnd && _startTime != null) {
          final duration = _durationMinutes;
          if (duration <= 0 || duration > 24 * 60) {
            return 'Durasi lembur harus lebih dari 0 dan maksimal 24 jam.';
          }
        }
        return null;
      },
      builder: (field) => InkWell(
        onTap: () async {
          final picked = await showTimePicker(
            context: context,
            initialTime: time ?? const TimeOfDay(hour: 17, minute: 0),
          );
          if (picked == null || !mounted) return;
          setState(() {
            if (isEnd) {
              _endTime = picked;
            } else {
              _startTime = picked;
            }
          });
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            errorText: field.errorText,
            suffixIcon: const Icon(Icons.schedule),
          ),
          child: Text(time == null ? 'Pilih jam' : _formatTime(time)),
        ),
      ),
    );
  }

  int get _durationMinutes =>
      _endTime!.hour * 60 +
      _endTime!.minute +
      (_endsNextDay ? 1440 : 0) -
      _startTime!.hour * 60 -
      _startTime!.minute;

  String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}.${time.minute.toString().padLeft(2, '0')}';

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final details = switch (_kind) {
      RequestKind.stock => [
        'Barang: ${_item.text.trim()}',
        'Jumlah: ${int.parse(_quantity.text)} ${_unit.text.trim()}',
      ],
      RequestKind.leave => [
        'Jenis izin: $_leaveType',
        'Tanggal: ${_startDate!.toIndonesianDate()} – ${_endDate!.toIndonesianDate()}',
      ],
      RequestKind.shiftSwap => [
        'Tanggal: ${_startDate!.toIndonesianDate()}',
        'Shift asal: ${_originalShift.text.trim()}',
        'Shift tujuan: ${_replacementShift.text.trim()}',
        'Rekan pengganti: ${_colleague.text.trim()}',
      ],
      RequestKind.overtime => [
        'Tanggal: ${_startDate!.toIndonesianDate()}',
        'Jam: ${_formatTime(_startTime!)} – ${_formatTime(_endTime!)}${_endsNextDay ? ' (hari berikutnya)' : ''}',
        'Durasi: $_durationMinutes menit',
        'Pekerjaan: ${_purpose.text.trim()}',
      ],
      RequestKind.cashAdvance => ['Pengajuan kasbon'],
      RequestKind.expense => [
        'Jenis biaya: $_expenseType',
        'Tujuan: ${_purpose.text.trim()}',
      ],
    };
    Navigator.of(context).pop(
      RequestSubmission(
        kind: _kind,
        summary: [
          ...details,
          if (_note.text.trim().isNotEmpty) 'Catatan: ${_note.text.trim()}',
        ].join('\n'),
        amount: _kind.needsMoney
            ? int.parse(_amount.text)
            : _kind == RequestKind.stock
            ? int.parse(_quantity.text)
            : 0,
      ),
    );
  }
}
