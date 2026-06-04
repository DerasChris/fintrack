// lib/features/reports/screens/reports_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/transaction.dart';
import '../../../data/repositories/transaction_repository.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _repo = TransactionRepository();

  DateTime _month = DateTime.now();
  double _total = 0;
  Map<Category, double> _categoryTotals = {};
  List<Transaction> _transactions = [];
  bool _isLoading = true;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final totals = await _repo.getCategoryTotals(_month.year, _month.month);
    final monthTotal = await _repo.getMonthTotal(_month.year, _month.month);
    final txs = await _repo.getTransactionsByMonth(_month.year, _month.month);

    setState(() {
      _categoryTotals = totals;
      _total = monthTotal;
      _transactions = txs;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Reportes'),
        actions: [
          IconButton(
            icon: _isExporting
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                : const Icon(Icons.picture_as_pdf_outlined, color: AppColors.textSecondary),
            onPressed: _isExporting ? null : _exportPdf,
            tooltip: 'Exportar PDF',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Selector de mes
                  _buildMonthSelector(),
                  const SizedBox(height: 20),

                  // Total
                  _buildTotalCard(),
                  const SizedBox(height: 20),

                  // Por categoría
                  const Text('Desglose por categoría',
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 12),
                  _buildCategoryBreakdown(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  Widget _buildMonthSelector() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left, color: AppColors.textSecondary),
          onPressed: () {
            setState(() {
              _month = DateTime(_month.year, _month.month - 1);
            });
            _load();
          },
        ),
        Expanded(
          child: Center(
            child: Text(
              DateFormat('MMMM yyyy', 'es').format(_month),
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          onPressed: _month.month == DateTime.now().month &&
                  _month.year == DateTime.now().year
              ? null
              : () {
                  setState(() {
                    _month = DateTime(_month.year, _month.month + 1);
                  });
                  _load();
                },
        ),
      ],
    );
  }

  Widget _buildTotalCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D2818), Color(0xFF0A1F14)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total gastado',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 4),
                Text('\$${_total.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${_transactions.length}',
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w700)),
              const Text('transacciones',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown() {
    if (_categoryTotals.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Text('Sin datos para este mes',
              style: TextStyle(color: AppColors.textMuted)),
        ),
      );
    }

    final sorted = _categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final max = sorted.first.value;

    return Column(
      children: sorted.map((entry) {
        final cat = entry.key;
        final amount = entry.value;
        final pct = _total > 0 ? amount / _total : 0.0;
        final color = categoryColor(cat);
        final count = _transactions.where((t) => t.category == cat).length;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Text(cat.label,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('\$${amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      Text('$count pagos · ${(pct * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 11)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Barra de progreso
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: max > 0 ? amount / max : 0,
                  backgroundColor: color.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation(color),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ─── Export PDF ─────────────────────────────────────────────

  Future<void> _exportPdf() async {
    setState(() => _isExporting = true);

    try {
      final pdf = pw.Document();
      final monthLabel = DateFormat('MMMM yyyy', 'es').format(_month);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Encabezado
              pw.Text('FinTrack SV — Reporte Mensual',
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.Text(monthLabel,
                  style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
              pw.SizedBox(height: 24),

              // Total
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green50,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total gastado',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('\$${_total.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green800)),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),

              // Por categoría
              pw.Text('Desglose por categoría',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              ..._categoryTotals.entries
                  .toList()
                  .map((e) => pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 4),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(e.key.label),
                            pw.Text('\$${e.value.toStringAsFixed(2)}',
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      )),

              pw.Divider(),
              pw.SizedBox(height: 16),

              // Transacciones
              pw.Text('Detalle de transacciones',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Table(
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1.5),
                  2: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: ['Comercio', 'Banco', 'Monto']
                        .map((h) => pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(h,
                                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                            ))
                        .toList(),
                  ),
                  ..._transactions.map((t) => pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(t.merchant, style: const pw.TextStyle(fontSize: 9)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(t.bank.label, style: const pw.TextStyle(fontSize: 9)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('\$${t.amount.toStringAsFixed(2)}',
                                style: const pw.TextStyle(fontSize: 9)),
                          ),
                        ],
                      )),
                ],
              ),
            ],
          ),
        ),
      );

      await Printing.layoutPdf(onLayout: (_) async => pdf.save());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar PDF: $e'),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }
}
