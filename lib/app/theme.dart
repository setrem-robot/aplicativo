import 'package:flutter/material.dart';

/// Todas as cores do app ficam aqui, e SOMENTE aqui.
///
/// Se voce quiser mudar a aparencia do app (por exemplo, trocar o ciano por
/// verde), mude nesta classe e o app inteiro acompanha. Nunca escreva um
/// `Color(0xFF...)` solto no meio de uma tela.
class AppColors {
  const AppColors._(); // impede que alguem crie um objeto AppColors por engano

  /// Ciano. E a cor de destaque do app: icones, bordas, textos importantes.
  static const Color primary = Color(0xFF00E5FF);

  /// Azul. Usada junto do ciano para fazer os degrades (gradientes).
  static const Color secondary = Color(0xFF0066FF);

  /// Azul quase preto. O fundo de todas as telas.
  static const Color background = Color(0xFF0A0E1A);

  /// Azul escuro. O fundo dos cartoes e botoes que ficam por cima do fundo.
  static const Color surface = Color(0xFF131929);

  /// Vermelho do botao STOP e do aviso de desconexao.
  static const Color danger = Color(0xFFB71C1C);

  /// Verde da bolinha "Conectado".
  static const Color success = Colors.greenAccent;

  /// O degrade ciano -> azul, usado no titulo e no selo "ROBO".
  static const LinearGradient brandGradient = LinearGradient(
    colors: [primary, secondary],
  );
}

/// Espacamentos padrao. Usar estes valores no lugar de numeros soltos deixa
/// o app visualmente consistente.
class AppSpacing {
  const AppSpacing._();

  static const double small = 8;
  static const double medium = 16;
  static const double large = 24;

  /// Cantos arredondados dos cartoes e botoes.
  static const double radius = 16;
}

/// Monta o tema do Material Design a partir das cores acima.
///
/// O tema e o que o Flutter aplica automaticamente em widgets prontos
/// (botoes, textos, barras). O que ele nao cobre, as telas pintam na mao
/// usando [AppColors].
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
