import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// Jenis penyedia (Bagian 7.1 PRD).
enum InstitutionType { bank, ewallet, tunai, lain }

/// Tipe transaksi (Bagian 7.4 PRD). Sumber tunggal penanda pemasukan/pengeluaran.
enum TxType { pemasukan, pengeluaran, transfer }

/// Lingkup anggaran (Bagian 7.5 PRD).
enum BudgetScope { total, kategori }

/// Master institusi — bank, e-wallet, tunai, lain-lain (Bagian 7.1).
class Institutions extends Table {
  TextColumn get id => text()();
  TextColumn get nama => text()();
  TextColumn get tipe => textEnum<InstitutionType>()();
  BoolColumn get aktif => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Kategori (Bagian 7.2) — tanpa field `jenis`, karena tipe dibawa transaksi.
///
/// Tanpa kolom `archived`: keadaan "tidak aktif" sudah dibawa `deletedAt`
/// (soft delete). Kategori yang masih dipakai transaksi tidak boleh dihapus
/// (lihat `CategoryRepository.usedByTransactions`); penamaan/warna historis
/// tetap terbaca lewat `allCategoriesProvider`.
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get nama => text()();
  TextColumn get ikon => text().nullable()();
  TextColumn get warna => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Akun/dompet; nama diambil dari institusi (Bagian 7.3), tanpa label.
class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get institusiId => text().references(Institutions, #id)();
  BoolColumn get milikSendiri => boolean().withDefault(const Constant(true))();
  IntColumn get saldoAwal => integer().withDefault(const Constant(0))();
  BoolColumn get aktif => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Transaksi (Bagian 7.4). Indeks sesuai Bagian 16 PRD: mempercepat filter
/// tipe/kategori dan pengurutan per tanggal.
@TableIndex(
  name: 'idx_transactions_tipe_tanggal_kategori',
  columns: {#tipe, #tanggal, #kategoriId},
)
class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get tipe => textEnum<TxType>()();
  IntColumn get nominal => integer()();
  DateTimeColumn get tanggal => dateTime()();
  TextColumn get kategoriId =>
      text().nullable().references(Categories, #id)();
  TextColumn get akunId => text().nullable().references(Accounts, #id)();
  TextColumn get catatan => text().nullable()();
  TextColumn get akunAsalId => text().nullable().references(Accounts, #id)();
  TextColumn get akunTujuanId => text().nullable().references(Accounts, #id)();
  IntColumn get biayaAdmin => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Anggaran (Bagian 7.5) — rentang tanggal eksplisit, sekali pakai.
class Budgets extends Table {
  TextColumn get id => text()();
  TextColumn get lingkup => textEnum<BudgetScope>()();
  TextColumn get kategoriId =>
      text().nullable().references(Categories, #id)();
  DateTimeColumn get periodeMulai => dateTime()();
  DateTimeColumn get periodeSelesai => dateTime()();
  IntColumn get nominal => integer()();
  BoolColumn get aktif => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [Institutions, Categories, Accounts, Transactions, Budgets],
)
class AppDatabase extends _$AppDatabase {
  /// `executor` bisa diisi (mis. `NativeDatabase.memory()`) untuk pengujian.
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _seed();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // Kolom `archived` dibuang: keadaan nonaktif kini hanya `deletedAt`.
        await m.dropColumn(categories, 'archived');
        // Membuat indeks baru (CREATE ... IF NOT EXISTS, aman diulang).
        await m.createAll();
      }
    },
  );

  static QueryExecutor _open() => driftDatabase(name: 'elutung');

  /// Data awal institusi & kategori (Bagian 7.1 & 7.2).
  Future<void> _seed() async {
    await batch((b) {
      b.insertAll(institutions, [
        InstitutionsCompanion.insert(id: 'tunai', nama: 'Tunai', tipe: InstitutionType.tunai),
        InstitutionsCompanion.insert(id: 'bca', nama: 'BCA', tipe: InstitutionType.bank),
        InstitutionsCompanion.insert(id: 'mandiri', nama: 'Mandiri', tipe: InstitutionType.bank),
        InstitutionsCompanion.insert(id: 'bni', nama: 'BNI', tipe: InstitutionType.bank),
        InstitutionsCompanion.insert(id: 'bri', nama: 'BRI', tipe: InstitutionType.bank),
        InstitutionsCompanion.insert(id: 'bsi', nama: 'BSI', tipe: InstitutionType.bank),
        InstitutionsCompanion.insert(id: 'ovo', nama: 'OVO', tipe: InstitutionType.ewallet),
        InstitutionsCompanion.insert(id: 'gopay', nama: 'GoPay', tipe: InstitutionType.ewallet),
        InstitutionsCompanion.insert(id: 'dana', nama: 'Dana', tipe: InstitutionType.ewallet),
        InstitutionsCompanion.insert(id: 'shopeepay', nama: 'ShopeePay', tipe: InstitutionType.ewallet),
        InstitutionsCompanion.insert(id: 'linkaja', nama: 'LinkAja', tipe: InstitutionType.ewallet),
        InstitutionsCompanion.insert(id: 'lain', nama: 'Lain-lain', tipe: InstitutionType.lain),
      ]);
      b.insertAll(categories, [
        CategoriesCompanion.insert(id: 'makanan', nama: 'Makanan & Minuman', ikon: Value('restaurant'), warna: Value('#D98C7A')),
        CategoriesCompanion.insert(id: 'belanja', nama: 'Belanja Kebutuhan Pribadi', ikon: Value('shopping_bag'), warna: Value('#E0B36B')),
        CategoriesCompanion.insert(id: 'transport', nama: 'Transport', ikon: Value('directions_car'), warna: Value('#7FA0CC')),
        CategoriesCompanion.insert(id: 'tagihan', nama: 'Tagihan & Utilitas', ikon: Value('receipt_long'), warna: Value('#A08CC0')),
        CategoriesCompanion.insert(id: 'kesehatan', nama: 'Kesehatan', ikon: Value('medical_services'), warna: Value('#6FBFA8')),
        CategoriesCompanion.insert(id: 'hiburan', nama: 'Hiburan', ikon: Value('sports_esports'), warna: Value('#D79AC0')),
        CategoriesCompanion.insert(id: 'pendidikan', nama: 'Pendidikan', ikon: Value('school'), warna: Value('#86C4D6')),
        CategoriesCompanion.insert(id: 'transfer_admin', nama: 'Transfer & Admin', ikon: Value('swap_horiz'), warna: Value('#8B93CE')),
        CategoriesCompanion.insert(id: 'gaji', nama: 'Gaji', ikon: Value('payments'), warna: Value('#6FAE86')),
        CategoriesCompanion.insert(id: 'bonus', nama: 'Bonus', ikon: Value('redeem'), warna: Value('#85BE9A')),
        CategoriesCompanion.insert(id: 'usaha', nama: 'Usaha', ikon: Value('storefront'), warna: Value('#A3BC7E')),
        CategoriesCompanion.insert(id: 'bunga_hadiah', nama: 'Bunga/Hadiah', ikon: Value('card_giftcard'), warna: Value('#D4B978')),
        CategoriesCompanion.insert(id: 'lain2', nama: 'Lain-lain', ikon: Value('more_horiz'), warna: Value('#A9AEB6')),
      ]);
    });
  }
}
