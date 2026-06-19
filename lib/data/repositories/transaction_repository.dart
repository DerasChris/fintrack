// lib/data/repositories/transaction_repository.dart

import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:path/path.dart';
import '../models/transaction.dart';
import '../models/subscription.dart';

class TransactionRepository {
  static const _dbName = 'fintrack_sv.db';
  static const _dbVersion = 2;

  static Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _createTables,
      onUpgrade: _upgradeTables,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        amount REAL NOT NULL,
        merchant TEXT NOT NULL,
        card_last_four TEXT,
        date TEXT NOT NULL,
        bank TEXT NOT NULL,
        type TEXT NOT NULL,
        category TEXT NOT NULL,
        raw_sms TEXT NOT NULL,
        is_manually_edited INTEGER DEFAULT 0,
        notes TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE subscriptions (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        amount REAL NOT NULL,
        card_last_four TEXT,
        bank TEXT NOT NULL,
        day_of_month INTEGER NOT NULL,
        last_charged TEXT NOT NULL,
        next_expected TEXT,
        is_active INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE processed_sms (
        sms_hash TEXT PRIMARY KEY,
        processed_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE synced_transactions (
        transaction_id TEXT PRIMARY KEY,
        synced_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  Future<void> _upgradeTables(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS synced_transactions (
          transaction_id TEXT PRIMARY KEY,
          synced_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // TRANSACTIONS CRUD
  // ─────────────────────────────────────────────────────────────

  Future<void> insertTransaction(Transaction t) async {
    final db = await database;
    await db.insert(
      'transactions',
      t.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> insertTransactions(List<Transaction> list) async {
    final db = await database;
    final batch = db.batch();
    for (final t in list) {
      batch.insert('transactions', t.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateTransaction(Transaction t) async {
    final db = await database;
    await db.update(
      'transactions',
      t.toMap(),
      where: 'id = ?',
      whereArgs: [t.id],
    );
  }

  Future<void> deleteTransaction(String id) async {
    final db = await database;
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<Transaction?> getTransactionById(String id) async {
    final db = await database;
    final maps = await db.query('transactions', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Transaction.fromMap(maps.first);
  }

  /// Todas las transacciones ordenadas por fecha desc
  Future<List<Transaction>> getAllTransactions() async {
    final db = await database;
    final maps = await db.query('transactions', orderBy: 'date DESC');
    return maps.map(Transaction.fromMap).toList();
  }

  /// Transacciones de un mes/año específico
  Future<List<Transaction>> getTransactionsByMonth(int year, int month) async {
    final db = await database;
    final start = DateTime(year, month, 1).toIso8601String();
    final end = DateTime(year, month + 1, 1).toIso8601String();

    final maps = await db.query(
      'transactions',
      where: 'date >= ? AND date < ?',
      whereArgs: [start, end],
      orderBy: 'date DESC',
    );
    return maps.map(Transaction.fromMap).toList();
  }

  /// Gastos totales del mes agrupados por categoría
  Future<Map<Category, double>> getCategoryTotals(int year, int month) async {
    final transactions = await getTransactionsByMonth(year, month);
    final Map<Category, double> totals = {};

    for (final t in transactions) {
      totals[t.category] = (totals[t.category] ?? 0) + t.amount;
    }

    return totals;
  }

  /// Total gastado en el mes
  Future<double> getMonthTotal(int year, int month) async {
    final db = await database;
    final start = DateTime(year, month, 1).toIso8601String();
    final end = DateTime(year, month + 1, 1).toIso8601String();

    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM transactions WHERE date >= ? AND date < ?',
      [start, end],
    );

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Últimas N transacciones
  Future<List<Transaction>> getRecentTransactions({int limit = 10}) async {
    final db = await database;
    final maps = await db.query(
      'transactions',
      orderBy: 'date DESC',
      limit: limit,
    );
    return maps.map(Transaction.fromMap).toList();
  }

  /// Transacciones del mes que aun no se han sincronizado al API.
  Future<List<Transaction>> getUnsyncedTransactionsByMonth(int year, int month) async {
    final db = await database;
    final start = DateTime(year, month, 1).toIso8601String();
    final end = DateTime(year, month + 1, 1).toIso8601String();

    final maps = await db.rawQuery(
      '''
      SELECT t.*
      FROM transactions t
      LEFT JOIN synced_transactions s ON s.transaction_id = t.id
      WHERE t.date >= ? AND t.date < ? AND s.transaction_id IS NULL
      ORDER BY t.date DESC
      ''',
      [start, end],
    );

    return maps.map(Transaction.fromMap).toList();
  }

  Future<void> markTransactionAsSynced(String transactionId) async {
    final db = await database;
    await db.insert(
      'synced_transactions',
      {'transaction_id': transactionId},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // CONTROL DE DUPLICADOS (hash del SMS raw)
  // ─────────────────────────────────────────────────────────────

  Future<bool> isSmsAlreadyProcessed(String smsBody) async {
    final db = await database;
    final hash = smsBody.hashCode.toString();
    final result = await db.query(
      'processed_sms',
      where: 'sms_hash = ?',
      whereArgs: [hash],
    );
    return result.isNotEmpty;
  }

  Future<void> markSmsAsProcessed(String smsBody) async {
    final db = await database;
    final hash = smsBody.hashCode.toString();
    await db.insert(
      'processed_sms',
      {'sms_hash': hash},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SUBSCRIPTIONS CRUD
  // ─────────────────────────────────────────────────────────────

  Future<void> upsertSubscription(Subscription s) async {
    final db = await database;
    await db.insert(
      'subscriptions',
      s.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Subscription>> getActiveSubscriptions() async {
    final db = await database;
    final maps = await db.query(
      'subscriptions',
      where: 'is_active = 1',
      orderBy: 'day_of_month ASC',
    );
    return maps.map(Subscription.fromMap).toList();
  }

  Future<void> deactivateSubscription(String id) async {
    final db = await database;
    await db.update(
      'subscriptions',
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
