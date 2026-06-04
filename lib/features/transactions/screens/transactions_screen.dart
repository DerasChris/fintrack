// lib/features/transactions/screens/transactions_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/transaction.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../widgets/transaction_tile.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _repo = TransactionRepository();
  final _searchCtrl = TextEditingController();

  List<Transaction> _all = [];
  List<Transaction> _filtered = [];
  Category? _filterCategory;
  Bank? _filterBank;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await _repo.getAllTransactions();
    setState(() {
      _all = data;
      _filtered = data;
      _isLoading = false;
    });
  }

  void _applyFilters() {
    final query = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _all.where((t) {
        final matchSearch = query.isEmpty || t.merchant.toLowerCase().contains(query);
        final matchCat = _filterCategory == null || t.category == _filterCategory;
        final matchBank = _filterBank == null || t.bank == _filterBank;
        return matchSearch && matchCat && matchBank;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Movimientos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: AppColors.textSecondary),
            onPressed: _showFilters,
          ),
        ],
      ),
      body: Column(
        children: [
          // Búsqueda
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Buscar comercio...',
                prefixIcon: Icon(Icons.search, color: AppColors.textMuted, size: 20),
                isDense: true,
              ),
            ),
          ),

          // Chips de filtro activos
          if (_filterCategory != null || _filterBank != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  if (_filterCategory != null)
                    _chip(_filterCategory!.label, () {
                      _filterCategory = null;
                      _applyFilters();
                    }),
                  if (_filterBank != null)
                    _chip(_filterBank!.label, () {
                      _filterBank = null;
                      _applyFilters();
                    }),
                ],
              ),
            ),

          // Conteo
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Text('${_filtered.length} transacciones',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),

          // Lista
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _filtered.isEmpty
                    ? const Center(
                        child: Text('Sin resultados',
                            style: TextStyle(color: AppColors.textMuted)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filtered.length,
                        itemBuilder: (context, i) {
                          final t = _filtered[i];

                          // Separador de mes
                          final showHeader = i == 0 ||
                              _filtered[i - 1].date.month != t.date.month ||
                              _filtered[i - 1].date.year != t.date.year;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (showHeader)
                                Padding(
                                  padding: const EdgeInsets.only(top: 16, bottom: 8),
                                  child: Text(
                                    DateFormat('MMMM yyyy', 'es').format(t.date),
                                    style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.5),
                                  ),
                                ),
                              TransactionTile(
                                transaction: t,
                                onCategoryChanged: (cat) async {
                                  final updated = t.copyWith(
                                      category: cat, isManuallyEdited: true);
                                  await _repo.updateTransaction(updated);
                                  await _load();
                                },
                              ),
                            ],
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, VoidCallback onRemove) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Chip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        deleteIcon: const Icon(Icons.close, size: 14),
        onDeleted: onRemove,
        backgroundColor: AppColors.primaryGlow,
        side: const BorderSide(color: AppColors.primary, width: 0.5),
      ),
    );
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setModal) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Filtrar por categoría',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: Category.values.map((cat) {
                    final sel = _filterCategory == cat;
                    return FilterChip(
                      label: Text(cat.label, style: const TextStyle(fontSize: 11)),
                      selected: sel,
                      onSelected: (v) {
                        setModal(() => _filterCategory = v ? cat : null);
                        setState(() {});
                        _applyFilters();
                      },
                      selectedColor: AppColors.primaryGlow,
                      checkmarkColor: AppColors.primary,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Filtrar por banco',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [Bank.agricola, Bank.bac, Bank.davivienda, Bank.cuscatlan]
                      .map((bank) {
                    final sel = _filterBank == bank;
                    return FilterChip(
                      label: Text(bank.label, style: const TextStyle(fontSize: 11)),
                      selected: sel,
                      onSelected: (v) {
                        setModal(() => _filterBank = v ? bank : null);
                        setState(() {});
                        _applyFilters();
                      },
                      selectedColor: AppColors.primaryGlow,
                      checkmarkColor: AppColors.primary,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
