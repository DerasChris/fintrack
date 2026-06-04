// lib/features/transactions/widgets/transaction_tile.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/transaction.dart';

class TransactionTile extends StatelessWidget {
  final Transaction transaction;
  final Function(Category) onCategoryChanged;

  const TransactionTile({
    super.key,
    required this.transaction,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    final color = categoryColor(t.category);
    final bColor = bankColor(t.bank);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              _categoryEmoji(t.category),
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                t.merchant,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Editado manualmente
            if (t.isManuallyEdited)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.edit, size: 12, color: AppColors.textMuted),
              ),
          ],
        ),
        subtitle: Row(
          children: [
            // Banco badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: bColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _bankShort(t.bank),
                style: TextStyle(color: bColor, fontSize: 9, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 6),
            // Tarjeta
            if (t.cardLastFour != null)
              Text('*${t.cardLastFour}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            const SizedBox(width: 6),
            // Fecha
            Text(
              DateFormat('dd MMM', 'es').format(t.date),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\$${t.amount.toStringAsFixed(2)}',
              style: const TextStyle(
                  color: AppColors.expense,
                  fontSize: 15,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            GestureDetector(
              onTap: () => _showCategoryPicker(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  t.category.label,
                  style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCategoryPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Cambiar categoría',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16)),
            ),
            const Divider(color: AppColors.border, height: 1),
            Expanded(
              child: ListView(
                children: Category.values.map((cat) {
                  final color = categoryColor(cat);
                  final isSelected = cat == transaction.category;
                  return ListTile(
                    leading: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(child: Text(_categoryEmoji(cat), style: const TextStyle(fontSize: 18))),
                    ),
                    title: Text(cat.label,
                        style: TextStyle(
                            color: isSelected ? color : AppColors.textPrimary,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: color, size: 20)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      onCategoryChanged(cat);
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _categoryEmoji(Category cat) {
    switch (cat) {
      case Category.supermarket:   return '🛒';
      case Category.restaurant:    return '🍔';
      case Category.fuel:          return '⛽';
      case Category.pharmacy:      return '💊';
      case Category.entertainment: return '🎬';
      case Category.health:        return '🏥';
      case Category.shopping:      return '🛍️';
      case Category.services:      return '💡';
      case Category.transfer:      return '🔄';
      case Category.other:         return '❓';
    }
  }

  static String _bankShort(Bank bank) {
    switch (bank) {
      case Bank.agricola:   return 'AGR';
      case Bank.bac:        return 'BAC';
      case Bank.davivienda: return 'DAV';
      case Bank.cuscatlan:  return 'CUS';
      case Bank.unknown:    return '???';
    }
  }
}
