import 'package:flutter/material.dart';

class AppColors {
  // Industrial High-Visibility Safety Accent
  static const Color primary = Color(0xFFD9531E); // Terracotta Safety Orange
  static const Color primaryDark = Color(0xFFB83E0E);
  static const Color primaryLight = Color(0xFFFFF3ED);

  // High-Contrast Sunlight Neutral Surfaces
  static const Color background = Color(0xFFF7F8FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0);
  static const Color divider = Color(0xFFEDF2F7);

  // Status Colors (Peruvian Technical Standards)
  static const Color conforme = Color(0xFF22543D); // Forest Green
  static const Color conformeBg = Color(0xFFC6F6D5);

  static const Color noConforme = Color(0xFF9B2C2C); // Crimson Defect
  static const Color noConformeBg = Color(0xFFFED7D7);

  static const Color warning = Color(0xFF975A16); // Amber Warning
  static const Color warningBg = Color(0xFFFEEBC8);

  static const Color info = Color(0xFF2B6CB0);
  static const Color infoBg = Color(0xFFBEE3F8);

  // Typography Tokens
  static const Color textMain = Color(0xFF1A202C);
  static const Color textMuted = Color(0xFF4A5568);
  static const Color textSecondary = Color(0xFF718096);
}

class AppDimensions {
  // Minimum 48px Touch Targets for Field Gloves
  static const double minTouchTarget = 48.0;
  static const double buttonHeight = 52.0;
  static const double inputHeight = 50.0;
  
  static const double paddingS = 8.0;
  static const double paddingM = 16.0;
  static const double paddingL = 24.0;

  static const double radiusS = 6.0;
  static const double radiusM = 10.0;
}

class AppConstants {
  static const String appTitle = 'Protokol QC';
  static const String appSubtitle = 'Control de Calidad en Obra';
  static const String defaultApiUrl = 'http://localhost:4000/api';
}
