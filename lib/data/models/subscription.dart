// lib/data/models/subscription.dart

import 'transaction.dart';

class Subscription {
  final String id;
  final String name;
  final double amount;
  final String? cardLastFour;
  final Bank bank;
  final int dayOfMonth;      // Día estimado de cobro (1-31)
  final DateTime lastCharged;
  final DateTime? nextExpected;
  bool isActive;

  Subscription({
    required this.id,
    required this.name,
    required this.amount,
    this.cardLastFour,
    required this.bank,
    required this.dayOfMonth,
    required this.lastCharged,
    this.nextExpected,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'card_last_four': cardLastFour,
      'bank': bank.name,
      'day_of_month': dayOfMonth,
      'last_charged': lastCharged.toIso8601String(),
      'next_expected': nextExpected?.toIso8601String(),
      'is_active': isActive ? 1 : 0,
    };
  }

  factory Subscription.fromMap(Map<String, dynamic> map) {
    return Subscription(
      id: map['id'] as String,
      name: map['name'] as String,
      amount: (map['amount'] as num).toDouble(),
      cardLastFour: map['card_last_four'] as String?,
      bank: Bank.values.firstWhere(
        (b) => b.name == map['bank'],
        orElse: () => Bank.unknown,
      ),
      dayOfMonth: map['day_of_month'] as int,
      lastCharged: DateTime.parse(map['last_charged'] as String),
      nextExpected: map['next_expected'] != null
          ? DateTime.parse(map['next_expected'] as String)
          : null,
      isActive: (map['is_active'] as int) == 1,
    );
  }

  /// Calcula cuántos días faltan para el próximo cobro
  int get daysUntilNext {
    if (nextExpected == null) return -1;
    return nextExpected!.difference(DateTime.now()).inDays;
  }

  bool get isAlertActive => daysUntilNext >= 0 && daysUntilNext <= 3;
}
