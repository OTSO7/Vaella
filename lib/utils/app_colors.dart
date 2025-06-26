// lib/utils/app_colors.dart
import 'package:flutter/material.dart';

class AppColors {
  static Color primaryColor(BuildContext context) =>
      Theme.of(context).colorScheme.primary; // Typically Teal.shade400
  static Color onPrimaryColor(BuildContext context) =>
      Theme.of(context).colorScheme.onPrimary; // Typically Black

  static Color accentColor(BuildContext context) =>
      Theme.of(context).colorScheme.secondary; // Typically Orange.shade400
  static Color onAccentColor(BuildContext context) =>
      Theme.of(context).colorScheme.onSecondary; // Typically Black

  static Color backgroundColor(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor; // Typically 0xFF1A1A1A
  static Color cardColor(BuildContext context) =>
      Theme.of(context).cardColor; // Typically 0xFF2C2C2C
  static Color onCardColor(BuildContext context) => Theme.of(context)
      .colorScheme
      .onSurface; // Typically white.withOpacity(0.9)

  static Color textColor(BuildContext context) => Theme.of(context)
      .colorScheme
      .onSurface; // Typically white.withOpacity(0.9)
  static Color subtleTextColor(BuildContext context) =>
      Colors.white.withOpacity(0.6); // Custom for subtle text in dark theme

  static Color errorColor(BuildContext context) =>
      Theme.of(context).colorScheme.error; // Typically RedAccent.shade200

  // Existing temporary color function (can be integrated into theme if desired)
  static Color getTempColor(double temp) {
    if (temp >= 30) return Colors.red.shade700;
    if (temp >= 25) return Colors.redAccent.shade200;
    if (temp >= 20) return Colors.orange.shade600;
    if (temp >= 15) return Colors.amber.shade700;
    if (temp >= 10) return Colors.lightGreen.shade600;
    if (temp >= 5) return Colors.teal.shade400;
    if (temp >= 0) return Colors.cyan.shade600;
    if (temp >= -5) return Colors.blue.shade300;
    if (temp >= -10) return Colors.lightBlue.shade200;
    return Colors.indigo.shade200;
  }
}
