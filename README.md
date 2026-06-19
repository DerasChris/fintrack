# 💳 FinTrack SV — Gestor Financiero Personal

Aplicación Flutter para leer SMS bancarios salvadoreños,
categorizar gastos automáticamente, generar reportes mensuales y sincronizar movimientos a una API propia.

**Parser local (sin IA) + sincronización opcional a tu backend.**

---

## 🏦 Bancos Soportados

| Banco | Débito | Crédito | Transferencias |
|---|---|---|---|
| Banco Agrícola | ✅ | ✅ | ✅ |
| BAC Credomatic | ✅ | ✅ | ✅ |
| Davivienda | ✅ | ✅ | ✅ |
| Banco Cuscatlán | ✅ | ✅ | ✅ |

---

## 📋 Requisitos Previos

### Software
- [Flutter SDK](https://flutter.dev/docs/get-started/install) >= 3.22.0
- [Android Studio](https://developer.android.com/studio) o VS Code con extensión Flutter
- [VS Code Extensions](https://marketplace.visualstudio.com/items?itemName=Dart-Code.flutter):
  - Dart
  - Flutter
  - Flutter Widget Snippets (opcional)

### Hardware
- Android físico **Samsung Galaxy** (para leer SMS reales del Galaxy Watch)
- Cable USB + modo desarrollador activado en el teléfono

### Activar Modo Desarrollador en Samsung
1. Ajustes → Acerca del teléfono → Información de software
2. Toca **Número de compilación** 7 veces
3. Ajustes → Opciones de desarrollador → Depuración USB ✅

---

## 🚀 Instalación Rápida

```bash
# 1. Clonar o descomprimir el proyecto
cd fintrack_sv

# 2. Instalar dependencias
flutter pub get

# 3. Verificar entorno
flutter doctor

# 4. Conectar teléfono Samsung por USB y ejecutar
flutter run

# Para build APK de producción
flutter build apk --release
# APK generado en: build/app/outputs/flutter-apk/app-release.apk
```

---

## 📁 Estructura del Proyecto

```
fintrack_sv/
├── lib/
│   ├── main.dart                          # Entry point
│   ├── core/
│   │   ├── constants/
│   │   │   └── app_constants.dart         # Strings, keys, configs
│   │   ├── theme/
│   │   │   └── app_theme.dart             # Colores, tipografía, estilos
│   │   └── utils/
│   │       └── currency_formatter.dart    # Formateo de montos USD
│   ├── data/
│   │   ├── models/
│   │   │   ├── transaction.dart           # Modelo de transacción
│   │   │   └── subscription.dart         # Modelo de suscripción recurrente
│   │   └── repositories/
│   │       ├── sms_parser.dart            # 🧠 Parser regex por banco
│   │       ├── transaction_repository.dart # CRUD SQLite
│   │       └── sms_repository.dart        # Lectura de SMS del teléfono
│   └── features/
│       ├── dashboard/
│       │   ├── screens/dashboard_screen.dart
│       │   ├── widgets/
│       │   │   ├── balance_card.dart
│       │   │   ├── recent_transactions.dart
│       │   │   └── spending_chart.dart
│       │   └── providers/dashboard_provider.dart
│       ├── transactions/
│       │   ├── screens/transactions_screen.dart
│       │   └── widgets/transaction_tile.dart
│       ├── reports/
│       │   └── screens/reports_screen.dart
│       └── settings/
│           └── screens/settings_screen.dart
├── android/
│   └── app/
│       └── src/main/
│           └── AndroidManifest.xml        # ⚠️ Permisos SMS aquí
├── pubspec.yaml                           # Dependencias Flutter
└── README.md
```

---

## 📦 Dependencias (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Lectura de SMS
  telephony: ^0.2.0
  permission_handler: ^11.3.1
  
  # Base de datos local
  sqflite: ^2.3.3+1
  path: ^1.9.0
  
  # Gestión de estado
  provider: ^6.1.2
  
  # UI / Gráficas
  fl_chart: ^0.68.0
  
  # Exportar PDF
  pdf: ^3.11.1
  printing: ^5.13.1
  
  # Utilidades
  intl: ^0.19.0
  shared_preferences: ^2.3.2
  uuid: ^4.4.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
```

---

## 🔑 Permisos Android (AndroidManifest.xml)

```xml
<!-- Dentro de <manifest> pero FUERA de <application> -->
<uses-permission android:name="android.permission.READ_SMS" />
<uses-permission android:name="android.permission.RECEIVE_SMS" />
<uses-permission android:name="android.permission.READ_CONTACTS" />
```

---

## 🧠 Cómo Funciona el Parser de SMS

El corazón de la app. Cada banco tiene patrones diferentes:

```
SMS Banco Agrícola ejemplo:
"Compra aprobada por $45.00 con tarjeta *1234 en SUPER SELECTOS el 30/05/2026"

SMS BAC Credomatic ejemplo:
"BAC: Tarjeta *5678 - Compra $23.50 en McDONALDS 30/05/2026 10:35"

SMS Davivienda (formato real, multilinea):
"Davivienda Cargo
Cta:530
Cta.D.:COMPRA POS
Concep:McDonald s APP
Fec:30/05/26 17:04:31
Monto:$14.35
-Si NO la reconoce llamar al 25560000-"

SMS Cuscatlán ejemplo:
"Cuscatlan: Consumo $67.80 Tarjeta Crédito *3456 WALMART 30/05/2026"
```

El parser extrae automáticamente:
- 💵 **Monto** — regex `\$[\d,]+\.?\d{0,2}`
- 🏪 **Comercio** — regex por banco
- 💳 **Últimos 4 dígitos** — regex `\*(\d{4})`
- 📅 **Fecha** — regex `\d{2}/\d{2}/\d{4}`
- 🏷️ **Categoría** — lookup table por palabras clave del comercio

---

## 🏷️ Categorías Automáticas

| Categoría | Comercios detectados |
|---|---|
| 🛒 Supermercado | Walmart, Selectos, La Colonia, PriceSmart |
| 🍔 Restaurantes | McDonald's, Subway, Pizza Hut, KFC |
| ⛽ Combustible | Puma, Shell, Uno, Texaco |
| 💊 Farmacia | Farmacia San Nicolás, Farmacias Económicas |
| 🎬 Entretenimiento | Netflix, Spotify, YouTube, Disney+ |
| 🏥 Salud | Médicos, Laboratorios, Clínicas |
| 🛍️ Compras | Zara, H&M, Amazon, tiendas generales |
| 💡 Servicios | AES, ANDA, Tigo, Claro, Movistar |
| ❓ Otros | Sin categoría detectada |

---

## 📊 Funcionalidades

### Dashboard
- Resumen del mes actual (gastos totales, por categoría)
- Últimas 5 transacciones
- Gráfica de dona por categoría

### Transacciones
- Lista completa filtrable por fecha/banco/categoría
- Edición manual de categoría
- Búsqueda por comercio

### Reportes Mensuales
- Comparativo mes a mes
- Gráfica de barras por semana
- Export a PDF

### Alertas de Suscripciones
- Detección automática de cobros recurrentes (Netflix, Spotify, etc.)
- Notificación 3 días antes del cobro estimado
- Lista de suscripciones activas con monto mensual

---

## 🔧 Inyectar SMS de Prueba (Emulador)

Si usas emulador de Android Studio en lugar del Samsung físico:

```bash
# En terminal, con emulador corriendo
adb emu sms send 503-AGRICOLA "Compra aprobada por $45.00 con tarjeta *1234 en SUPER SELECTOS el 30/05/2026"

adb emu sms send 503-BAC "BAC: Tarjeta *5678 - Compra $23.50 en McDONALDS 30/05/2026 10:35"

adb emu sms send 503-DAVIVIENDA "Davivienda Cargo\nCta:530\nCta.D.:COMPRA POS\nConcep:McDonald s APP\nFec:30/05/26 17:04:31\nMonto:\$14.35\n-Si NO la reconoce llamar al 25560000-"
```

---

## 📱 Galaxy Watch 7 — Aclaración Técnica

El Galaxy Watch **no almacena SMS** — los refleja desde el teléfono Samsung.
La app lee directamente del teléfono, y el watch muestra las notificaciones automáticamente desde Galaxy Wearable. **No se requiere desarrollo adicional para el watch.**

---

## 🗺️ Roadmap

- [x] Fase 1 — Parser SMS 4 bancos
- [x] Fase 2 — CRUD SQLite local
- [x] Fase 3 — Dashboard + gráficas
- [x] Fase 4 — Reportes PDF
- [ ] Fase 5 — Widget para pantalla de inicio
- [ ] Fase 6 — Backup/Restore local (sin cloud)
- [ ] Fase 7 — Soporte Promerica + Banco de América Central

---

## ⚠️ Privacidad

Todos los datos permanecen **exclusivamente en el dispositivo**.
Ninguna información se envía a servidores externos.
Los SMS se procesan en memoria y solo el resultado estructurado se guarda en SQLite.

---

*Desarrollado para El Salvador 🇸🇻 — USD nativo, formato centroamericano*
