import 'package:flutter/material.dart';

/// Todas as cores do app ficam aqui, e SOMENTE aqui.
///
/// Se voce quiser mudar a aparencia do app, mude nesta classe e o app inteiro
/// acompanha. Nunca escreva um `Color(0xFF...)` solto no meio de uma tela.
///
/// ## De onde vem estas cores
///
/// Da paleta oficial da Setrem (Manual de Identidade Visual, pagina 6):
///
/// | Cor                | Hex      | Pantone |
/// |--------------------|----------|---------|
/// | Verde Setrem       | #00BF6F  | 7480 C  |
/// | Azul Setrem        | #002F6C  | 294 C   |
/// | Verde (secundaria) | #24FFC2  | --      |
/// | Azul (secundaria)  | #00EAFF  | --      |
///
/// O app usa os dois verdes. O Azul Setrem NAO e usado como cor de destaque
/// de proposito: ele e escuro demais (#002F6C) e some no fundo preto do app
/// -- o contraste fica em 1,6:1, abaixo do minimo de 4,5:1 que a norma de
/// acessibilidade pede para texto.
class AppColors {
  const AppColors._(); // impede que alguem crie um objeto AppColors por engano

  /// Verde Setrem. E a cor de destaque do app: icones, bordas, textos
  /// importantes.
  static const Color primary = Color(0xFF00BF6F);

  /// Verde claro da paleta secundaria. Usado junto do Verde Setrem para
  /// fazer os degrades (gradientes) e nos avisos discretos.
  static const Color secondary = Color(0xFF24FFC2);

  /// Azul quase preto. O fundo de todas as telas.
  static const Color background = Color(0xFF0A0E1A);

  /// Azul escuro. O fundo dos cartoes e botoes que ficam por cima do fundo.
  static const Color surface = Color(0xFF131929);

  /// Vermelho do botao STOP e do aviso de desconexao.
  static const Color danger = Color(0xFFB71C1C);

  /// Verde da bolinha "Conectado".
  ///
  /// Continua sendo um verde diferente do verde da marca de proposito: aqui
  /// ele significa "esta funcionando", nao "isto e da Setrem". Quem olha a
  /// tela precisa ler o par verde/vermelho como estado, e nao como enfeite.
  static const Color success = Colors.greenAccent;

  /// O degrade verde claro -> Verde Setrem, usado no titulo e no selo "ROBO".
  ///
  /// Vai do claro para o escuro. As duas pontas sao claras o bastante para
  /// serem lidas no fundo preto do app -- por isso o que for escrito EM CIMA
  /// deste degrade tem que ser escuro (veja [onBrand]).
  static const LinearGradient brandGradient = LinearGradient(
    colors: [secondary, primary],
  );

  /// A cor do texto que fica POR CIMA do [brandGradient].
  ///
  /// Tem que ser escura: o degrade e claro nas duas pontas, e texto branco
  /// sobre ele fica ilegivel (contraste de 1,3:1 contra o #24FFC2).
  static const Color onBrand = background;
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
