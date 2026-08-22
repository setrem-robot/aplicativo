import 'package:flutter/material.dart';

/// Paleta oficial da Setrem (#00BF6F / Pantone 7480 C). Mude só aqui — nunca
/// solto num `Color(0xFF...)` dentro de uma tela.
///
/// Azul Setrem (#002F6C) não é usado como destaque: contraste de 1,6:1 no
/// fundo preto do app, abaixo do mínimo de 4,5:1 exigido para texto (WCAG).
class AppColors {
  const AppColors._();

  static const Color primary = Color(0xFF00BF6F); // destaque: ícones, bordas
  static const Color secondary = Color(0xFF24FFC2); // usado nos degradês
  static const Color background = Color(0xFF0A0E1A);
  static const Color surface = Color(0xFF131929); // fundo de cartões/botões
  static const Color danger = Color(0xFFB71C1C);
  static const Color success = Colors.greenAccent; // "conectado" -- estado, não marca

  /// Pontas claras o bastante para o fundo preto; texto em cima precisa ser
  /// escuro (veja [onBrand]).
  static const LinearGradient brandGradient = LinearGradient(
    colors: [secondary, primary],
  );

  /// Cor do texto sobre o [brandGradient] — branco teria contraste de 1,3:1 ali.
  static const Color onBrand = background;
}

class AppSpacing {
  const AppSpacing._();

  static const double small = 8;
  static const double medium = 16;
  static const double large = 24;
  static const double radius = 16;
}

class AppTheme {
  const AppTheme._();

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: AppColors.background,
  );
}
