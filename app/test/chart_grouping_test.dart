import 'package:elutung/data/database.dart';
import 'package:elutung/data/finance.dart';
import 'package:elutung/util/color.dart';
import 'package:elutung/widgets/charts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mitigasi risiko Bagian 16 PRD: "Limit legend + 'Lainnya' untuk kategori
/// kecil" — tanpa mengubah jumlah persentase yang harus tetap 100%.
void main() {
  Category cat(String id, String nama, {String? warna}) => Category(
    id: id,
    nama: nama,
    ikon: null,
    warna: warna,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    deletedAt: null,
  );

  CategoryTotal total(String? id, int value) =>
      CategoryTotal(kategoriId: id, total: value);

  final catById = {
    'makan': cat('makan', 'Makanan', warna: '#FF0000'),
    'transport': cat('transport', 'Transport'),
    'belanja': cat('belanja', 'Belanja'),
    'hobi': cat('hobi', 'Hobi'),
    'lain': cat('lain', 'Lain-lain'),
    'kecil1': cat('kecil1', 'Kecil 1'),
    'kecil2': cat('kecil2', 'Kecil 2'),
    'kecil3': cat('kecil3', 'Kecil 3'),
  };

  test('kategori kecil digabung jadi satu "Lainnya"', () {
    final byCat = [
      total('makan', 400000),
      total('transport', 300000),
      total('belanja', 200000),
      total('hobi', 50000), // 5% — tetap sendiri
      total('lain', 30000), // 3% — tetap sendiri
      total('kecil1', 10000), // 1%
      total('kecil2', 8000),
      total('kecil3', 2000),
    ];

    final slices = buildChartSlices(
      byCat: byCat,
      catById: catById,
      totalExpense: 1000000,
    );

    expect(slices.length, 6); // 5 kategori besar + 1 gabungan
    expect(slices.last.label, kOtherSliceLabel);
    expect(slices.last.total, 20000);
    expect(slices.first.label, 'Makanan');

    // Jumlah potongan tetap sama dengan total → persentase tetap 100%.
    final sum = slices.fold<int>(0, (a, s) => a + s.total);
    expect(sum, 1000000);
  });

  test('satu kategori kecil tidak digabung', () {
    final slices = buildChartSlices(
      byCat: [total('makan', 98000), total('kecil1', 2000)],
      catById: catById,
      totalExpense: 100000,
    );
    expect(slices.length, 2);
    expect(slices.map((s) => s.label), ['Makanan', 'Kecil 1']);
    expect(slices.any((s) => s.label == kOtherSliceLabel), isFalse);
  });

  test('warna kategori dipakai; "Lainnya" memakai warna netral', () {
    final slices = buildChartSlices(
      byCat: [
        total('makan', 970000),
        total('kecil1', 20000), // 2% — di bawah ambang
        total('kecil2', 10000), // 1% — di bawah ambang
      ],
      catById: catById,
      totalExpense: 1000000,
    );
    expect(slices.first.label, 'Makanan');
    expect(slices.first.color, const Color(0xFFFF0000));
    expect(slices.last.label, kOtherSliceLabel);
    expect(slices.last.total, 30000);
    expect(slices.last.color, parseHexColor(null));
  });

  test('total nol atau daftar kosong menghasilkan grafik kosong', () {
    expect(
      buildChartSlices(byCat: [], catById: catById, totalExpense: 0),
      isEmpty,
    );
    expect(
      buildChartSlices(
        byCat: [total('makan', 1000)],
        catById: catById,
        totalExpense: 0,
      ),
      isEmpty,
    );
  });
}
