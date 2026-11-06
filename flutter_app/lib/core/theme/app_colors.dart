import 'package:flutter/material.dart';

/// Paleta de colores extraída directamente de la aplicación de toma de fotos
/// de góndola, mapeada para compatibilidad con Material Design 3.
abstract class AppColors {
  // Brand & Header
  static const Color primaryPurple = Color(0xFF612680);
  static const Color primaryPurpleDark = Color(0xFF4A1C62);
  static const Color primaryPurpleLight = Color(0xFF7E36A3);

  // Botón Principal de Acción / Estado Listo para Fotografiar (Verde Esmeralda)
  static const Color primaryGreen = Color(0xFF0EBD6E);
  static const Color primaryGreenDark = Color(0xFF0A9E5B);
  static const Color primaryGreenLight = Color(0xFFE6F9F0);

  // Fondos y Superficies (Modo Claro Material 3)
  static const Color scaffoldBackground = Color(0xFFF4F3F8);
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color surfaceInput = Color(0xFFF9F8FC);
  static const Color borderSubtle = Color(0xFFE5DFEE);
  static const Color borderFocus = Color(0xFF612680);

  // Contenedores Secundarios y Pills
  static const Color lavenderContainer = Color(0xFFEDE7F6);
  static const Color lavenderBorder = Color(0xFFDCD2EE);

  // Estados del Lote
  // 1. Acumulado (Días no laborables / fines de semana)
  static const Color warningAmber = Color(0xFFEAB308);
  static const Color warningAmberDark = Color(0xFFB45309);
  static const Color warningContainer = Color(0xFFFEF9E7);
  static const Color warningBorder = Color(0xFFFDE68A);

  // 2. En Curso / Finalizar / Alerta Destructiva
  static const Color dangerRed = Color(0xFFE11D48);
  static const Color dangerRedDark = Color(0xFFBE123C);
  static const Color dangerContainer = Color(0xFFFEEBEF);
  static const Color dangerBorder = Color(0xFFFECDD3);

  // 3. Próximo en 7 días
  static const Color upcomingBlue = Color(0xFF6366F1);
  static const Color upcomingContainer = Color(0xFFEEF2FF);
  static const Color upcomingBorder = Color(0xFFC7D2FE);

  // Tipografía y Contraste
  static const Color textPrimary = Color(0xFF1E1B26);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textDim = Color(0xFF9CA3AF);
  static const Color textWhite = Color(0xFFFFFFFF);
}
