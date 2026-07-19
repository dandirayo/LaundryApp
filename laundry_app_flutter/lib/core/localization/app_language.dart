import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appLanguageProvider =
    NotifierProvider<AppLanguageController, AppLanguage>(
      AppLanguageController.new,
    );

enum AppLanguage {
  id('Indonesia', Locale('id')),
  en('English', Locale('en'));

  const AppLanguage(this.label, this.locale);

  final String label;
  final Locale locale;
}

class AppLanguageController extends Notifier<AppLanguage> {
  @override
  AppLanguage build() => AppLanguage.id;

  void setLanguage(AppLanguage language) {
    state = language;
  }
}

class AppStrings {
  const AppStrings(this.language);

  final AppLanguage language;

  bool get isEnglish => language == AppLanguage.en;

  String get home => isEnglish ? 'Home' : 'Beranda';
  String get orders => isEnglish ? 'Orders' : 'Pesanan';
  String get customers => isEnglish ? 'Customers' : 'Pelanggan';
  String get attendance => isEnglish ? 'Attendance' : 'Absensi';
  String get more => isEnglish ? 'More' : 'Lainnya';
  String get reports => isEnglish ? 'Reports' : 'Laporan';
  String get cashbook => isEnglish ? 'Cashbook' : 'Buku Kas';
  String get orderBook => isEnglish ? 'Order Book' : 'Buku Pesanan';
  String get oldData => 'Old Data';
  String get transactions => isEnglish ? 'Transactions' : 'Transaksi';
  String get summary => isEnglish ? 'Summary' : 'Ringkasan';
  String get languageLabel => isEnglish ? 'Language' : 'Bahasa';
  String get signInTitle =>
      isEnglish ? 'Sign in to Idola Laundry' : 'Masuk Idola Laundry';
  String get signInDescription => isEnglish
      ? 'Use your account to continue. Preview mode is available while online sync is not configured.'
      : 'Gunakan akun untuk masuk. Mode preview tersedia selama sinkron online belum dikonfigurasi.';
  String get signIn => isEnglish ? 'Sign In' : 'Masuk';
  String get previewOwner => isEnglish ? 'Preview Owner' : 'Preview Owner';
  String get previewEmployee =>
      isEnglish ? 'Preview Employee' : 'Preview Karyawan';
  String get emailRequired =>
      isEnglish ? 'Email is required.' : 'Email wajib diisi.';
  String get invalidEmail =>
      isEnglish ? 'Email format is invalid.' : 'Format email belum valid.';
  String get passwordRequired =>
      isEnglish ? 'Password is required.' : 'Password wajib diisi.';
  String get supabasePreviewNotice => isEnglish
      ? 'Supabase is not configured yet. Debug preview mode is available for checking navigation without production data.'
      : 'Supabase belum dikonfigurasi. Mode preview debug tersedia untuk cek navigasi tanpa data produksi.';
  String get supabaseMissingNotice => isEnglish
      ? 'Supabase is not configured yet. Fill dart-define before signing in.'
      : 'Supabase belum dikonfigurasi. Isi dart-define sebelum login.';
  String get today => isEnglish ? 'Today' : 'Hari ini';
  String get yesterday => isEnglish ? 'Yesterday' : 'Kemarin';
  String get thisWeek => isEnglish ? 'This week' : 'Minggu ini';
  String get thisMonth => isEnglish ? 'This month' : 'Bulan ini';
  String get last3Months => isEnglish ? '3 months' : '3 bulan';
  String get last6Months => isEnglish ? '6 months' : '6 bulan';
  String get lastYear => isEnglish ? '1 year' : '1 tahun';
  String get customRange => isEnglish ? 'Custom' : 'Rentang';

  String get logout => isEnglish ? 'Sign Out' : 'Keluar';
  String get logoutTitle =>
      isEnglish ? 'Sign out of account?' : 'Keluar dari akun?';
  String get logoutMessage => isEnglish
      ? 'Session, sensitive providers, auth cache, and subscriptions will be cleared.'
      : 'Session, provider sensitif, cache auth, dan subscription akan dibersihkan.';

  String get search => isEnglish ? 'Search' : 'Cari';
  String get save => isEnglish ? 'Save' : 'Simpan';
  String get saveChanges => isEnglish ? 'Save Changes' : 'Simpan Perubahan';
  String get edit => isEnglish ? 'Edit' : 'Edit';
  String get delete => isEnglish ? 'Delete' : 'Hapus';
  String get add => isEnglish ? 'Add' : 'Tambah';
  String get detail => isEnglish ? 'Detail' : 'Detail';
  String get all => isEnglish ? 'All' : 'Semua';
  String get phone => isEnglish ? 'Phone' : 'Telepon';
  String get name => isEnglish ? 'Name' : 'Nama';
  String get address => isEnglish ? 'Address' : 'Alamat';
  String get note => isEnglish ? 'Note' : 'Catatan';
  String get customer => isEnglish ? 'Customer' : 'Pelanggan';
  String get employee => isEnglish ? 'Employee' : 'Karyawan';
  String get service => isEnglish ? 'Service' : 'Layanan';
  String get servicesAndPrices =>
      isEnglish ? 'Services & Prices' : 'Layanan & Harga';
  String get inventory =>
      isEnglish ? 'Stock & Procurement' : 'Stok & Pengadaan';
  String get shifts => isEnglish ? 'Shift Schedule' : 'Jadwal Shift';
  String get employees => isEnglish ? 'Employees' : 'Data Karyawan';
  String get payroll => isEnglish ? 'Payroll & Incentives' : 'Gaji & Insentif';
  String get expenses => isEnglish ? 'Expenses' : 'Pengeluaran';
  String get notifications => isEnglish ? 'Notifications' : 'Notifikasi';
  String get backupData => isEnglish ? 'Backup Data' : 'Backup Data';
  String get shopSettings => isEnglish ? 'Shop Settings' : 'Pengaturan Toko';
  String get profile => isEnglish ? 'Profile' : 'Profil';
  String get changePin => isEnglish ? 'Change PIN' : 'Ganti PIN';
  String get requests => isEnglish ? 'Requests' : 'Request';

  String get operational => isEnglish ? 'OPERATIONS' : 'OPERASIONAL';
  String get team => isEnglish ? 'TEAM' : 'TIM';
  String get finance => isEnglish ? 'FINANCE' : 'KEUANGAN';
  String get system => isEnglish ? 'SYSTEM' : 'SISTEM';
  String get work => isEnglish ? 'WORK' : 'PEKERJAAN';
  String get account => isEnglish ? 'ACCOUNT' : 'AKUN';

  String get myOrders => isEnglish ? 'My Orders' : 'Pesanan Saya';
  String get mySchedule => isEnglish ? 'My Schedule' : 'Jadwal Saya';
  String get addCustomer => isEnglish ? 'Add Customer' : 'Tambah Pelanggan';
  String get editCustomer => isEnglish ? 'Edit Customer' : 'Edit Pelanggan';
  String get importPhoneContacts =>
      isEnglish ? 'Import Phone Contacts' : 'Import kontak HP';
  String get searchCustomers => isEnglish
      ? 'Search name, phone, or address'
      : 'Cari nama, telepon, atau alamat';
  String get noCustomersTitle =>
      isEnglish ? 'No customers yet' : 'Pelanggan belum ada';
  String get noCustomersMessage => isEnglish
      ? 'Add customers so orders can use a valid customerId.'
      : 'Tambahkan pelanggan agar pesanan bisa memakai customerId yang valid.';
  String get addressMissing =>
      isEnglish ? 'Address not filled' : 'Alamat belum diisi';
  String visits(int count) => isEnglish ? '$count visits' : '$count kunjungan';
  String get nameRequired =>
      isEnglish ? 'Name is required.' : 'Nama wajib diisi.';
  String get invalidPhone => isEnglish
      ? 'Phone number is not valid yet.'
      : 'Nomor telepon belum valid.';
  String get customerUpdated => isEnglish
      ? 'Customer updated successfully.'
      : 'Pelanggan berhasil diperbarui.';
  String get customerAdded => isEnglish
      ? 'Customer added successfully.'
      : 'Pelanggan berhasil ditambahkan.';
  String imported(String value) =>
      isEnglish ? '$value imported successfully.' : '$value berhasil diimport.';

  String get addOrder => isEnglish ? 'Add Order' : 'Tambah pesanan';
  String get searchOrders => isEnglish
      ? 'Search order number or customer'
      : 'Cari nomor pesanan atau pelanggan';
  String get noOrdersTitle => isEnglish ? 'No orders yet' : 'Pesanan belum ada';
  String get noOrdersMessage => isEnglish
      ? 'Create a new order from quick actions. Preview data is stored while the app is running.'
      : 'Buat pesanan baru lewat aksi cepat. Data preview tersimpan selama aplikasi berjalan.';
  String get receivePayment =>
      isEnglish ? 'Receive Payment' : 'Terima Pembayaran';
  String get amount => isEnglish ? 'Amount' : 'Nominal';
  String get method => isEnglish ? 'Method' : 'Metode';
  String get savePayment => isEnglish ? 'Save Payment' : 'Simpan Pembayaran';
  String get paymentSaved =>
      isEnglish ? 'Payment added to Cashbook.' : 'Pembayaran masuk Buku Kas.';
  String get whatsappReady => isEnglish
      ? 'WhatsApp opened with pickup-ready template.'
      : 'WhatsApp dibuka dengan template siap ambil.';
  String get whatsappUnavailable => isEnglish
      ? 'WhatsApp cannot be opened on this device.'
      : 'WhatsApp tidak bisa dibuka di perangkat ini.';
  String get processedBy => isEnglish ? 'Processed by' : 'Diproses oleh';
  String get unassigned => isEnglish ? 'Unassigned' : 'Belum ditugaskan';
  String get startProcessing => isEnglish ? 'Start Process' : 'Mulai Proses';
  String get markDone => isEnglish ? 'Mark Done' : 'Tandai Selesai';
  String get pickedUp => isEnglish ? 'Picked Up' : 'Sudah Diambil';
  String get completed => isEnglish ? 'Completed' : 'Sudah Selesai';
  String get cancelled => isEnglish ? 'Cancelled' : 'Dibatalkan';

  String orderStatus(String label) {
    if (!isEnglish) return label;
    return switch (label) {
      'Diterima' => 'Received',
      'Diproses' => 'Processing',
      'Selesai' => 'Ready',
      'Diambil' => 'Picked Up',
      'Dibatalkan' => 'Cancelled',
      _ => label,
    };
  }
}

extension AppStringsRef on WidgetRef {
  AppStrings get strings => AppStrings(watch(appLanguageProvider));
}
