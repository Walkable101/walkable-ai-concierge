import 'package:flutter/cupertino.dart';

/// Colours for the concierge UI. Light and dark variants follow the
/// surrounding app's brightness (Cupertino or Material). Change [brand] to re-colour everything.
@immutable
class ConciergePalette {
  const ConciergePalette({
    required this.brand,
    required this.brandSoft,
    required this.onBrand,
    required this.background,
    required this.surface,
    required this.field,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
  });

  final Color brand;
  final Color brandSoft;
  final Color onBrand;
  final Color background;
  final Color surface;
  final Color field;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;

  /// Walkable's primary brand purple.
  static const walkablePurple = Color(0xFF8C52FF);

  // Neutral values mirror the Walkable app's light/dark palette.
  static const light = ConciergePalette(
    brand: walkablePurple,
    brandSoft: Color(0xFFF3EDFF),
    onBrand: Color(0xFFFFFFFF),
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    field: Color(0xFFF8F8F8),
    border: Color(0xFFE0E2E6),
    textPrimary: Color(0xFF000000),
    textSecondary: Color(0xFF5E5D5D),
  );

  static const dark = ConciergePalette(
    brand: walkablePurple,
    brandSoft: Color(0xFF2E2540),
    onBrand: Color(0xFFFFFFFF),
    background: Color(0xFF1D1D1B),
    surface: Color(0xFF2F2F2D),
    field: Color(0xFF242422),
    border: Color(0xFF50504E),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFC4C4C4),
  );

  static ConciergePalette of(BuildContext context) =>
      CupertinoTheme.brightnessOf(context) == Brightness.dark ? dark : light;
}
