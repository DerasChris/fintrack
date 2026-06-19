// lib/features/dashboard/providers/dashboard_provider.dart

import 'package:flutter/foundation.dart' hide Category;
// ignore: avoid_print
import '../../../data/models/transaction.dart';
import '../../../data/models/subscription.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../data/repositories/sms_repository.dart';
import '../../../data/repositories/api_sync_repository.dart';

class DashboardProvider extends ChangeNotifier {
  final TransactionRepository _txRepo;
  final SmsRepository _smsRepo;
  final ApiSyncRepository _apiRepo;

  DashboardProvider({
    required TransactionRepository txRepo,
    required SmsRepository smsRepo,
    required ApiSyncRepository apiRepo,
  })  : _txRepo = txRepo,
        _smsRepo = smsRepo,
        _apiRepo = apiRepo;

  // ─── Estado ───
  List<Transaction> _recentTransactions = [];
  List<Transaction> _monthTransactions  = [];
  List<Subscription> _subscriptions     = [];
  Map<Category, double> _categoryTotals = {};
  double _monthTotal = 0;

  bool _isLoading = false;
  bool _isScanning = false;
  bool _isSyncing = false;
  String? _error;
  String? _lastSyncInfo;
  bool _hasPermission = false;
  bool _isPermPermanentlyDenied = false;

  DateTime _selectedMonth = DateTime.now();

  // ─── Getters ───
  List<Transaction>  get recentTransactions => _recentTransactions;
  List<Transaction>  get monthTransactions  => _monthTransactions;
  List<Subscription> get subscriptions      => _subscriptions;
  Map<Category, double> get categoryTotals  => _categoryTotals;
  double get monthTotal  => _monthTotal;
  bool   get isLoading   => _isLoading;
  bool   get isScanning  => _isScanning;
  String? get error      => _error;
  String? get lastSyncInfo => _lastSyncInfo;
  bool   get hasPermission => _hasPermission;
  bool   get isPermPermanentlyDenied => _isPermPermanentlyDenied;
  bool   get isSyncing => _isSyncing;
  DateTime get selectedMonth => _selectedMonth;

  // ─────────────────────────────────────────────────────────────
  // INICIALIZACIÓN
  // ─────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      _hasPermission = await _smsRepo.hasSmsPermission();
      _isPermPermanentlyDenied = await _smsRepo.isPermissionPermanentlyDenied();
      if (_hasPermission) {
        try {
          await _smsRepo.scanInbox();
          await _syncUnsyncedCurrentMonth();
        } catch (_) {}
      }
      await _loadData();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadData() async {
    final now = _selectedMonth;
    _recentTransactions = await _txRepo.getRecentTransactions(limit: 5);
    _monthTransactions  = await _txRepo.getTransactionsByMonth(now.year, now.month);
    _categoryTotals     = await _txRepo.getCategoryTotals(now.year, now.month);
    _monthTotal         = await _txRepo.getMonthTotal(now.year, now.month);
    _subscriptions      = await _txRepo.getActiveSubscriptions();
  }

  // ─────────────────────────────────────────────────────────────
  // ACCIONES
  // ─────────────────────────────────────────────────────────────

  /// Solicitar permiso de SMS y escanear inbox
  Future<bool> requestPermissionAndScan() async {
    _isPermPermanentlyDenied = await _smsRepo.isPermissionPermanentlyDenied();
    if (_isPermPermanentlyDenied) {
      await _smsRepo.openSettings();
      notifyListeners();
      return false;
    }

    final granted = await _smsRepo.requestSmsPermission();
    _hasPermission = granted;
    _isPermPermanentlyDenied = await _smsRepo.isPermissionPermanentlyDenied();

    if (granted) {
      await scanSms();
    }

    notifyListeners();
    return granted;
  }

  /// Escanear SMS del inbox
  Future<int> scanSms() async {
    _isScanning = true;
    _error = null;
    _lastSyncInfo = null;
    notifyListeners();

    int found = 0;
    try {
      final newTx = await _smsRepo.scanInbox();
      found = newTx.length;
    } catch (e) {
      _error = 'Error al leer SMS: ${e.toString()}';
      _isScanning = false;
      notifyListeners();
      return 0;
    }

    // Sync es opcional — si falla por red no bloquea el resultado del scan
    try {
      final synced = await _syncUnsyncedCurrentMonth();
      _lastSyncInfo = synced > 0
          ? 'Sincronizados $synced movimiento(s) a la API'
          : null;
    } catch (e) {
      _lastSyncInfo = 'Sin conexión — los movimientos se sincronizarán después';
    }

    await _loadData();
    _isScanning = false;
    notifyListeners();
    return found;
  }

  Future<int> _syncUnsyncedCurrentMonth() async {
    final now = DateTime.now();
    final unsynced = await _txRepo.getUnsyncedTransactionsByMonth(now.year, now.month);
    if (unsynced.isEmpty) return 0;

    var syncedCount = 0;
    for (final tx in unsynced) {
      final ok = await _apiRepo.sendTransaction(tx);
      if (!ok) continue;
      await _txRepo.markTransactionAsSynced(tx.id);
      syncedCount++;
    }
    return syncedCount;
  }

  /// Sincronización manual con feedback visible
  Future<String> syncNow() async {
    _isSyncing = true;
    _lastSyncInfo = null;
    notifyListeners();

    try {
      final userId = await _apiRepo.getUserId();
      final config = await _apiRepo.loadConfig();
      debugPrint('[SYNC] userId=$userId config=$config');

      final hasConfig = await _apiRepo.hasConfig();
      debugPrint('[SYNC] hasConfig=$hasConfig');
      if (!hasConfig) {
        _lastSyncInfo = 'Configura tu User ID en Ajustes';
        return _lastSyncInfo!;
      }

      final now = DateTime.now();
      final unsynced = await _txRepo.getUnsyncedTransactionsByMonth(now.year, now.month);
      debugPrint('[SYNC] unsynced=${unsynced.length} txs');
      if (unsynced.isEmpty) {
        _lastSyncInfo = 'No hay movimientos pendientes por sincronizar';
        return _lastSyncInfo!;
      }

      var synced = 0;
      var failed = 0;
      for (final tx in unsynced) {
        try {
          debugPrint('[SYNC] enviando tx=${tx.id} amount=${tx.amount} type=${tx.type}');
          final ok = await _apiRepo.sendTransaction(tx);
          debugPrint('[SYNC] resultado tx=${tx.id} ok=$ok');
          if (ok) {
            await _txRepo.markTransactionAsSynced(tx.id);
            synced++;
          } else {
            failed++;
          }
        } catch (e) {
          debugPrint('[SYNC] error tx=${tx.id}: $e');
          failed++;
        }
      }

      _lastSyncInfo = synced > 0
          ? 'Enviados $synced movimiento(s)${failed > 0 ? " · $failed fallaron" : ""}'
          : 'Falló la sincronización ($failed errores) — revisa la URL';
      debugPrint('[SYNC] resultado final: $_lastSyncInfo');
      return _lastSyncInfo!;
    } catch (e) {
      final msg = e.toString();
      _lastSyncInfo = msg.contains('Failed host lookup') || msg.contains('SocketException')
          ? 'Sin conexión a internet — verifica tu red e intenta de nuevo'
          : 'Error: $msg';
      return _lastSyncInfo!;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Revertir carga: elimina de la API y desmarca localmente
  Future<String> revertCurrentMonthSync() async {
    _isSyncing = true;
    notifyListeners();

    try {
      final now = DateTime.now();
      final ids = await _txRepo.getSyncedTransactionIdsByMonth(now.year, now.month);
      if (ids.isEmpty) {
        _lastSyncInfo = 'No hay movimientos sincronizados este mes';
        return _lastSyncInfo!;
      }

      final deleted = await _apiRepo.revertTransactions(ids);
      await _txRepo.unmarkTransactionsAsSynced(ids);

      _lastSyncInfo = deleted > 0
          ? 'Revertidos $deleted de ${ids.length} movimiento(s) en la API'
          : '${ids.length} movimiento(s) desmarcados localmente (API no respondió)';
      return _lastSyncInfo!;
    } catch (e) {
      _lastSyncInfo = 'Error al revertir: ${e.toString()}';
      return _lastSyncInfo!;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Cambiar mes visualizado
  Future<void> changeMonth(DateTime month) async {
    _selectedMonth = month;
    _isLoading = true;
    notifyListeners();

    await _loadData();

    _isLoading = false;
    notifyListeners();
  }

  /// Actualizar categoría de una transacción manualmente
  Future<void> updateCategory(Transaction t, Category newCategory) async {
    final updated = t.copyWith(
      category: newCategory,
      isManuallyEdited: true,
    );
    await _txRepo.updateTransaction(updated);
    await _loadData();
    notifyListeners();
  }

  /// Refrescar datos
  Future<void> refresh() async {
    await _loadData();
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
