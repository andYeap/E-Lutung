import 'package:drift/native.dart';
import 'package:elutung/data/database.dart';
import 'package:elutung/data/repositories/account_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Label akun. Akun tidak punya nama sendiri (PRD FR-7.2: namanya diambil dari
/// institusi), jadi dua akun di bank yang sama harus tetap bisa dibedakan —
/// kalau tidak, saldo bisa dibaca atau akun bisa dipilih secara keliru.
void main() {
  late AppDatabase db;
  late AccountRepository accounts;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    accounts = AccountRepository(db);
  });
  tearDown(() => db.close());

  Future<void> buatAkun(String institusiId, {String? nama}) => accounts.create(
    institusiId: institusiId,
    milikSendiri: true,
    saldoAwal: 0,
    nama: nama,
  );

  test('nama dari pengguna dipakai bila diisi', () async {
    await buatAkun('bca', nama: 'Gaji bulanan');
    final semua = await accounts.watchAll().first;

    expect(akunLabel(semua, semua.single.account.id), 'Gaji bulanan');
  });

  test('nama yang hanya spasi dianggap kosong', () async {
    await buatAkun('bca', nama: '   ');
    final semua = await accounts.watchAll().first;

    expect(semua.single.account.nama, isNull);
    expect(akunLabel(semua, semua.single.account.id), 'BCA');
  });

  test('nama yang sama tetap dibedakan nomor urut', () async {
    await buatAkun('bca', nama: 'Dompet');
    await buatAkun('mandiri', nama: 'Dompet');
    final semua = await accounts.watchAll().first;

    expect(akunLabels(semua).values.toSet(), {'Dompet (1)', 'Dompet (2)'});
  });

  test('nama berbeda tidak perlu nomor urut', () async {
    await buatAkun('bca', nama: 'Gaji');
    await buatAkun('bca', nama: 'Tabungan');
    final semua = await accounts.watchAll().first;

    expect(akunLabels(semua).values.toSet(), {'Gaji', 'Tabungan'});
  });

  test('satu akun per institusi: labelnya nama institusi saja', () async {
    await buatAkun('bca');
    final semua = await accounts.watchAll().first;

    expect(akunLabel(semua, semua.single.account.id), 'BCA');
  });

  test('dua akun di institusi yang sama: diberi nomor urut', () async {
    await buatAkun('bca');
    await buatAkun('bca');
    final semua = await accounts.watchAll().first;

    expect(akunLabels(semua).values.toSet(), {'BCA (1)', 'BCA (2)'});
  });

  test('institusi berbeda tidak saling memberi nomor', () async {
    await buatAkun('bca');
    await buatAkun('tunai');
    final semua = await accounts.watchAll().first;

    expect(akunLabels(semua).values.toSet(), {'BCA', 'Tunai'});
  });

  test('nomornya tetap sama walau daftarnya disaring untuk pemilih', () async {
    await buatAkun('bca');
    await buatAkun('bca');
    await buatAkun('tunai');
    final semua = await accounts.watchAll().first;

    // Pemilih hanya menampilkan sebagian, tetapi label tetap dihitung dari
    // daftar lengkap supaya nomornya tidak berbeda antar layar.
    final bcaSaja = semua
        .where((a) => a.institusi.nama == 'BCA')
        .toList(growable: false);

    expect(bcaSaja.map((a) => akunLabel(semua, a.account.id)).toSet(), {
      'BCA (1)',
      'BCA (2)',
    });
  });

  test('id yang tidak dikenal tidak melempar', () {
    expect(akunLabel([], 'tidak-ada'), '?');
  });
}
