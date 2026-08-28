import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/telemetria.dart';
import 'app_card.dart';

/// O estado do robô agora: bateria, posição, motores e rede.
///
/// A regra desta tela é que **nenhum número aparece sem a idade dele**. Um
/// painel que mostra "bateria 83%" com a mesma cara para um dado de agora e
/// para um de anteontem é pior que um painel vazio: ele faz alguém confiar num
/// robô que está desligado há dois dias.
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
    // O cabeçalho é o item 0; cada cartão entra logo depois do de cima.
    final blocos = <Widget>[
      _Resumo(estado: estado),
      _CartaoBateria(leitura: estado.bateria),
      _CartaoPosicao(leitura: estado.gps),
      _CartaoMotores(leitura: estado.motores),
      _CartaoRede(leitura: estado.wifi),
    ];

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.medium),
      itemCount: blocos.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.medium),
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
      curve: Interval(inicio, 1.0, curve: Curves.easeOut),
    );
    return FadeTransition(
      opacity: curva,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.06), end: Offset.zero)
            .animate(curva),
        child: child,
      ),
    );
  }
}

/// Uma linha de resumo no topo: o robô está "ao vivo"? e há quanto tempo veio o
/// dado mais fresco de todos. É o que responde de relance "posso confiar nisto
/// agora?" antes de a pessoa ler cartão por cartão.
class _Resumo extends StatelessWidget {
  const _Resumo({required this.estado});

  final EstadoRobo estado;

  @override
  Widget build(BuildContext context) {
    final leituras = [estado.bateria, estado.gps, estado.motores, estado.wifi]
        .whereType<LeituraAtual>()
        .toList();
    // A leitura mais recente de todas decide o estado geral: se qualquer coisa
    // chegou há poucos segundos, o robô está publicando.
    final maisFresca = leituras.isEmpty
        ? null
        : leituras.reduce((a, b) => a.idade < b.idade ? a : b);
    final aoVivo = maisFresca?.recente ?? false;
    final cor = aoVivo ? AppColors.success : Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.medium,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        border: Border.all(color: cor.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          // O ponto colorido: verde aceso = chegando agora, âmbar = parado.
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: cor,
              shape: BoxShape.circle,
              boxShadow: aoVivo
                  ? [BoxShadow(color: cor.withValues(alpha: 0.6), blurRadius: 8)]
                  : null,
            ),
          ),
          const SizedBox(width: AppSpacing.small),
          Text(
            aoVivo ? 'Recebendo dados' : 'Sem dados recentes',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const Spacer(),
          if (maisFresca != null)
            Text(
              idadeEmTexto(maisFresca.idade),
              style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.w600),
            ),
        ],
      ),
    );
  }
}

/// Cabeçalho comum: o nome do dado, e há quanto tempo ele chegou.
class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.titulo, required this.icone, this.leitura});

  final String titulo;
  final IconData icone;
  final LeituraAtual? leitura;

  @override
  Widget build(BuildContext context) {
    final atual = leitura;
    return Row(
      children: [
        Icon(icone, color: AppColors.primary, size: 20),
        const SizedBox(width: AppSpacing.small),
        Text(
          titulo,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const Spacer(),
        if (atual != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: atual.recente
                  ? AppColors.success.withValues(alpha: 0.15)
                  : Colors.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              idadeEmTexto(atual.idade),
              style: TextStyle(
                color: atual.recente ? AppColors.success : Colors.orange,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
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
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.small),
      child: Text(
        oQueFalta,
        style: const TextStyle(color: Colors.white38, height: 1.4),
      ),
    );
  }
}

class _CartaoBateria extends StatelessWidget {
  const _CartaoBateria({required this.leitura});

  final LeituraAtual? leitura;

  @override
  Widget build(BuildContext context) {
    final atual = leitura;
    final percentual = atual?.numero('percentual');

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Cabecalho(titulo: 'BATERIA', icone: Icons.battery_full_rounded, leitura: atual),
          if (percentual == null)
            const _SemLeitura(oQueFalta: 'ninguém está publicando a bateria ainda')
          else ...[
            const SizedBox(height: AppSpacing.medium),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  percentual.toStringAsFixed(0),
                  style: TextStyle(
                    color: _corDaCarga(percentual),
                    fontSize: 44,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
                const Text('%', style: TextStyle(color: Colors.white54, fontSize: 20)),
                const Spacer(),
                if (atual!.numero('tensao_v') != null)
                  Text(
                    '${atual.numero('tensao_v')!.toStringAsFixed(2)} V',
                    style: const TextStyle(color: Colors.white54),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.medium),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (percentual / 100).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation(_corDaCarga(percentual)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Verde, âmbar, vermelho. Os cortes são os do robô: abaixo de 20% os
  /// motores de passo começam a falhar antes de a eletrônica desligar, então
  /// vermelho ali significa "recolha agora", não "vai desligar em breve".
  Color _corDaCarga(double percentual) {
    if (percentual >= 50) return AppColors.success;
    if (percentual >= 20) return Colors.orange;
    return Colors.redAccent;
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

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Cabecalho(titulo: 'POSIÇÃO', icone: Icons.place_rounded, leitura: atual),
          if (lat == null || lon == null)
            const _SemLeitura(oQueFalta: 'o GPS ainda não está instalado no robô')
          else ...[
            const SizedBox(height: AppSpacing.medium),
            Text(
              '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: AppSpacing.small),
            Row(
              children: [
                Icon(
                  comSinal ? Icons.satellite_alt_rounded : Icons.signal_cellular_off_rounded,
                  size: 14,
                  color: comSinal ? AppColors.success : Colors.orange,
                ),
                const SizedBox(width: 6),
                Text(
                  comSinal
                      ? '${atual!.dados['satelites'] ?? '?'} satélites'
                      // Sem fix, a coordenada é a última conhecida ou zero —
                      // e (0, 0) fica no meio do oceano.
                      : 'sem sinal de satélite: esta posição não vale',
                  style: TextStyle(
                    color: comSinal ? Colors.white54 : Colors.orange,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                if (atual!.numero('velocidade_kmh') != null)
                  Text(
                    '${atual.numero('velocidade_kmh')!.toStringAsFixed(1)} km/h',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
              ],
            ),
          ],
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

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Cabecalho(titulo: 'MOTORES', icone: Icons.settings_rounded, leitura: atual),
          if (acao.isEmpty)
            const _SemLeitura(oQueFalta: 'nenhum comando de movimento registrado')
          else ...[
            const SizedBox(height: AppSpacing.medium),
            Text(
              acao.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: AppSpacing.medium),
            // Os dois lados separados, e não só a velocidade: é o que mostra
            // que o robô estava curvando, e para que lado.
            Row(
              children: [
                Expanded(child: _Lado(nome: 'esquerda', valor: atual!.numero('esquerda'))),
                const SizedBox(width: AppSpacing.medium),
                Expanded(child: _Lado(nome: 'direita', valor: atual.numero('direita'))),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Lado extends StatelessWidget {
  const _Lado({required this.nome, required this.valor});

  final String nome;
  final double? valor;

  @override
  Widget build(BuildContext context) {
    final v = valor ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(nome, style: const TextStyle(color: Colors.white38, fontSize: 11)),
        const SizedBox(height: 4),
        Text(
          v.toStringAsFixed(2),
          style: TextStyle(
            // Ré em âmbar: um lado negativo enquanto o outro é positivo é o
            // robô girando no lugar, e isso deve saltar aos olhos.
            color: v < 0 ? Colors.orange : Colors.white,
            fontSize: 18,
            fontFeatures: const [FontFeature.tabularFigures()],
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

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Cabecalho(titulo: 'REDE', icone: Icons.wifi_rounded, leitura: atual),
          if (atual == null)
            const _SemLeitura(oQueFalta: 'o serviço de Wi-Fi não publicou estado')
          else ...[
            const SizedBox(height: AppSpacing.medium),
            Row(
              children: [
                Icon(
                  conectado ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                  color: conectado ? AppColors.success : Colors.redAccent,
                ),
                const SizedBox(width: AppSpacing.small),
                Text(
                  conectado ? (ssid.isEmpty ? 'conectado' : ssid) : 'fora do ar',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const Spacer(),
                if (conectado && atual.texto('ip').isNotEmpty)
                  Text(
                    atual.texto('ip'),
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
