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

/// Duracoes das animacoes. Centralizadas para o app inteiro pulsar no mesmo
/// ritmo: animacao com duracao "escolhida na hora" em cada tela e o que faz
/// uma interface parecer remendada.
class AppDurations {
  const AppDurations._();

  /// Resposta a um toque. Acima de ~150ms o botao parece lento.
  static const Duration press = Duration(milliseconds: 120);

  /// Troca de conteudo (um texto que vira outro, lista que aparece).
  static const Duration swap = Duration(milliseconds: 260);

  /// Entrada dos elementos quando a tela abre.
  static const Duration enter = Duration(milliseconds: 420);

  /// Ciclo do radar de busca. Lento de proposito: rapido demais vira
  /// estroboscopio numa tela que fica minutos aberta.
  static const Duration radar = Duration(milliseconds: 2600);
}

/// Sombras. O app e escuro, entao "elevacao" aqui e brilho colorido, nao
/// sombra preta -- preto sobre preto nao aparece.
class AppShadows {
  const AppShadows._();

  /// Halo verde para o que esta ativo (botao pressionado, cartao conectado).
  static List<BoxShadow> brandGlow({double opacity = 0.35, double blur = 18}) {
    return [
      BoxShadow(
        color: AppColors.primary.withValues(alpha: opacity),
        blurRadius: blur,
        spreadRadius: 1,
      ),
    ];
  }
}

class AppSpacing {
  const AppSpacing._();

  static const double small = 8;
  static const double medium = 16;
  static const double large = 24;
  static const double radius = 16;
  static const double radiusLarge = 22; // botoes do D-pad
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
