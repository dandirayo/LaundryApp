/// Membulatkan total pesanan ke ribuan untuk mengikuti harga operasional toko.
/// Berlaku untuk seluruh metode dan status pembayaran.
///
/// Nilai yang sudah tepat pada kelipatan Rp1.000 tidak berubah. Setiap nilai
/// di atasnya dibulatkan naik ke kelipatan Rp1.000 berikutnya.
int roundOrderTotal(num amount) {
  final value = amount.ceil();
  if (value <= 0) return 0;
  return ((value + 999) ~/ 1000) * 1000;
}
