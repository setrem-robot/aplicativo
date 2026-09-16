import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/filtro.dart';
import '../models/telemetria.dart';
import '../services/filtroStore.dart';
import '../services/telemetryApi.dart';
import '../widgets/barraFiltro.dart';
import '../widgets/carregando.dart';
import '../widgets/graficoSerie.dart';
import '../widgets/listaEventos.dart';
import '../widgets/mapaTrajeto.dart';
import '../widgets/painelEstado.dart';
import 'ajustesApiScreen.dart';

/// O que o robô fez, lido do banco na nuvem.
///
/// Esta tela **não depende do Bluetooth**: funciona longe do robô e com ele
/// desligado, porque o que ela mostra é histórico, e não o robô ao vivo. É por
/// isso que ela é alcançada da tela de conexão, e não da de controle — quem
/// abre o app para ver onde o robô andou ontem não deveria precisar parear
/// nada antes.
///
/// O filtro é um só para a tela (`FiltroStore`): as fontes marcadas valem na
/// aba Agora e na aba Eventos ao mesmo tempo, e sobrevivem ao app fechar.
class TelemetriaScreen extends StatefulWidget {
  const TelemetriaScreen({super.key});

  @override
  State<TelemetriaScreen> createState() => _TelemetriaScreenState();
}

class _TelemetriaScreenState extends State<TelemetriaScreen> {
  bool _carregando = true;
  bool _configurado = false;

  @override
  void initState() {
    super.initState();
    _verificarConfiguracao();
  }

  Future<void> _verificarConfiguracao() async {
    // O filtro guardado é lido junto com a configuração, antes de qualquer
    // aba montar: senão a primeira consulta sairia com "todas" e a tela
    // trocaria de conteúdo um instante depois, quando o filtro chegasse.
    await Future.wait([
      TelemetryApi.instance.carregar(),
      FiltroStore.instance.carregar(),
    ]);
    if (!mounted) return;
    setState(() {
      _configurado = TelemetryApi.instance.configurado;
      _carregando = false;
    });
  }

  Future<void> _abrirAjustes() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AjustesApiScreen()),
    );
    if (!mounted) return;
    setState(() => _carregando = true);
    await _verificarConfiguracao();
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (!_configurado) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Dados do robô'),
          backgroundColor: AppColors.background,
        ),
        body: _PrimeiroUso(aoConfigurar: _abrirAjustes),
      );
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Dados do robô'),
          backgroundColor: AppColors.background,
          scrolledUnderElevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_rounded),
              tooltip: 'Conexão com os dados',
              onPressed: _abrirAjustes,
            ),
          ],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(48),
            child: _Abas(),
          ),
        ),
        body: const TabBarView(
          children: [_AbaAgora(), _AbaTrajeto(), _AbaHistorico(), _AbaEventos()],
        ),
      ),
    );
  }
}

/// As quatro abas, como uma fileira de pílulas.
///
/// A `TabBar` do Material sublinha a aba ativa; aqui ela ganha um fundo — a
/// mesma pílula dos chips de filtro logo abaixo, para a tela inteira falar uma
/// língua só. Rolável porque quatro rótulos com ícone não cabem lado a lado
/// num celular estreito: sem isto, o Flutter os espreme até virarem
/// reticências.
class _Abas extends StatelessWidget {
  const _Abas();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TabBar(
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        padding: const EdgeInsets.fromLTRB(AppSpacing.medium, 0, AppSpacing.medium, 8),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
        ),
        // Sem o brilho do Material ao tocar: a pílula já responde mudando de
        // lugar, e o círculo cinza por cima dela parecia defeito.
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        labelColor: AppColors.texto,
        unselectedLabelColor: AppColors.textoApagado,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        tabs: const [
          _Aba(icone: Icons.dashboard_rounded, rotulo: 'Agora'),
          _Aba(icone: Icons.map_rounded, rotulo: 'Trajeto'),
          _Aba(icone: Icons.show_chart_rounded, rotulo: 'Histórico'),
          _Aba(icone: Icons.list_alt_rounded, rotulo: 'Eventos'),
        ],
      ),
    );
  }
}

class _Aba extends StatelessWidget {
  const _Aba({required this.icone, required this.rotulo});

  final IconData icone;
  final String rotulo;

  @override
  Widget build(BuildContext context) {
    return Tab(
      height: 36,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 15),
            const SizedBox(width: 6),
            Text(rotulo),
          ],
        ),
      ),
    );
  }
}

class _PrimeiroUso extends StatelessWidget {
  const _PrimeiroUso({required this.aoConfigurar});

  final VoidCallback aoConfigurar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_outlined, size: 56, color: Colors.white24),
            const SizedBox(height: AppSpacing.large),
            const Text(
              'Falta dizer onde ficam os dados',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: AppSpacing.small),
            const Text(
              'O robô guarda o que faz num banco na nuvem. Informe o endereço e '
              'o token para o app conseguir ler de lá.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, height: 1.4),
            ),
            const SizedBox(height: AppSpacing.large),
            FilledButton.icon(
              onPressed: aoConfigurar,
              icon: const Icon(Icons.settings_rounded),
              label: const Text('Configurar'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onBrand,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// As quatro abas
// ---------------------------------------------------------------------------
class _AbaAgora extends StatelessWidget {
  const _AbaAgora();

  @override
  Widget build(BuildContext context) {
    final filtro = FiltroStore.instance;
    return Column(
      children: [
        BarraFontes(filtro: filtro),
        Expanded(
          child: Carregando<EstadoRobo>(
            buscar: TelemetryApi.instance.estado,
            vazio: (_) => const SemDados(
              mensagem: 'Nenhuma telemetria ainda',
              detalhe: 'O robô grava aqui quando estiver ligado e com rede. '
                  'Para ver as telas antes disso, rode o semear-demonstracao.py na VM.',
            ),
            // O filtro só esconde cartões; não refaz a consulta. O estado já
            // veio inteiro da API, e trocar de fonte é instantâneo.
            construir: (context, estado) => estado.vazio
                ? const SemDados(mensagem: 'Nenhuma telemetria ainda')
                : AnimatedBuilder(
                    animation: filtro,
                    builder: (context, _) =>
                        PainelEstado(estado: estado, fontes: filtro.fontes),
                  ),
          ),
        ),
      ],
    );
  }
}

class _AbaTrajeto extends StatelessWidget {
  const _AbaTrajeto();

  @override
  Widget build(BuildContext context) {
    return Carregando<List<PontoTrajeto>>(
      buscar: () => TelemetryApi.instance.trajeto(
        desde: DateTime.now().subtract(const Duration(days: 1)),
      ),
      vazio: (_) => const SemDados(
        mensagem: 'Sem posições nas últimas 24 h',
        detalhe: 'O GPS ainda não está instalado no robô. Quando estiver, o '
            'trajeto aparece aqui sozinho — nada precisa mudar no app.',
      ),
      construir: (context, pontos) => MapaTrajeto(pontos: pontos),
    );
  }
}

/// Janelas que fazem sentido num celular, com o passo de agregação de cada uma.
///
/// O passo acompanha a janela de propósito: 24 horas em passos de 1 minuto
/// seriam 1440 pontos numa tela de 6 polegadas — mais pontos que pixels.
const _janelas = {
  '6 h': (Duration(hours: 6), '5m'),
  '24 h': (Duration(days: 1), '15m'),
  '7 d': (Duration(days: 7), '1h'),
  '30 d': (Duration(days: 30), '6h'),
};

/// Um gráfico por grandeza marcada, empilhados.
///
/// Uma grandeza só ocupa a aba inteira, como antes. Duas ou mais viram uma
/// coluna de cartões de altura fixa: é o que deixa ver temperatura e
/// velocidade **uma embaixo da outra**, no mesmo eixo de tempo, e perguntar
/// "ele esquentou quando andou?" — a pergunta que um gráfico de cada vez não
/// responde.
class _AbaHistorico extends StatelessWidget {
  const _AbaHistorico();

  /// Altura de cada cartão quando há mais de um. Cabe a leitura, as quatro
  /// estatísticas e uma linha com espaço para respirar; dois cartões cabem
  /// numa tela de celular sem rolar.
  static const double _alturaCartao = 300;

  @override
  Widget build(BuildContext context) {
    final filtro = FiltroStore.instance;
    return Column(
      children: [
        BarraGrandezas(filtro: filtro, janelas: _janelas.keys.toList()),
        Expanded(
          child: AnimatedBuilder(
            animation: filtro,
            builder: (context, _) {
              final grandezas = filtro.grandezas;
              final (duracao, intervalo) = _janelas[filtro.janela] ?? _janelas.values.first;
              return LayoutBuilder(
                builder: (context, caixa) {
                  final unico = grandezas.length == 1;
                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.medium,
                      AppSpacing.small,
                      AppSpacing.medium,
                      AppSpacing.large * 2,
                    ),
                    itemCount: grandezas.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => SizedBox(
                      // Um só: toda a altura disponível, descontada a margem
                      // (e nunca menos que um cartão, se a caixa for apertada).
                      height: unico
                          ? (caixa.maxHeight - AppSpacing.small - AppSpacing.large * 2)
                              .clamp(_alturaCartao, double.infinity)
                          : _alturaCartao,
                      child: _CartaoGrafico(
                        // A chave é o que faz cada cartão manter o próprio
                        // Future quando um vizinho entra ou sai da lista.
                        key: ValueKey(grandezas[i].id),
                        grandeza: grandezas[i],
                        janela: filtro.janela,
                        duracao: duracao,
                        intervalo: intervalo,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// O cartão de uma grandeza: o nome com a cor da fonte, e o gráfico dentro.
class _CartaoGrafico extends StatelessWidget {
  const _CartaoGrafico({
    super.key,
    required this.grandeza,
    required this.janela,
    required this.duracao,
    required this.intervalo,
  });

  final Grandeza grandeza;
  final String janela;
  final Duration duracao;
  final String intervalo;

  @override
  Widget build(BuildContext context) {
    final cor = AppColors.fonte(grandeza.fonte.tipo);
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surfaceAlta, AppColors.surface],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.large, 14, AppSpacing.large, 0),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: cor,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: cor.withValues(alpha: 0.6), blurRadius: 6)],
                  ),
                ),
                const SizedBox(width: 8),
                Text(grandeza.rotulo.toUpperCase(), style: AppText.sobrancelha),
                const Spacer(),
                Text(
                  '${grandeza.fonte.rotulo} · $janela',
                  style: AppText.meta,
                ),
              ],
            ),
          ),
          Expanded(
            child: Carregando<List<PontoSerie>>(
              // A chave força um estado novo quando a janela muda; sem ela o
              // `Carregando` guardaria o Future antigo e o gráfico não mudaria.
              key: ValueKey('${grandeza.id}|$janela'),
              buscar: () => TelemetryApi.instance.serie(
                tipo: grandeza.fonte.tipo,
                campo: grandeza.campo,
                intervalo: intervalo,
                desde: DateTime.now().subtract(duracao),
              ),
              vazio: (_) => SemDados(
                mensagem: 'Sem ${grandeza.rotulo.toLowerCase()} nesse período',
                detalhe: 'Tente uma janela maior, ou confira se o robô estava '
                    'ligado e publicando.',
              ),
              construir: (context, pontos) => GraficoSerie(
                pontos: pontos,
                unidade: grandeza.unidade,
                cor: cor,
                minimoY: grandeza.minimo,
                maximoY: grandeza.maximo,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AbaEventos extends StatelessWidget {
  const _AbaEventos();

  @override
  Widget build(BuildContext context) {
    final filtro = FiltroStore.instance;
    return Column(
      children: [
        BarraFontes(filtro: filtro),
        Expanded(
          child: AnimatedBuilder(
            animation: filtro,
            builder: (context, _) {
              final tipos = filtro.todasAsFontes
                  ? const <String>[]
                  : [for (final f in filtro.fontes) f.tipo];
              return Carregando<List<EventoTelemetria>>(
                // A chave é o conjunto de fontes: mudou o filtro, nova consulta.
                key: ValueKey(tipos.join(',')),
                buscar: () => TelemetryApi.instance.eventosDasFontes(tipos: tipos),
                vazio: (_) => SemDados(
                  mensagem: 'Nenhum evento registrado',
                  detalhe: tipos.isEmpty
                      ? null
                      : 'Nada dessas fontes nos últimos 90 dias. Marque "todas" '
                          'para conferir se o robô publicou alguma coisa.',
                ),
                construir: (context, eventos) => ListaEventos(eventos: eventos),
              );
            },
          ),
        ),
      ],
    );
  }
}
