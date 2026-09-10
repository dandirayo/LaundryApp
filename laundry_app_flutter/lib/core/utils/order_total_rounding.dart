/// Membulatkan total pesanan ke ribuan untuk mengikuti harga operasional toko.
/// Berlaku untuk seluruh metode dan status pembayaran.
///
/// Sisa sampai dengan Rp500 dibulatkan ke bawah. Sisa mulai Rp501
/// dibulatkan ke atas.
int roundOrderTotal(num amount) {
  final rounded = amount.round();
  final value = rounded < 0 ? 0 : rounded;
  final base = (value ~/ 1000) * 1000;
  final remainder = value - base;
  return remainder <= 500 ? base : base + 1000;
}
