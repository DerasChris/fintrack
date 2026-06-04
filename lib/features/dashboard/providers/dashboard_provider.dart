// lib/features/dashboard/providers/dashboard_provider.dart

import 'package:flutter/foundation.dart' hide Category;
import '../../../data/models/transaction.dart';
import '../../../data/models/subscription.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../data/repositories/sms_repository.dart';

class DashboardProvider extends ChangeNotifier {
  final TransactionRepository _txRepo;
  final SmsRepository _smsRepo;

  DashboardProvider({
    required TransactionRepository txRepo,
    required SmsRepository smsRepo,
  })  : _txRepo = txRepo,
        _smsRepo = smsRepo;

  // ─── Estado ───
  List<Transaction> _recentTransactions = [];
  List<Transaction> _monthTransactions  = [];
  List<Subscription> _subscriptions     = [];
  Map<Category, double> _categoryTotals = {};
  double _monthTotal = 0;

  bool _isLoading = false;
  bool _isScanning = false;
  String? _error;
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
  bool   get hasPermission => _hasPermission;
  bool   get isPermPermanentlyDenied => _isPermPermanentlyDenied;
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
    notifyListeners();

    try {
      final newTx = await _smsRepo.scanInbox();
      await _loadData();
      return newTx.length;
    } catch (e) {
      _error = 'Error al escanear SMS: ${e.toString()}';
      return 0;
    } finally {
      _isScanning = false;
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
