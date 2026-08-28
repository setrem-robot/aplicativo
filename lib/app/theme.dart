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

  /// Um degrau acima de [surface], para o cartão não ser um retângulo chapado.
  /// A diferença é pequena de propósito: o que separa o cartão do fundo é a
  /// borda, não o preenchimento.
  static const Color surfaceAlta = Color(0xFF192034);

  static const Color danger = Color(0xFFFF5A6E);
  static const Color success = Color(0xFF3BE08A); // "conectado" -- estado, não marca
  static const Color atencao = Color(0xFFFFB84D);

  /// A cor do dado velho. Um cinza-ardósia frio, e não um branco fraco: o que
  /// envelheceu tem de **recuar** da tela, não só clarear. É a única cor da
  /// paleta que não pertence à marca, e é por isso que ela funciona aqui — um
  /// número parado não deveria parecer da Atlas.
  static const Color parado = Color(0xFF5A6478);

  /// Texto, em três pesos de presença. Ter nomes em vez de `Colors.white54`
  /// solto é o que impede a tela de ganhar um quarto tom por descuido.
  static const Color texto = Color(0xFFEAF0F5);
  static const Color textoFraco = Color(0xFF9AA6B8);
  static const Color textoApagado = Color(0xFF5F6B80);

  /// Pontas claras o bastante para o fundo preto; texto em cima precisa ser
  /// escuro (veja [onBrand]).
  static const LinearGradient brandGradient = LinearGradient(
    colors: [secondary, primary],
  );

  /// Cor do texto sobre o [brandGradient] — branco teria contraste de 1,3:1 ali.
  static const Color onBrand = background;
}

/// A escala de texto do app, com um papel por estilo.
///
/// Sem fonte nova de propósito: o peso, o tamanho e o espaçamento entre letras
/// já dão a personalidade, e um arquivo de fonte pesaria em cada atualização
/// pelo ar. O que faz a tela parecer instrumento — e não formulário — é a
/// disciplina de sempre usar o mesmo estilo para o mesmo papel.
class AppText {
  const AppText._();

  /// O rótulo miúdo acima de um valor: BATERIA, POSIÇÃO. Em caixa alta e bem
  /// espaçado, ele vira uma etiqueta de painel, e some do caminho do número.
  static const TextStyle sobrancelha = TextStyle(
    color: AppColors.textoFraco,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
  );

  /// O número grande. `tabularFigures` é o detalhe que importa: sem ele, cada
  /// dígito tem largura própria e o valor **dança** a cada atualização.
  static const TextStyle valor = TextStyle(
    color: AppColors.texto,
    fontSize: 40,
    fontWeight: FontWeight.w700,
    height: 1,
    letterSpacing: -1.2,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Um valor menor, para quando há dois no mesmo cartão.
  static const TextStyle valorMedio = TextStyle(
    color: AppColors.texto,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.1,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// A unidade ao lado do número (%, V, km/h). Nunca do tamanho do número:
  /// quem lê o painel quer o valor, e a unidade ele já sabe.
  static const TextStyle unidade = TextStyle(
    color: AppColors.textoFraco,
    fontSize: 15,
    fontWeight: FontWeight.w500,
  );

  /// Nota de rodapé de um cartão: a idade do dado, o IP, a contagem.
  static const TextStyle meta = TextStyle(
    color: AppColors.textoApagado,
    fontSize: 11.5,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
  );
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
