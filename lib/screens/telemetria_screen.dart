import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/telemetria.dart';
import '../services/telemetry_api.dart';
import '../widgets/carregando.dart';
import '../widgets/grafico_serie.dart';
import '../widgets/lista_eventos.dart';
import '../widgets/mapa_trajeto.dart';
import '../widgets/painel_estado.dart';
import 'ajustes_api_screen.dart';

/// O que o robô fez, lido do banco na nuvem.
///
/// Esta tela **não depende do Bluetooth**: funciona longe do robô e com ele
/// desligado, porque o que ela mostra é histórico, e não o robô ao vivo. É por
/// isso que ela é alcançada da tela de conexão, e não da de controle — quem
/// abre o app para ver onde o robô andou ontem não deveria precisar parear
/// nada antes.
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
    await TelemetryApi.instance.carregar();
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
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_rounded),
              tooltip: 'Conexão com os dados',
              onPressed: _abrirAjustes,
            ),
          ],
          bottom: const TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.white38,
            // Rolável porque quatro rótulos com texto não cabem lado a lado
            // num celular estreito — sem isto, o Flutter os espreme até virarem
            // reticências.
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(icon: Icon(Icons.dashboard_rounded), text: 'Agora'),
              Tab(icon: Icon(Icons.map_rounded), text: 'Trajeto'),
              Tab(icon: Icon(Icons.show_chart_rounded), text: 'Histórico'),
              Tab(icon: Icon(Icons.list_alt_rounded), text: 'Eventos'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_AbaAgora(), _AbaTrajeto(), _AbaHistorico(), _AbaEventos()],
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
    return Carregando<EstadoRobo>(
      buscar: TelemetryApi.instance.estado,
      vazio: (_) => const SemDados(
        mensagem: 'Nenhuma telemetria ainda',
        detalhe: 'O robô grava aqui quando estiver ligado e com rede. '
            'Para ver as telas antes disso, rode o semear-demonstracao.py na VM.',
      ),
      construir: (context, estado) => estado.vazio
          ? const SemDados(mensagem: 'Nenhuma telemetria ainda')
          : PainelEstado(estado: estado),
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

/// O que dá para ver em gráfico, e com que escala.
///
/// A escala fixa da bateria (0 a 100) não é detalhe: sem ela, uma variação de
/// 82% a 84% ocuparia a altura inteira do gráfico e pareceria um tombo.
class _Grandeza {
  const _Grandeza({
    required this.rotulo,
    required this.tipo,
    required this.campo,
    required this.unidade,
    this.minimo,
    this.maximo,
  });

  final String rotulo;
  final String tipo;
  final String campo;
  final String unidade;
  final double? minimo;
  final double? maximo;
}

const _grandezas = [
  _Grandeza(
    rotulo: 'Bateria',
    tipo: 'bateria',
    campo: 'percentual',
    unidade: '%',
    minimo: 0,
    maximo: 100,
  ),
  _Grandeza(rotulo: 'Tensão', tipo: 'bateria', campo: 'tensao_v', unidade: 'V'),
  _Grandeza(
    rotulo: 'Velocidade',
    tipo: 'gps',
    campo: 'velocidade_kmh',
    unidade: 'km/h',
    minimo: 0,
  ),
  _Grandeza(rotulo: 'Satélites', tipo: 'gps', campo: 'satelites', unidade: '', minimo: 0),
];

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

class _AbaHistorico extends StatefulWidget {
  const _AbaHistorico();

  @override
  State<_AbaHistorico> createState() => _AbaHistoricoState();
}

class _AbaHistoricoState extends State<_AbaHistorico> {
  _Grandeza _grandeza = _grandezas.first;
  String _janela = '24 h';

  @override
  Widget build(BuildContext context) {
    final (duracao, intervalo) = _janelas[_janela]!;

    return Column(
      children: [
        _Filtros(
          grandeza: _grandeza,
          janela: _janela,
          aoTrocarGrandeza: (nova) => setState(() => _grandeza = nova),
          aoTrocarJanela: (nova) => setState(() => _janela = nova),
        ),
        Expanded(
          child: Carregando<List<PontoSerie>>(
            // A chave força um estado novo quando o filtro muda; sem ela o
            // `Carregando` guardaria o Future antigo e o gráfico não mudaria.
            key: ValueKey('${_grandeza.rotulo}|$_janela'),
            buscar: () => TelemetryApi.instance.serie(
              tipo: _grandeza.tipo,
              campo: _grandeza.campo,
              intervalo: intervalo,
              desde: DateTime.now().subtract(duracao),
            ),
            vazio: (_) => SemDados(
              mensagem: 'Sem ${_grandeza.rotulo.toLowerCase()} nesse período',
              detalhe: 'Tente uma janela maior, ou confira se o robô estava '
                  'ligado e publicando.',
            ),
            construir: (context, pontos) => GraficoSerie(
              pontos: pontos,
              unidade: _grandeza.unidade,
              minimoY: _grandeza.minimo,
              maximoY: _grandeza.maximo,
            ),
          ),
        ),
      ],
    );
  }
}

class _Filtros extends StatelessWidget {
  const _Filtros({
    required this.grandeza,
    required this.janela,
    required this.aoTrocarGrandeza,
    required this.aoTrocarJanela,
  });

  final _Grandeza grandeza;
  final String janela;
  final ValueChanged<_Grandeza> aoTrocarGrandeza;
  final ValueChanged<String> aoTrocarJanela;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.medium),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final opcao in _grandezas)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.small),
                    child: ChoiceChip(
                      label: Text(opcao.rotulo),
                      selected: opcao.rotulo == grandeza.rotulo,
                      onSelected: (_) => aoTrocarGrandeza(opcao),
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: opcao.rotulo == grandeza.rotulo
                            ? AppColors.onBrand
                            : Colors.white70,
                      ),
                      backgroundColor: AppColors.surface,
                      side: BorderSide.none,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.small),
          SegmentedButton<String>(
            segments: [
              for (final nome in _janelas.keys)
                ButtonSegment(value: nome, label: Text(nome)),
            ],
            selected: {janela},
            onSelectionChanged: (escolha) => aoTrocarJanela(escolha.first),
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              backgroundColor: AppColors.surface,
              foregroundColor: Colors.white70,
              selectedBackgroundColor: AppColors.primary,
              selectedForegroundColor: AppColors.onBrand,
              side: BorderSide.none,
            ),
          ),
        ],
      ),
    );
  }
}

class _AbaEventos extends StatefulWidget {
  const _AbaEventos();

  @override
  State<_AbaEventos> createState() => _AbaEventosState();
}

class _AbaEventosState extends State<_AbaEventos> {
  String? _tipo;

  static const _tipos = [null, 'gps', 'bateria', 'motores', 'wifi'];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(AppSpacing.medium),
          child: Row(
            children: [
              for (final opcao in _tipos)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.small),
                  child: ChoiceChip(
                    label: Text(opcao ?? 'todos'),
                    selected: opcao == _tipo,
                    onSelected: (_) => setState(() => _tipo = opcao),
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: opcao == _tipo ? AppColors.onBrand : Colors.white70,
                    ),
                    backgroundColor: AppColors.surface,
                    side: BorderSide.none,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: Carregando<List<EventoTelemetria>>(
            key: ValueKey(_tipo ?? 'todos'),
            buscar: () => TelemetryApi.instance.eventos(tipo: _tipo, limite: 200),
            vazio: (_) => const SemDados(mensagem: 'Nenhum evento registrado'),
            construir: (context, eventos) => ListaEventos(eventos: eventos),
          ),
        ),
      ],
    );
  }
}
