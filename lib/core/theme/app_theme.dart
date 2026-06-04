// lib/core/theme/app_theme.dart

import 'package:flutter/material.dart';

class AppColors {
  // Paleta principal — dark financial
  static const background   = Color(0xFF0D1117);
  static const surface      = Color(0xFF161B22);
  static const surfaceHigh  = Color(0xFF21262D);
  static const border       = Color(0xFF30363D);

  // Acento principal — verde financiero
  static const primary      = Color(0xFF00D395);
  static const primaryDark  = Color(0xFF00A371);
  static const primaryGlow  = Color(0x2200D395);

  // Acento secundario — azul
  static const accent       = Color(0xFF58A6FF);

  // Estados
  static const income       = Color(0xFF00D395);  // verde
  static const expense      = Color(0xFFFF6B6B);  // rojo suave
  static const warning      = Color(0xFFFFAB00);  // ámbar

  // Texto
  static const textPrimary   = Color(0xFFE6EDF3);
  static const textSecondary = Color(0xFF8B949E);
  static const textMuted     = Color(0xFF484F58);

  // Bancos
  static const agricola    = Color(0xFF006FB9);
  static const bac         = Color(0xFFE63329);
  static const davivienda  = Color(0xFFCC0000);
  static const cuscatlan   = Color(0xFF003087);

  // Categorías
  static const catSupermarket   = Color(0xFF4CAF50);
  static const catRestaurant    = Color(0xFFFF7043);
  static const catFuel          = Color(0xFFFFEB3B);
  static const catPharmacy      = Color(0xFF26C6DA);
  static const catEntertainment = Color(0xFF7C4DFF);
  static const catHealth        = Color(0xFFEC407A);
  static const catShopping      = Color(0xFFFF9800);
  static const catServices      = Color(0xFF29B6F6);
  static const catTransfer      = Color(0xFF78909C);
  static const catOther         = Color(0xFF9E9E9E);
}

class AppTheme {
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.surface,
        primary: AppColors.primary,
        secondary: AppColors.accent,
        error: AppColors.expense,
        onSurface: AppColors.textPrimary,
        onPrimary: Colors.black,
      ),
      fontFamily: 'Roboto',

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          letterSpacing: -0.3,
        ),
      ),

      // Cards
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
      ),

      // Bottom Nav
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primaryGlow,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ),

      // Dividers
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),

      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textMuted),
      ),

      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceHigh,
        selectedColor: AppColors.primaryGlow,
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
      ),

      // Floating Action Button
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
      ),

      textTheme: const TextTheme(
        displayLarge: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        headlineLarge: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 28),
        headlineMedium: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 22),
        titleLarge: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 18),
        titleMedium: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500, fontSize: 16),
        bodyLarge: TextStyle(color: AppColors.textPrimary, fontSize: 15),
        bodyMedium: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        labelLarge: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 14),
      ),
    );
  }
}

/// Retorna el color asociado a cada categoría
Color categoryColor(dynamic category) {
  switch (category.toString().split('.').last) {
    case 'supermarket':   return AppColors.catSupermarket;
    case 'restaurant':    return AppColors.catRestaurant;
    case 'fuel':          return AppColors.catFuel;
    case 'pharmacy':      return AppColors.catPharmacy;
    case 'entertainment': return AppColors.catEntertainment;
    case 'health':        return AppColors.catHealth;
    case 'shopping':      return AppColors.catShopping;
    case 'services':      return AppColors.catServices;
    case 'transfer':      return AppColors.catTransfer;
    default:              return AppColors.catOther;
  }
}

/// Retorna el color del banco
Color bankColor(dynamic bank) {
  switch (bank.toString().split('.').last) {
    case 'agricola':   return AppColors.agricola;
    case 'bac':        return AppColors.bac;
    case 'davivienda': return AppColors.davivienda;
    case 'cuscatlan':  return AppColors.cuscatlan;
    default:           return AppColors.textMuted;
  }
}
