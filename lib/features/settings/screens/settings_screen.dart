// lib/features/settings/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/subscription.dart';
import '../../../data/models/transaction.dart' hide Category;
import '../../../data/repositories/api_sync_repository.dart';
import '../../../data/repositories/transaction_repository.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _repo = TransactionRepository();
  final _apiRepo = ApiSyncRepository();
  final _baseUrlCtrl = TextEditingController();
  final _endpointCtrl = TextEditingController();
  List<Subscription> _subscriptions = [];
  bool _savingApiConfig = false;

  @override
  void initState() {
    super.initState();
    _loadSubscriptions();
    _loadApiConfig();
  }

  @override
  void dispose() {
    _baseUrlCtrl.dispose();
    _endpointCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSubscriptions() async {
    final subs = await _repo.getActiveSubscriptions();
    setState(() => _subscriptions = subs);
  }

  Future<void> _loadApiConfig() async {
    final config = await _apiRepo.loadConfig();
    _baseUrlCtrl.text = config['baseUrl'] ?? '';
    _endpointCtrl.text = config['endpointPath'] ?? '/api/movimientos';
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Suscripciones detectadas
          _sectionTitle('Suscripciones recurrentes'),
          const SizedBox(height: 8),
          if (_subscriptions.isEmpty)
            _emptyCard('No se han detectado suscripciones aún.\nSe detectan automáticamente al leer los SMS.')
          else
            ..._subscriptions.map((sub) => _subscriptionCard(sub)),

          const SizedBox(height: 24),

          // Sincronización API
          _sectionTitle('Sincronización con tu web'),
          const SizedBox(height: 8),
          _apiConfigCard(),

          const SizedBox(height: 24),

          // Info de la app
          _sectionTitle('Acerca de'),
          const SizedBox(height: 8),
          _infoCard(),

          const SizedBox(height: 24),

          // Privacidad
          _sectionTitle('Privacidad'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lock_outline, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    const Text('100% local y privado',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Los SMS se procesan localmente con regex, sin IA. '
                  'Solo se envian movimientos a tu API cuando configuras la sincronización. '
                  'La app no usa servicios de terceros.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title,
        style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5));
  }

  Widget _subscriptionCard(Subscription sub) {
    final daysLeft = sub.daysUntilNext;
    final isAlert = sub.isAlertActive;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAlert ? AppColors.warning.withOpacity(0.4) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isAlert ? AppColors.warning.withOpacity(0.1) : AppColors.primaryGlow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.autorenew,
              color: isAlert ? AppColors.warning : AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sub.name,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
                Text(
                  'Día ${sub.dayOfMonth} · ${sub.bank.label}${sub.cardLastFour != null ? ' *${sub.cardLastFour}' : ''}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
                if (sub.nextExpected != null)
                  Text(
                    'Próximo: ${DateFormat('dd/MM/yyyy').format(sub.nextExpected!)}${daysLeft >= 0 ? ' (en ${daysLeft}d)' : ''}',
                    style: TextStyle(
                        color: isAlert ? AppColors.warning : AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: isAlert ? FontWeight.w600 : FontWeight.normal),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('\$${sub.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
              const Text('/mes', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => _deactivateSubscription(sub),
                child: const Text('Desactivar',
                    style: TextStyle(color: AppColors.expense, fontSize: 10)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyCard(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(message,
          style: const TextStyle(
              color: AppColors.textMuted, fontSize: 13, height: 1.5)),
    );
  }

  Widget _infoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _infoRow('Versión', '1.0.0'),
          _infoRow('Bancos soportados', 'Agrícola, BAC, Davivienda, Cuscatlán'),
          _infoRow('Motor de parseo', 'Regex local (sin IA)'),
          _infoRow('Almacenamiento', 'SQLite local'),
          _infoRow('Sincronización', 'API REST configurable'),
          _infoRow('Desarrollado para', 'El Salvador 🇸🇻'),
        ],
      ),
    );
  }

  Widget _apiConfigCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Se envian solo movimientos del mes actual y solo pendientes.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _baseUrlCtrl,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Base URL API',
              hintText: 'https://tu-dominio.com',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _endpointCtrl,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Path endpoint',
              hintText: '/api/movimientos',
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _savingApiConfig ? null : _saveApiConfig,
              icon: _savingApiConfig
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text(_savingApiConfig ? 'Guardando...' : 'Guardar configuración API'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Future<void> _deactivateSubscription(Subscription sub) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Desactivar suscripción',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text('¿Desactivar alerta para ${sub.name}?',
            style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Desactivar', style: TextStyle(color: AppColors.expense)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _repo.deactivateSubscription(sub.id);
      _loadSubscriptions();
    }
  }

  Future<void> _saveApiConfig() async {
    final baseUrl = _baseUrlCtrl.text.trim();
    final endpointPath = _endpointCtrl.text.trim();

    if (baseUrl.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa Base URL'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _savingApiConfig = true);
    await _apiRepo.saveConfig(
      baseUrl: baseUrl,
      endpointPath: endpointPath,
    );
    if (!mounted) return;

    setState(() => _savingApiConfig = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Configuración API guardada'),
        backgroundColor: AppColors.primary,
      ),
    );
  }
}
