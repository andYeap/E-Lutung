/// Pemetaan pedagang: mengubah keterangan transaksi menjadi pola yang bisa
/// dicocokkan, supaya kategori & akun yang pernah dipakai bisa diusulkan lagi.
///
/// Murni dan tanpa basis data supaya bisa diuji dengan contoh teks saja.
library;

/// Normalisasi nama pedagang menjadi pola pencocokan.
///
/// Huruf kecil, tanda baca jadi pemisah, dan spasi dirapikan. Dua ejaan yang
/// hanya berbeda pada tanda baca (mis. "Warung Bu Ani," dan "WARUNG  BU ANI")
/// menghasilkan pola yang sama. Mengembalikan null bila tidak ada cukup isi
/// untuk dijadikan pola, supaya keterangan kosong atau sependek "ok" tidak
/// menjelma jadi kebiasaan.
///
/// Sengaja **tidak** memotong kata: pola harus utuh supaya "Toko A" dan
/// "Toko A Cabang B" tidak dianggap pedagang yang sama.
String? polaMerchant(String? catatan) {
  if (catatan == null) return null;
  final rapi = catatan
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (rapi.length < 3) return null;
  return rapi;
}
