// lib/features/dashboard/screens/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/dashboard_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../transactions/widgets/transaction_tile.dart';
import '../widgets/spending_chart.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Consumer<DashboardProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
            onRefresh: provider.refresh,
            child: CustomScrollView(
              slivers: [
                _buildAppBar(context, provider),
                SliverToBoxAdapter(child: _buildBody(context, provider)),
              ],
            ),
          );
        },
      ),
      floatingActionButton: Consumer<DashboardProvider>(
        builder: (context, provider, _) => FloatingActionButton.extended(
          onPressed: provider.isScanning ? null : () => _scanSms(context, provider),
          icon: provider.isScanning
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded),
          label: Text(provider.isScanning ? 'Escaneando...' : 'Leer SMS'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.black,
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, DashboardProvider provider) {
    final monthLabel = DateFormat('MMMM yyyy', 'es').format(provider.selectedMonth);

    return SliverAppBar(
      pinned: true,
      backgroundColor: AppColors.background,
      expandedHeight: 0,
      title: Row(
        children: [
          const Text('FinTrack ', style: TextStyle(fontWeight: FontWeight.w700)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primaryGlow,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('SV',
                style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      actions: [
        // Selector de mes
        TextButton.icon(
          onPressed: () => _pickMonth(context, provider),
          icon: const Icon(Icons.calendar_month_outlined, size: 16, color: AppColors.textSecondary),
          label: Text(monthLabel,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, DashboardProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          // Permiso no otorgado
          if (!provider.hasPermission) _buildPermissionBanner(context, provider),

          // Error
          if (provider.error != null) _buildErrorBanner(provider),

          // Total del mes
          _buildMonthCard(provider),
          const SizedBox(height: 20),

          // Gráfica de dona
          if (provider.categoryTotals.isNotEmpty) ...[
            const Text('Por categoría',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5)),
            const SizedBox(height: 12),
            SpendingChart(categoryTotals: provider.categoryTotals),
            const SizedBox(height: 24),
          ],

          // Alertas de suscripciones
          if (provider.subscriptions.any((s) => s.isAlertActive))
            _buildSubscriptionAlerts(provider),

          // Transacciones recientes
          const Text('Recientes',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5)),
          const SizedBox(height: 8),
          if (provider.recentTransactions.isEmpty)
            _buildEmptyState()
          else
            ...provider.recentTransactions.map(
              (t) => TransactionTile(transaction: t, onCategoryChanged: (cat) {
                provider.updateCategory(t, cat);
              }),
            ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // ─── Widgets auxiliares ─────────────────────────────────────

  Widget _buildMonthCard(DashboardProvider provider) {
    return Container(
      width: double.infinity,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Gastos del mes',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          Text(
            '\$${provider.monthTotal.toStringAsFixed(2)}',
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 36,
              fontWeight: FontWeight.w700,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${provider.monthTransactions.length} transacciones',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionBanner(BuildContext context, DashboardProvider provider) {
    final isPerm = provider.isPermPermanentlyDenied;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
            isPerm ? Icons.settings_outlined : Icons.lock_outline,
            color: AppColors.warning,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isPerm
                  ? 'Ve a Ajustes → Permisos → SMS y actívalo manualmente.'
                  : 'Se necesita permiso para leer SMS bancarios.',
              style: const TextStyle(color: AppColors.warning, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: () => provider.requestPermissionAndScan(),
            child: Text(
              isPerm ? 'Ajustes' : 'Permitir',
              style: const TextStyle(
                  color: AppColors.warning, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(DashboardProvider provider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.expense.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.expense.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.expense, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(provider.error!,
              style: const TextStyle(color: AppColors.expense, fontSize: 12))),
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: AppColors.textMuted),
            onPressed: provider.clearError,
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionAlerts(DashboardProvider provider) {
    final alerts = provider.subscriptions.where((s) => s.isAlertActive).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('⚡ Próximos cobros',
            style: TextStyle(color: AppColors.warning, fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        ...alerts.map((sub) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.warning.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.warning.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.notifications_active_outlined, color: AppColors.warning, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text('${sub.name} — \$${sub.amount.toStringAsFixed(2)}',
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
              ),
              Text('en ${sub.daysUntilNext}d',
                  style: const TextStyle(color: AppColors.warning, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        )),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined, color: AppColors.textMuted, size: 48),
          const SizedBox(height: 12),
          const Text('Sin transacciones este mes',
              style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
          const SizedBox(height: 4),
          const Text('Toca "Leer SMS" para importar',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  // ─── Acciones ───────────────────────────────────────────────

  Future<void> _scanSms(BuildContext context, DashboardProvider provider) async {
    if (!provider.hasPermission) {
      final granted = await provider.requestPermissionAndScan();
      if (!granted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permiso de SMS denegado'), backgroundColor: AppColors.expense),
        );
      }
      return;
    }

    final count = await provider.scanSms();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(count > 0
              ? '✓ $count transacciones importadas'
              : 'No se encontraron SMS bancarios nuevos'),
          backgroundColor: count > 0 ? AppColors.primary : AppColors.surfaceHigh,
        ),
      );
    }
  }

  Future<void> _pickMonth(BuildContext context, DashboardProvider provider) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: provider.selectedMonth,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDatePickerMode: DatePickerMode.year,
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      provider.changeMonth(DateTime(picked.year, picked.month));
    }
  }
}
