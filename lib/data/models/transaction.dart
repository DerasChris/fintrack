// lib/data/models/transaction.dart

enum TransactionType { credit, debit, transfer }

enum Bank { agricola, bac, davivienda, cuscatlan, unknown }

enum Category {
  supermarket,
  restaurant,
  fuel,
  pharmacy,
  entertainment,
  health,
  shopping,
  services,
  transfer,
  other,
}

extension CategoryLabel on Category {
  String get label {
    switch (this) {
      case Category.supermarket:   return '🛒 Supermercado';
      case Category.restaurant:    return '🍔 Restaurantes';
      case Category.fuel:          return '⛽ Combustible';
      case Category.pharmacy:      return '💊 Farmacia';
      case Category.entertainment: return '🎬 Entretenimiento';
      case Category.health:        return '🏥 Salud';
      case Category.shopping:      return '🛍️ Compras';
      case Category.services:      return '💡 Servicios';
      case Category.transfer:      return '🔄 Transferencia';
      case Category.other:         return '❓ Otros';
    }
  }

  String get key => name;
}

extension BankLabel on Bank {
  String get label {
    switch (this) {
      case Bank.agricola:   return 'Banco Agrícola';
      case Bank.bac:        return 'BAC Credomatic';
      case Bank.davivienda: return 'Davivienda';
      case Bank.cuscatlan:  return 'Banco Cuscatlán';
      case Bank.unknown:    return 'Desconocido';
    }
  }
}

class Transaction {
  final String id;
  final double amount;
  final String merchant;
  final String? cardLastFour;
  final DateTime date;
  final Bank bank;
  final TransactionType type;
  Category category;
  final String rawSms;
  final bool isManuallyEdited;
  final String? notes;

  Transaction({
    required this.id,
    required this.amount,
    required this.merchant,
    this.cardLastFour,
    required this.date,
    required this.bank,
    required this.type,
    required this.category,
    required this.rawSms,
    this.isManuallyEdited = false,
    this.notes,
  });

  Transaction copyWith({
    String? id,
    double? amount,
    String? merchant,
    String? cardLastFour,
    DateTime? date,
    Bank? bank,
    TransactionType? type,
    Category? category,
    String? rawSms,
    bool? isManuallyEdited,
    String? notes,
  }) {
    return Transaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      merchant: merchant ?? this.merchant,
      cardLastFour: cardLastFour ?? this.cardLastFour,
      date: date ?? this.date,
      bank: bank ?? this.bank,
      type: type ?? this.type,
      category: category ?? this.category,
      rawSms: rawSms ?? this.rawSms,
      isManuallyEdited: isManuallyEdited ?? this.isManuallyEdited,
      notes: notes ?? this.notes,
    );
  }

  /// Serializa a Map para SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'merchant': merchant,
      'card_last_four': cardLastFour,
      'date': date.toIso8601String(),
      'bank': bank.name,
      'type': type.name,
      'category': category.name,
      'raw_sms': rawSms,
      'is_manually_edited': isManuallyEdited ? 1 : 0,
      'notes': notes,
    };
  }

  /// Deserializa desde SQLite
  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] as String,
      amount: (map['amount'] as num).toDouble(),
      merchant: map['merchant'] as String,
      cardLastFour: map['card_last_four'] as String?,
      date: DateTime.parse(map['date'] as String),
      bank: Bank.values.firstWhere(
        (b) => b.name == map['bank'],
        orElse: () => Bank.unknown,
      ),
      type: TransactionType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => TransactionType.debit,
      ),
      category: Category.values.firstWhere(
        (c) => c.name == map['category'],
        orElse: () => Category.other,
      ),
      rawSms: map['raw_sms'] as String,
      isManuallyEdited: (map['is_manually_edited'] as int) == 1,
      notes: map['notes'] as String?,
    );
  }

  @override
  String toString() =>
      'Transaction(id: $id, amount: \$$amount, merchant: $merchant, bank: ${bank.label}, date: $date)';
}
