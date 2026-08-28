import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/telemetria.dart';
import 'frescor.dart';

/// O estado do robô agora: bateria, posição, motores e rede.
///
/// A regra desta tela é que **nenhum número aparece sem a idade dele**. Um
/// painel que mostra "bateria 83%" com a mesma cara para um dado de agora e
/// para um de anteontem é pior que um painel vazio: ele faz alguém confiar num
/// robô que está desligado há dois dias.
///
/// Essa regra é o que dá forma ao visual daqui, e não só ao texto. Cada cartão
/// pega a cor, o brilho e o pulso do [Frescor] da leitura dele: o que está
/// chegando respira em verde, o que envelheceu recua para um cinza frio. Dá
/// para ler o painel inteiro sem ler uma palavra.
class PainelEstado extends StatefulWidget {
  const PainelEstado({super.key, required this.estado});

  final EstadoRobo estado;

  @override
  State<PainelEstado> createState() => _PainelEstadoState();
}

class _PainelEstadoState extends State<PainelEstado>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrada = AnimationController(
    vsync: this,
    duration: AppDurations.enter,
  )..forward();

  @override
  void dispose() {
    _entrada.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estado = widget.estado;
    final blocos = <Widget>[
      _Cabecalho(estado: estado),
      _CartaoBateria(leitura: estado.bateria),
      _CartaoPosicao(leitura: estado.gps),
      _CartaoMotores(leitura: estado.motores),
      _CartaoRede(leitura: estado.wifi),
    ];

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.medium,
        AppSpacing.medium,
        AppSpacing.medium,
        // Folga no fim para o último cartão não encostar no selo de versão.
        AppSpacing.large * 2,
      ),
      itemCount: blocos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _Entrada(
        controle: _entrada,
        ordem: i,
        total: blocos.length,
        child: blocos[i],
      ),
    );
  }
}

/// Faz um bloco entrar deslizando de baixo e surgindo, na sua vez.
///
/// A ordem é o que dá o efeito de cascata: o cartão de baixo só começa quando o
/// de cima já está na metade. Recortar o mesmo controller em fatias (`Interval`)
/// é mais barato que um controller por cartão e mantém todos no mesmo ritmo.
class _Entrada extends StatelessWidget {
  const _Entrada({
    required this.controle,
    required this.ordem,
    required this.total,
    required this.child,
  });

  final AnimationController controle;
  final int ordem;
  final int total;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final inicio = (ordem / (total + 1)).clamp(0.0, 1.0);
    final curva = CurvedAnimation(
      parent: controle,
      curve: Interval(inicio, 1.0, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: curva,
      child: SlideTransition(
        position:
            Tween(begin: const Offset(0, 0.07), end: Offset.zero).animate(curva),
        child: child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// A moldura comum
// ---------------------------------------------------------------------------

/// O cartão de uma leitura.
///
/// A borda esquerda colorida é o que amarra o painel: ela pega a cor do
/// [Frescor], então a coluna de traços na lateral já conta, de relance, quais
/// dados estão vivos e quais pararam — antes de qualquer número ser lido.
class _Cartao extends StatelessWidget {
  const _Cartao({
    required this.titulo,
    required this.icone,
    required this.leitura,
    required this.child,
  });

  final String titulo;
  final IconData icone;
  final LeituraAtual? leitura;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final atual = leitura;
    final frescor = atual == null ? Frescor.parado : Frescor.da(atual.idade);

    return AnimatedContainer(
      duration: AppDurations.swap,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surfaceAlta, AppColors.surface],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // O traço de frescor. 3px: fino o bastante para não virar bloco
              // de cor, largo o bastante para se ver de relance na coluna.
              AnimatedContainer(
                duration: AppDurations.swap,
                width: 3,
                color: frescor.cor.withValues(
                  alpha: frescor == Frescor.parado ? 0.35 : 0.9,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(icone, color: frescor.cor, size: 15),
                          const SizedBox(width: 7),
                          Text(titulo, style: AppText.sobrancelha),
                          const Spacer(),
                          if (atual != null) ...[
                            Text(
                              idadeEmTexto(atual.idade),
                              style: AppText.meta.copyWith(color: frescor.cor),
                            ),
                            const SizedBox(width: 4),
                            PulsoFrescor(frescor: frescor, tamanho: 6),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),
                      // A opacidade é o que faz o dado velho recuar sem sumir.
                      AnimatedOpacity(
                        duration: AppDurations.swap,
                        opacity: frescor.opacidade,
                        child: child,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "agora", "há 3 min", "há 2 h", "há 5 d".
///
/// Arredondado de propósito: a diferença entre 42 e 43 segundos não muda
/// decisão nenhuma, e um número que muda a cada segundo puxa o olho para o
/// lugar errado da tela.
String idadeEmTexto(Duration idade) {
  if (idade.inSeconds < 10) return 'agora';
  if (idade.inSeconds < 60) return 'há ${idade.inSeconds}s';
  if (idade.inMinutes < 60) return 'há ${idade.inMinutes} min';
  if (idade.inHours < 24) return 'há ${idade.inHours} h';
  return 'há ${idade.inDays} d';
}

class _SemLeitura extends StatelessWidget {
  const _SemLeitura({required this.oQueFalta});

  final String oQueFalta;

  @override
  Widget build(BuildContext context) {
    return Text(oQueFalta, style: AppText.meta.copyWith(height: 1.5));
  }
}

// ---------------------------------------------------------------------------
// O cabeçalho
// ---------------------------------------------------------------------------

/// A resposta de uma olhada: o robô está publicando agora?
///
/// Vem do dado mais fresco de todos — se qualquer coisa chegou há segundos, o
/// robô está de pé. Fica acima dos cartões porque é a pergunta que se faz antes
/// de olhar qualquer número.
class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.estado});

  final EstadoRobo estado;

  @override
  Widget build(BuildContext context) {
    final leituras = [estado.bateria, estado.gps, estado.motores, estado.wifi]
        .whereType<LeituraAtual>()
        .toList();
    final maisFresca = leituras.isEmpty
        ? null
        : leituras.reduce((a, b) => a.idade < b.idade ? a : b);
    final frescor =
        maisFresca == null ? Frescor.parado : Frescor.da(maisFresca.idade);

    final titulo = switch (frescor) {
      Frescor.vivo => 'Atlas está publicando',
      Frescor.morno => 'Sem publicar há pouco',
      Frescor.parado => 'Atlas está em silêncio',
    };
    final detalhe = switch (frescor) {
      Frescor.vivo => 'os dados abaixo são de agora',
      Frescor.morno => 'os dados abaixo ainda valem, mas não são de agora',
      Frescor.parado => 'os dados abaixo são o último que se soube dele',
    };

    return Row(
      children: [
        PulsoFrescor(frescor: frescor, tamanho: 9),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: TextStyle(
                  color: frescor.cor,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(detalhe, style: AppText.meta),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Os quatro cartões
// ---------------------------------------------------------------------------

class _CartaoBateria extends StatelessWidget {
  const _CartaoBateria({required this.leitura});

  final LeituraAtual? leitura;

  @override
  Widget build(BuildContext context) {
    final atual = leitura;
    final percentual = atual?.numero('percentual');
    final tensao = atual?.numero('tensao_v');

    return _Cartao(
      titulo: 'BATERIA',
      icone: Icons.bolt_rounded,
      leitura: atual,
      child: percentual == null
          ? const _SemLeitura(oQueFalta: 'ninguém está publicando a bateria ainda')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    ValorAnimado(
                      valor: percentual,
                      estilo: AppText.valor.copyWith(color: _corDaCarga(percentual)),
                    ),
                    const SizedBox(width: 2),
                    const Text('%', style: AppText.unidade),
                    const Spacer(),
                    if (tensao != null)
                      Text(
                        '${tensao.toStringAsFixed(2)} V',
                        style: AppText.valorMedio.copyWith(
                          color: AppColors.textoFraco,
                          fontSize: 15,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _BarraCarga(percentual: percentual, cor: _corDaCarga(percentual)),
              ],
            ),
    );
  }

  /// Verde, âmbar, vermelho. Os cortes são os do robô: abaixo de 20% os
  /// motores de passo começam a falhar antes de a eletrônica desligar, então
  /// vermelho ali significa "recolha agora", não "vai desligar em breve".
  Color _corDaCarga(double percentual) {
    if (percentual >= 50) return AppColors.success;
    if (percentual >= 20) return AppColors.atencao;
    return AppColors.danger;
  }
}

/// A barra de carga. Anima até o valor novo em vez de saltar, pelo mesmo motivo
/// do número: mostrar a direção da mudança sem custo.
class _BarraCarga extends StatelessWidget {
  const _BarraCarga({required this.percentual, required this.cor});

  final double percentual;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Stack(
        children: [
          Container(height: 5, color: Colors.white.withValues(alpha: 0.06)),
          TweenAnimationBuilder<double>(
            tween: Tween(end: (percentual / 100).clamp(0.0, 1.0)),
            duration: AppDurations.enter,
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => FractionallySizedBox(
              widthFactor: v,
              child: Container(
                height: 5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [cor.withValues(alpha: 0.55), cor],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartaoPosicao extends StatelessWidget {
  const _CartaoPosicao({required this.leitura});

  final LeituraAtual? leitura;

  @override
  Widget build(BuildContext context) {
    final atual = leitura;
    final lat = atual?.numero('lat');
    final lon = atual?.numero('lon');
    final comSinal = atual?.dados['fix'] == true;

    return _Cartao(
      titulo: 'POSIÇÃO',
      icone: Icons.place_rounded,
      leitura: atual,
      child: lat == null || lon == null
          ? const _SemLeitura(oQueFalta: 'o GPS ainda não está instalado no robô')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}',
                  style: AppText.valorMedio,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      comSinal
                          ? Icons.satellite_alt_rounded
                          : Icons.signal_cellular_off_rounded,
                      size: 13,
                      color: comSinal ? AppColors.textoApagado : AppColors.atencao,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        comSinal
                            ? '${atual!.dados['satelites'] ?? '?'} satélites'
                            // Sem fix, a coordenada é a última conhecida ou
                            // zero — e (0, 0) fica no meio do oceano.
                            : 'sem sinal de satélite: esta posição não vale',
                        style: AppText.meta.copyWith(
                          color: comSinal ? AppColors.textoApagado : AppColors.atencao,
                        ),
                      ),
                    ),
                    if (atual!.numero('velocidade_kmh') != null)
                      Text(
                        '${atual.numero('velocidade_kmh')!.toStringAsFixed(1)} km/h',
                        style: AppText.meta,
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _CartaoMotores extends StatelessWidget {
  const _CartaoMotores({required this.leitura});

  final LeituraAtual? leitura;

  @override
  Widget build(BuildContext context) {
    final atual = leitura;
    final acao = atual?.texto('acao') ?? '';

    return _Cartao(
      titulo: 'MOTORES',
      icone: Icons.settings_rounded,
      leitura: atual,
      child: acao.isEmpty
          ? const _SemLeitura(oQueFalta: 'nenhum comando de movimento registrado')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  acao.toUpperCase(),
                  style: AppText.valor.copyWith(fontSize: 24, letterSpacing: 1.5),
                ),
                const SizedBox(height: 12),
                // Os dois lados separados, e não só a velocidade: é o que mostra
                // que o robô estava curvando, e para que lado.
                Row(
                  children: [
                    Expanded(
                      child: _Lado(nome: 'esquerda', valor: atual!.numero('esquerda')),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Lado(nome: 'direita', valor: atual.numero('direita')),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

/// A velocidade de um lado, com uma barra que sai do centro.
///
/// Do centro, e não da esquerda: o valor vai de -1 a 1, e o zero é o repouso.
/// Uma barra que crescesse da borda faria a ré parecer avanço.
class _Lado extends StatelessWidget {
  const _Lado({required this.nome, required this.valor});

  final String nome;
  final double? valor;

  @override
  Widget build(BuildContext context) {
    final v = (valor ?? 0).clamp(-1.0, 1.0);
    // Ré em âmbar: um lado negativo enquanto o outro é positivo é o robô
    // girando no lugar, e isso deve saltar aos olhos.
    final cor = v < 0 ? AppColors.atencao : AppColors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(nome, style: AppText.meta),
            const Spacer(),
            ValorAnimado(
              valor: v,
              casas: 2,
              estilo: AppText.valorMedio.copyWith(fontSize: 15, color: cor),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 4,
          child: LayoutBuilder(
            builder: (context, caixa) {
              final meio = caixa.maxWidth / 2;
              return Stack(
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  AnimatedPositioned(
                    duration: AppDurations.swap,
                    curve: Curves.easeOutCubic,
                    left: v >= 0 ? meio : meio + meio * v,
                    width: (meio * v).abs(),
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: cor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CartaoRede extends StatelessWidget {
  const _CartaoRede({required this.leitura});

  final LeituraAtual? leitura;

  @override
  Widget build(BuildContext context) {
    final atual = leitura;
    final conectado = atual?.dados['conectado'] == true;
    final ssid = atual?.texto('ssid') ?? '';

    return _Cartao(
      titulo: 'REDE',
      icone: conectado ? Icons.wifi_rounded : Icons.wifi_off_rounded,
      leitura: atual,
      child: atual == null
          ? const _SemLeitura(oQueFalta: 'o serviço de Wi-Fi não publicou estado')
          : Row(
              children: [
                Expanded(
                  child: Text(
                    conectado ? (ssid.isEmpty ? 'conectado' : ssid) : 'fora do ar',
                    style: AppText.valorMedio.copyWith(
                      color: conectado ? AppColors.texto : AppColors.danger,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (conectado && atual.texto('ip').isNotEmpty)
                  Text(atual.texto('ip'), style: AppText.meta),
              ],
            ),
    );
  }
}
