// lib/data/repositories/sms_repository.dart
//
// Lee SMS del inbox del dispositivo Android usando flutter_sms_inbox.
// Filtra solo los mensajes de bancos reconocidos y los parsea.

import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/transaction.dart';
import '../models/subscription.dart';
import 'sms_parser.dart';
import 'transaction_repository.dart';

class SmsRepository {
  final SmsQuery _query = SmsQuery();
  final TransactionRepository _db;

  SmsRepository(this._db);

  // ─────────────────────────────────────────────────────────────
  // PERMISOS
  // ─────────────────────────────────────────────────────────────

  Future<bool> requestSmsPermission() async {
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  Future<bool> hasSmsPermission() async {
    return await Permission.sms.isGranted;
  }

  Future<bool> isPermissionPermanentlyDenied() async {
    return await Permission.sms.isPermanentlyDenied;
  }

  Future<void> openSettings() async {
    await openAppSettings();
  }

  // ─────────────────────────────────────────────────────────────
  // LECTURA INICIAL — escanea el inbox completo
  // ─────────────────────────────────────────────────────────────

  /// Escanea todos los SMS del inbox y retorna las transacciones nuevas.
  /// Evita duplicados usando hash del SMS.
  Future<List<Transaction>> scanInbox() async {
    if (!await hasSmsPermission()) {
      throw Exception('Permiso de SMS no concedido');
    }

    final smsList = await _query.querySms(
      kinds: [SmsQueryKind.inbox],
    );

    // Ordenar por fecha descendente
    smsList.sort((a, b) =>
        (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)));

    final List<Transaction> results = [];
    final now = DateTime.now();
    // ignore: avoid_print
    print('[SMS] Total SMS en inbox: ${smsList.length}');

    for (final sms in smsList) {
      final body = sms.body;
      if (body == null || body.isEmpty) continue;

      final smsDate = sms.date;
      // ignore: avoid_print
      print('[SMS] from=${sms.address} date=$smsDate body_preview=${body.replaceAll('\n', '|').substring(0, body.length.clamp(0, 80))}');

      if (smsDate == null || smsDate.year != now.year || smsDate.month != now.month) {
        // ignore: avoid_print
        print('[SMS] ❌ filtrado por mes (smsDate=$smsDate, now=$now)');
        continue;
      }

      if (!_looksLikeBankSms(body)) {
        // ignore: avoid_print
        print('[SMS] ❌ no parece bancario');
        continue;
      }

      // ignore: avoid_print
      print('[SMS] ✅ bancario detectado, parseando...');

      if (await _db.isSmsAlreadyProcessed(body)) {
        // ignore: avoid_print
        print('[SMS] ⚠️ duplicado, ya procesado');
        continue;
      }

      final transaction = SmsParser.parse(body, receivedAt: sms.date);
      // ignore: avoid_print
      print('[SMS] parse resultado: ${transaction == null ? "null (no mapeó)" : "OK amount=${transaction.amount} merchant=${transaction.merchant}"}');

      if (transaction != null) {
        await _db.insertTransaction(transaction);
        await _db.markSmsAsProcessed(body);

        // Detectar y registrar suscripciones
        if (SmsParser.isLikelySubscription(transaction.merchant)) {
          await _detectSubscription(transaction);
        }

        results.add(transaction);
      }
    }

    return results;
  }

  // ─────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────

  /// Filtro rápido para descartar SMS que claramente no son bancarios
  bool _looksLikeBankSms(String body) {
    final lower = body.toLowerCase();
    return lower.contains('agricola') ||
        lower.contains('agrícola') ||
        lower.contains('bac') ||
        lower.contains('credomatic') ||
        lower.contains('davivienda') ||
        lower.contains('cuscatlan') ||
        lower.contains('cuscatlán') ||
        lower.contains('compra aprobada') ||
        (lower.contains('\$') && lower.contains('tarjeta'));
  }

  /// Detecta y registra suscripciones recurrentes
  Future<void> _detectSubscription(Transaction t) async {
    final sub = Subscription(
      id: t.merchant.toLowerCase().replaceAll(' ', '_'),
      name: t.merchant,
      amount: t.amount,
      cardLastFour: t.cardLastFour,
      bank: t.bank,
      dayOfMonth: t.date.day,
      lastCharged: t.date,
      nextExpected: DateTime(
        t.date.month == 12 ? t.date.year + 1 : t.date.year,
        t.date.month == 12 ? 1 : t.date.month + 1,
        t.date.day,
      ),
      isActive: true,
    );

    await _db.upsertSubscription(sub);
  }
}
