import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:laundry_app_flutter/core/theme/app_theme.dart';
import 'package:laundry_app_flutter/core/widgets/app_snack_bar.dart';
import 'package:laundry_app_flutter/features/auth/domain/app_user.dart';
import 'package:laundry_app_flutter/features/auth/domain/user_role.dart';
import 'package:laundry_app_flutter/features/auth/presentation/auth_controller.dart';
import 'package:laundry_app_flutter/features/employee_requests/domain/request_kind.dart';
import 'package:laundry_app_flutter/features/employee_requests/presentation/employee_request_controller.dart';
import 'package:laundry_app_flutter/features/employee_requests/presentation/request_form_sheet.dart';
import 'package:laundry_app_flutter/features/employee_requests/presentation/request_page.dart';
import 'package:laundry_app_flutter/features/employee_requests/presentation/request_review_page.dart';
import 'package:laundry_app_flutter/shared/preview_data.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets(
    'kirim dari halaman menyimpan detail dan menampilkan kategori baru',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(_EmployeeAuthController.new),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            scaffoldMessengerKey: appScaffoldMessengerKey,
            home: const RequestPage(initialType: 'Request Stok'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _tapText(tester, 'Buat Pengajuan');
      final category = find.descendant(
        of: find.byType(RequestFormSheet),
        matching: find.byWidgetPredicate(
          (widget) => widget is DropdownButtonFormField<RequestCategory>,
        ),
      );
      await tester.ensureVisible(category);
      await tester.tap(category);
      await tester.pumpAndSettle();
      await _tapText(tester, 'Dana & Biaya');
      await _enter(tester, 'Nominal (Rp)', '75000');
      await _submit(tester);
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (container.read(previewDataProvider).requests.isNotEmpty) break;
      }
      await tester.pumpAndSettle();
      final request = container.read(previewDataProvider).requests.single;
      expect(request.type, 'Request Kasbon');
      expect(request.amount, 75000);
      expect(request.reason, 'Pengajuan kasbon');
      expect(request.employeeId, 'employee-1');
      expect(request.status, PreviewRequestStatus.pending);
      expect(find.text('Kasbon'), findsOneWidget);
      expect(find.text('Pengajuan dikirim ke Owner.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('stok membutuhkan barang, jumlah, satuan tetapi bukan catatan', (
    tester,
  ) async {
    RequestSubmission? result;
    await _openForm(tester, onSubmit: (value) => result = value);
    await _submit(tester);
    expect(result, isNull);
    expect(find.text('Nama barang wajib diisi.'), findsOneWidget);
    expect(find.text('Satuan wajib diisi.'), findsOneWidget);

    await _enter(tester, 'Nama barang', 'Deterjen cair');
    await _enter(tester, 'Jumlah', '0');
    await _enter(tester, 'Satuan', 'liter');
    await _submit(tester);
    expect(find.text('Jumlah harus lebih dari nol.'), findsOneWidget);
    await _enter(tester, 'Jumlah', '5');
    await _submit(tester);

    expect(result?.kind, RequestKind.stock);
    expect(result?.amount, 5);
    expect(result?.summary, 'Barang: Deterjen cair\nJumlah: 5 liter');
    expect(tester.takeException(), isNull);
  });

  testWidgets('kasbon dapat dikirim tanpa alasan pribadi', (tester) async {
    RequestSubmission? result;
    await _openForm(
      tester,
      initialType: 'Request Kasbon',
      onSubmit: (value) => result = value,
    );
    await _enter(tester, 'Nominal (Rp)', '100000');
    await _submit(tester);
    expect(result?.kind, RequestKind.cashAdvance);
    expect(result?.amount, 100000);
    expect(result?.summary, 'Pengajuan kasbon');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'biaya memerlukan jenis dan tujuan, mengganti jenis membersihkan catatan',
    (tester) async {
      RequestSubmission? result;
      await _openForm(
        tester,
        initialType: 'Request Kasbon',
        onSubmit: (value) => result = value,
      );
      await _enter(tester, 'Nominal (Rp)', '100000');
      await _enter(
        tester,
        'Catatan tambahan (opsional)',
        'Catatan pribadi kasbon',
      );
      await _tapText(tester, 'Biaya Operasional');
      await _submit(tester);
      expect(result, isNull);
      expect(find.text('Jenis biaya wajib dipilih.'), findsOneWidget);
      expect(find.text('Nominal (Rp) harus lebih dari nol.'), findsOneWidget);
      expect(find.text('Tujuan penggunaan wajib diisi.'), findsOneWidget);

      await _choose(tester, 'Jenis biaya', 'Reimbursement (sudah dibayar)');
      await _enter(tester, 'Nominal (Rp)', '25000');
      await _enter(tester, 'Tujuan penggunaan', 'Beli plastik kemasan');
      await _submit(tester);
      expect(result?.kind, RequestKind.expense);
      expect(result?.amount, 25000);
      expect(
        result?.summary,
        'Jenis biaya: Reimbursement (sudah dibayar)\nTujuan: Beli plastik kemasan',
      );
      expect(result?.summary, isNot(contains('Catatan pribadi')));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('izin cukup jenis dan tanggal tanpa detail pribadi', (
    tester,
  ) async {
    RequestSubmission? result;
    await _openForm(
      tester,
      initialType: 'Request Izin',
      onSubmit: (value) => result = value,
    );
    await _submit(tester);
    expect(result, isNull);
    expect(find.text('Jenis izin wajib dipilih.'), findsOneWidget);
    expect(find.text('Tanggal mulai wajib dipilih.'), findsOneWidget);
    expect(find.text('Tanggal selesai wajib dipilih.'), findsOneWidget);
    await _choose(tester, 'Jenis izin', 'Sakit');
    await _pickDate(tester);
    await _pickDate(tester);
    await _submit(tester);
    expect(result?.kind, RequestKind.leave);
    expect(result?.amount, 0);
    expect(result?.summary, contains('Jenis izin: Sakit\nTanggal:'));
    expect(result?.summary, isNot(contains('Catatan:')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tukar shift membutuhkan jadwal dan rekan pengganti', (
    tester,
  ) async {
    RequestSubmission? result;
    await _openForm(
      tester,
      initialType: 'Request Tukar Shift',
      onSubmit: (value) => result = value,
    );
    await _submit(tester);
    expect(result, isNull);
    expect(find.text('Rekan pengganti wajib diisi.'), findsOneWidget);
    await _pickDate(tester);
    await _enter(tester, 'Shift asal', '06.00–14.00');
    await _enter(tester, 'Shift tujuan', '12.00–20.00');
    await _enter(tester, 'Rekan pengganti', 'Budi');
    await _submit(tester);
    expect(result?.kind, RequestKind.shiftSwap);
    expect(
      result?.summary,
      contains(
        'Shift asal: 06.00–14.00\nShift tujuan: 12.00–20.00\nRekan pengganti: Budi',
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('lembur wajib punya tanggal, jam, dan pekerjaan', (tester) async {
    RequestSubmission? result;
    await _openForm(
      tester,
      initialType: 'Request Lembur',
      onSubmit: (value) => result = value,
    );
    await _submit(tester);
    expect(result, isNull);
    expect(find.text('Tanggal lembur wajib dipilih.'), findsOneWidget);
    expect(find.text('Jam mulai wajib dipilih.'), findsOneWidget);
    expect(find.text('Jam selesai wajib dipilih.'), findsOneWidget);
    expect(
      find.text('Pekerjaan yang diselesaikan wajib diisi.'),
      findsOneWidget,
    );
    await _pickDate(tester);
    await _enter(
      tester,
      'Pekerjaan yang diselesaikan',
      'Menyelesaikan setrika',
    );
    await _tapText(tester, 'Pilih jam');
    await _tapText(tester, 'OK');
    await _tapText(tester, 'Pilih jam');
    await _tapText(tester, 'OK');
    await _submit(tester);
    expect(result, isNull);
    expect(
      find.text('Durasi lembur harus lebih dari 0 dan maksimal 24 jam.'),
      findsOneWidget,
    );
    await _tapText(tester, 'Selesai pada hari berikutnya');
    await _submit(tester);
    expect(result?.kind, RequestKind.overtime);
    expect(result?.summary, contains('(hari berikutnya)\nDurasi: 1440 menit'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('kategori tetap bisa dipakai di layar kecil dengan teks besar', (
    tester,
  ) async {
    await _openForm(tester, smallScreen: true);
    await _choose(tester, 'Kategori pengajuan', 'Izin & Jadwal');
    expect(find.text('Pilihan jadwal lainnya'), findsOneWidget);
    expect(find.text('Nama barang'), findsNothing);
    await _choose(tester, 'Kategori pengajuan', 'Dana & Biaya');
    await _tapText(tester, 'Biaya Operasional');
    await _choose(tester, 'Jenis biaya', 'Reimbursement (sudah dibayar)');
    await tester.ensureVisible(find.text('Kirim ke Owner'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('tautan insentif lama tidak menawarkan pengajuan insentif baru', (
    tester,
  ) async {
    await _openForm(tester, initialType: 'Request Insentif');
    await _choose(tester, 'Kategori pengajuan', 'Dana & Biaya');
    expect(find.text('Kasbon'), findsOneWidget);
    expect(find.text('Biaya Operasional'), findsOneWidget);
    expect(find.text('Insentif'), findsNothing);
  });

  testWidgets('Owner tetap bisa mereview insentif lama dalam Dana & Biaya', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          employeeRequestControllerProvider.overrideWith(
            _HistoryController.new,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const RequestReviewPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _choose(tester, 'Kategori pengajuan', 'Dana & Biaya');
    expect(find.text('Insentif'), findsOneWidget);
    expect(find.text('Setujui'), findsOneWidget);
    expect(find.text('Kebutuhan Stok'), findsNothing);
    await _choose(tester, 'Kategori pengajuan', 'Semua kategori');
    expect(find.text('Insentif'), findsOneWidget);
    expect(find.text('Kebutuhan Stok'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _openForm(
  WidgetTester tester, {
  String? initialType,
  ValueChanged<RequestSubmission?>? onSubmit,
  bool smallScreen = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = smallScreen
      ? const Size(320, 568)
      : const Size(430, 932);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(smallScreen ? 1.5 : 1)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final result = await showModalBottomSheet<RequestSubmission>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => RequestFormSheet(initialType: initialType),
              );
              onSubmit?.call(result);
            },
            child: const Text('Buka'),
          ),
        ),
      ),
    ),
  );
  await _tapText(tester, 'Buka');
}

Future<void> _enter(WidgetTester tester, String label, String value) async {
  final field = find.widgetWithText(TextFormField, label);
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pumpAndSettle();
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final target = find.text(text).first;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester, String label, String option) async {
  final field = find
      .ancestor(
        of: find.text(label).first,
        matching: find.byWidgetPredicate(
          (widget) => widget is DropdownButtonFormField,
        ),
      )
      .first;
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.tap(field);
  await tester.pumpAndSettle();
  final target = find.text(option).last;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _pickDate(WidgetTester tester) async {
  await _tapText(tester, 'Pilih tanggal');
  await _tapText(tester, 'OK');
}

Future<void> _submit(WidgetTester tester) => _tapText(tester, 'Kirim ke Owner');

class _HistoryController extends EmployeeRequestController {
  @override
  Future<EmployeeRequestListState> build() async => EmployeeRequestListState(
    isOnline: false,
    requests: [
      for (final type in ['Request Insentif', 'Request Stok'])
        PreviewEmployeeRequest(
          id: type,
          employeeId: 'employee-1',
          employeeName: 'Budi',
          type: type,
          reason: 'Riwayat lama',
          amount: 1,
          status: PreviewRequestStatus.pending,
          createdAt: DateTime(2026, 8, 30),
        ),
    ],
  );
}

class _EmployeeAuthController extends AuthController {
  @override
  Future<AuthSessionState> build() async =>
      const AuthSessionState.authenticated(
        AppUser(
          userId: 'preview-employee',
          shopId: 'preview-shop',
          employeeId: 'employee-1',
          name: 'Budi',
          role: UserRole.employee,
          isActive: true,
        ),
      );
}
