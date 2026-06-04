// lib/data/repositories/sms_parser.dart
//
// Parser de SMS bancarios salvadoreños usando regex puro.
// 100% offline, sin LLM, sin costo.
//
// Bancos soportados:
//   - Banco Agrícola
//   - BAC Credomatic
//   - Davivienda
//   - Banco Cuscatlán

import '../models/transaction.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class SmsParser {
  // ─────────────────────────────────────────────────────────────
  // PUNTO DE ENTRADA PRINCIPAL
  // ─────────────────────────────────────────────────────────────

  /// Intenta parsear un SMS bancario. Retorna null si no es reconocido.
  static Transaction? parse(String smsBody, {DateTime? receivedAt}) {
    final body = smsBody.trim();

    // Intentar cada banco en orden
    Transaction? result;
    result ??= _parseAgricola(body, receivedAt);
    result ??= _parseBac(body, receivedAt);
    result ??= _parseDavivienda(body, receivedAt);
    result ??= _parseCuscatlan(body, receivedAt);

    return result;
  }

  // ─────────────────────────────────────────────────────────────
  // BANCO AGRÍCOLA
  // Formato: "Compra aprobada por $45.00 con tarjeta *1234 en SUPER SELECTOS el 30/05/2026"
  // Formato2: "Agricola: Pago $12.50 tarjeta crédito *5678 FARMACIA 30/05/2026 14:30"
  // ─────────────────────────────────────────────────────────────

  static Transaction? _parseAgricola(String body, DateTime? receivedAt) {
    final isAgricola = body.toLowerCase().contains('agricola') ||
        body.toLowerCase().contains('agrícola') ||
        RegExp(r'compra aprobada', caseSensitive: false).hasMatch(body);

    if (!isAgricola) return null;

    final amount = _extractAmount(body);
    if (amount == null) return null;

    final card = _extractCard(body);
    final date = _extractDate(body) ?? receivedAt ?? DateTime.now();
    final merchant = _extractMerchantAgricola(body);
    final type = _detectType(body);
    final category = _categorize(merchant);

    return Transaction(
      id: _uuid.v4(),
      amount: amount,
      merchant: merchant,
      cardLastFour: card,
      date: date,
      bank: Bank.agricola,
      type: type,
      category: category,
      rawSms: body,
    );
  }

  static String _extractMerchantAgricola(String body) {
    // "compra ... en COMERCIO el"
    final pattern1 = RegExp(r'en\s+([A-ZÁÉÍÓÚÑ][A-ZÁÉÍÓÚÑ\s&.,\-]+?)\s+el\s+\d', caseSensitive: false);
    final m1 = pattern1.firstMatch(body);
    if (m1 != null) return _cleanMerchant(m1.group(1)!);

    // "en COMERCIO" al final
    final pattern2 = RegExp(r'en\s+([A-ZÁÉÍÓÚÑ][A-ZÁÉÍÓÚÑ\s&.,\-]+?)(?:\s+\d|$)', caseSensitive: false);
    final m2 = pattern2.firstMatch(body);
    if (m2 != null) return _cleanMerchant(m2.group(1)!);

    return 'Desconocido';
  }

  // ─────────────────────────────────────────────────────────────
  // BAC CREDOMATIC
  // Formato: "BAC: Tarjeta *5678 - Compra $23.50 en McDONALDS 30/05/2026 10:35"
  // Formato2: "BAC Credomatic: Cargo $15.00 tarjeta *1234 SPOTIFY 30/05/2026"
  // ─────────────────────────────────────────────────────────────

  static Transaction? _parseBac(String body, DateTime? receivedAt) {
    final isBac = RegExp(r'\bBAC\b', caseSensitive: false).hasMatch(body) ||
        body.toLowerCase().contains('credomatic');

    if (!isBac) return null;

    final amount = _extractAmount(body);
    if (amount == null) return null;

    final card = _extractCard(body);
    final date = _extractDate(body) ?? receivedAt ?? DateTime.now();
    final merchant = _extractMerchantBac(body);
    final type = _detectType(body);
    final category = _categorize(merchant);

    return Transaction(
      id: _uuid.v4(),
      amount: amount,
      merchant: merchant,
      cardLastFour: card,
      date: date,
      bank: Bank.bac,
      type: type,
      category: category,
      rawSms: body,
    );
  }

  static String _extractMerchantBac(String body) {
    // "en COMERCIO DATE"
    final p1 = RegExp(r'en\s+([A-ZÁÉÍÓÚÑA-Za-z][A-ZÁÉÍÓÚÑA-Za-z\s&.,\-]+?)\s+\d{2}[/\-]\d{2}', caseSensitive: false);
    final m1 = p1.firstMatch(body);
    if (m1 != null) return _cleanMerchant(m1.group(1)!);

    // Después del monto: "Compra $XX.XX COMERCIO"
    final p2 = RegExp(r'\$[\d,.]+\s+([A-ZÁÉÍÓÚÑ][A-ZÁÉÍÓÚÑ\s&]+?)(?:\s+\d{2}[/\-]|\s*$)', caseSensitive: false);
    final m2 = p2.firstMatch(body);
    if (m2 != null) return _cleanMerchant(m2.group(1)!);

    return 'Desconocido';
  }

  // ─────────────────────────────────────────────────────────────
  // DAVIVIENDA
  // Formato real confirmado:
  //   Davivienda Cargo
  //   Cta:530
  //   Cta.D.:COMPRA POS
  //   Concep:McDonald s APP
  //   Fec:30/05/26 17:04:31
  //   Monto:$14.35
  //   -Si NO la reconoce llamar al 25560000-
  // ─────────────────────────────────────────────────────────────

  static Transaction? _parseDavivienda(String body, DateTime? receivedAt) {
    if (!body.toLowerCase().contains('davivienda')) return null;

    final amount = _extractAmountDavivienda(body);
    if (amount == null) return null;

    final card = _extractAccountDavivienda(body);
    final date = _extractDateDavivienda(body) ?? receivedAt ?? DateTime.now();
    final merchant = _extractMerchantDavivienda(body);
    final type = _detectTypeDavivienda(body);
    final category = _categorize(merchant);

    return Transaction(
      id: _uuid.v4(),
      amount: amount,
      merchant: merchant,
      cardLastFour: card,
      date: date,
      bank: Bank.davivienda,
      type: type,
      category: category,
      rawSms: body,
    );
  }

  /// Extrae monto del campo "Monto:$14.35"
  static double? _extractAmountDavivienda(String body) {
    final p = RegExp(r'Monto:\s*\$\s*([\d,]+\.?\d{0,2})', caseSensitive: false);
    final m = p.firstMatch(body);
    if (m != null) return double.tryParse(m.group(1)!.replaceAll(',', ''));
    // fallback al extractor genérico
    return _extractAmount(body);
  }

  /// Extrae número de cuenta del campo "Cta:530" (últimos dígitos disponibles)
  static String? _extractAccountDavivienda(String body) {
    final p = RegExp(r'Cta:\s*(\d+)', caseSensitive: false);
    final m = p.firstMatch(body);
    if (m != null) {
      final digits = m.group(1)!;
      // Retornar los últimos 4 dígitos si hay suficientes, o todos si son menos
      return digits.length >= 4 ? digits.substring(digits.length - 4) : digits;
    }
    return null;
  }

  /// Extrae comercio del campo "Concep:McDonald s APP"
  static String _extractMerchantDavivienda(String body) {
    final p = RegExp(r'Concep:\s*(.+?)(?:\n|Fec:|Monto:|$)', caseSensitive: false);
    final m = p.firstMatch(body);
    if (m != null) return _cleanMerchant(m.group(1)!.trim());

    // Fallback: buscar después de "Cta.D.:" si Concep no existe
    final p2 = RegExp(r'Cta\.D\.:\s*(.+?)(?:\n|Concep:|Fec:|$)', caseSensitive: false);
    final m2 = p2.firstMatch(body);
    if (m2 != null) return _cleanMerchant(m2.group(1)!.trim());

    return 'Desconocido';
  }

  /// Extrae fecha del campo "Fec:30/05/26 17:04:31"
  static DateTime? _extractDateDavivienda(String body) {
    // Formato "Fec:DD/MM/YY HH:mm:ss" o "Fec:DD/MM/YYYY"
    final p = RegExp(r'Fec:\s*(\d{2})[/\-](\d{2})[/\-](\d{2,4})\s*(\d{2}:\d{2}:\d{2})?', caseSensitive: false);
    final m = p.firstMatch(body);
    if (m == null) return _extractDate(body);

    try {
      final day   = int.parse(m.group(1)!);
      final month = int.parse(m.group(2)!);
      var year    = int.parse(m.group(3)!);
      // Año de 2 dígitos → agregar siglo
      if (year < 100) year += 2000;

      int hour = 0, minute = 0, second = 0;
      if (m.group(4) != null) {
        final timeParts = m.group(4)!.split(':');
        hour   = int.parse(timeParts[0]);
        minute = int.parse(timeParts[1]);
        second = int.parse(timeParts[2]);
      }
      return DateTime(year, month, day, hour, minute, second);
    } catch (_) {
      return null;
    }
  }

  /// Detecta tipo de transacción desde "Cargo", "Abono", "COMPRA POS"
  static TransactionType _detectTypeDavivienda(String body) {
    final lower = body.toLowerCase();
    if (lower.contains('abono') || lower.contains('deposito') || lower.contains('depósito')) {
      return TransactionType.credit;
    }
    if (lower.contains('transferencia') || lower.contains('transfer')) {
      return TransactionType.transfer;
    }
    // "Cargo" y "COMPRA POS" son débitos
    return TransactionType.debit;
  }

  // ─────────────────────────────────────────────────────────────
  // BANCO CUSCATLÁN
  // Formato: "Cuscatlan: Consumo $67.80 Tarjeta Crédito *3456 WALMART 30/05/2026"
  // Formato2: "Cuscatlan: Compra aprobada $34.00 en PIZZA HUT tarjeta *7890"
  // ─────────────────────────────────────────────────────────────

  static Transaction? _parseCuscatlan(String body, DateTime? receivedAt) {
    final isCuscatlan = body.toLowerCase().contains('cuscatlan') ||
        body.toLowerCase().contains('cuscatlán');

    if (!isCuscatlan) return null;

    final amount = _extractAmount(body);
    if (amount == null) return null;

    final card = _extractCard(body);
    final date = _extractDate(body) ?? receivedAt ?? DateTime.now();
    final merchant = _extractMerchantCuscatlan(body);
    final type = _detectType(body);
    final category = _categorize(merchant);

    return Transaction(
      id: _uuid.v4(),
      amount: amount,
      merchant: merchant,
      cardLastFour: card,
      date: date,
      bank: Bank.cuscatlan,
      type: type,
      category: category,
      rawSms: body,
    );
  }

  static String _extractMerchantCuscatlan(String body) {
    // Después de *XXXX — el texto que sigue es el comercio
    final p1 = RegExp(r'\*\d{4}\s+([A-ZÁÉÍÓÚÑ][A-ZÁÉÍÓÚÑ\s&.,\-]+?)(?:\s+\d{2}[/\-]|\s*$)', caseSensitive: false);
    final m1 = p1.firstMatch(body);
    if (m1 != null) return _cleanMerchant(m1.group(1)!);

    // "en COMERCIO"
    final p2 = RegExp(r'en\s+([A-ZÁÉÍÓÚÑ][A-ZÁÉÍÓÚÑ\s&.,\-]+?)(?:\s+tarjeta|\s+\d|\s*$)', caseSensitive: false);
    final m2 = p2.firstMatch(body);
    if (m2 != null) return _cleanMerchant(m2.group(1)!);

    return 'Desconocido';
  }

  // ─────────────────────────────────────────────────────────────
  // HELPERS COMPARTIDOS
  // ─────────────────────────────────────────────────────────────

  /// Extrae monto: $45.00, $1,234.56, $1234
  static double? _extractAmount(String body) {
    final pattern = RegExp(r'\$\s*([\d,]+\.?\d{0,2})');
    final match = pattern.firstMatch(body);
    if (match == null) return null;

    final raw = match.group(1)!.replaceAll(',', '');
    return double.tryParse(raw);
  }

  /// Extrae últimos 4 dígitos: *1234, terminación 1234
  static String? _extractCard(String body) {
    final pattern = RegExp(r'\*(\d{4})');
    final match = pattern.firstMatch(body);
    return match?.group(1);
  }

  /// Extrae fecha: DD/MM/YYYY o DD-MM-YYYY
  static DateTime? _extractDate(String body) {
    final pattern = RegExp(r'(\d{2})[/\-](\d{2})[/\-](\d{4})');
    final match = pattern.firstMatch(body);
    if (match == null) return null;

    try {
      final day = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      final year = int.parse(match.group(3)!);
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  /// Detecta si es débito, crédito o transferencia
  static TransactionType _detectType(String body) {
    final lower = body.toLowerCase();
    if (lower.contains('transferencia') || lower.contains('transfer')) {
      return TransactionType.transfer;
    }
    if (lower.contains('crédito') ||
        lower.contains('credito') ||
        lower.contains('credit')) {
      return TransactionType.credit;
    }
    return TransactionType.debit;
  }

  /// Limpia espacios extras del nombre del comercio
  static String _cleanMerchant(String raw) {
    return raw.trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase();
  }

  // ─────────────────────────────────────────────────────────────
  // CATEGORIZACIÓN POR PALABRAS CLAVE
  // ─────────────────────────────────────────────────────────────

  /// Mapa de palabras clave → categoría
  static const Map<Category, List<String>> _categoryKeywords = {
    Category.supermarket: [
      'walmart', 'super selectos', 'selectos', 'la colonia',
      'pricesmart', 'price smart', 'súper', 'super', 'despensa',
      'hiper', 'mercado', 'colonia', 'maxi despensa',
    ],
    Category.restaurant: [
      'mcdonald', 'mcdonalds', "mcdonald's", 'burger king', 'subway',
      'pizza hut', 'kfc', 'pollo campero', 'dominos', "domino's",
      'wendys', "wendy's", 'little caesars', 'starbucks', 'restaurant',
      'restaurante', 'comida', 'sushi', 'tacos', 'cafeteria', 'cafetería',
      'food court', 'pupuseria', 'asados', 'mariscos',
    ],
    Category.fuel: [
      'puma', 'shell', 'uno energía', 'texaco', 'gasolinera',
      'combustible', 'gasolina', 'diesel', 'esso',
    ],
    Category.pharmacy: [
      'farmacia', 'san nicolas', 'san nicolás', 'farmacias económicas',
      'farmacias magistral', 'medco', 'drogueria', 'droguería',
    ],
    Category.entertainment: [
      'netflix', 'spotify', 'youtube', 'disney', 'amazon prime',
      'hbo', 'apple', 'google play', 'steam', 'xbox', 'playstation',
      'cines', 'cinemark', 'imax', 'multiplex',
    ],
    Category.health: [
      'medico', 'médico', 'clinica', 'clínica', 'hospital', 'laboratorio',
      'laboratorios', 'dentista', 'optica', 'óptica', 'consulta',
    ],
    Category.services: [
      'aes', 'anda', 'tigo', 'claro', 'movistar', 'digicel',
      'internet', 'cable', 'telefonia', 'telefonía', 'luz', 'agua',
      'alcaldía', 'alcaldia', 'impuesto',
    ],
    Category.shopping: [
      'zara', 'h&m', 'amazon', 'ebay', 'adidas', 'nike',
      'tienda', 'store', 'shop', 'moda', 'ropa', 'calzado',
      'joyeria', 'joyería', 'bazar',
    ],
    Category.transfer: [
      'transferencia', 'transfer', 'envio', 'envío', 'depósito', 'deposito',
    ],
  };

  /// Categoriza un comercio basado en palabras clave
  static Category _categorize(String merchant) {
    final lower = merchant.toLowerCase();

    for (final entry in _categoryKeywords.entries) {
      for (final keyword in entry.value) {
        if (lower.contains(keyword)) {
          return entry.key;
        }
      }
    }

    return Category.other;
  }

  // ─────────────────────────────────────────────────────────────
  // DETECCIÓN DE SUSCRIPCIONES RECURRENTES
  // ─────────────────────────────────────────────────────────────

  static const List<String> _subscriptionKeywords = [
    'netflix', 'spotify', 'youtube premium', 'disney+', 'hbo max',
    'amazon prime', 'apple music', 'icloud', 'google one',
    'office 365', 'microsoft 365', 'adobe', 'dropbox',
  ];

  static bool isLikelySubscription(String merchant) {
    final lower = merchant.toLowerCase();
    return _subscriptionKeywords.any((kw) => lower.contains(kw));
  }
}
