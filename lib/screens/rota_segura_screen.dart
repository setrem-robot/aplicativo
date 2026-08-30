import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../app/theme.dart';
import '../models/rota_segura.dart';
import '../services/robot_connection.dart';
import '../services/rota_store.dart';
import '../widgets/camada_osm.dart';

/// Planejamento da "rota segura": os waypoints que o robô poderá seguir, presos
/// dentro de uma cerca em volta do ponto de partida.
///
/// A tela não fala com o rádio direto — quem envia é o [RobotConnection], e quem
/// guarda é o [RotaStore]. Ela só desenha e decide o que é um ponto válido.
class RotaSeguraScreen extends StatefulWidget {
  const RotaSeguraScreen({super.key});

  @override
  State<RotaSeguraScreen> createState() => _RotaSeguraScreenState();
}

class _RotaSeguraScreenState extends State<RotaSeguraScreen> {
  final MapController _mapa = MapController();

  /// O campus da Setrem, usado quando ainda não há rota salva para enquadrar.
  /// É a mesma base dos dados de demonstração da telemetria.
  static const LatLng _campus = LatLng(-27.7708, -54.2406);

  PontoRota? _base;
  double _raio = 200;
  final List<PontoRota> _pontos = [];
  String _nome = '';
  bool _enviando = false;

  static const double _raioMin = 50;
  static const double _raioMax = 500;

  @override
  void initState() {
    super.initState();
    _carregarSalva();
  }

  Future<void> _carregarSalva() async {
    final rota = await RotaStore.carregar();
    if (rota == null || !mounted) return;
    setState(() {
      _base = rota.geofence.base;
      _raio = rota.geofence.raioMetros.clamp(_raioMin, _raioMax);
      _nome = rota.nome;
      _pontos
        ..clear()
        ..addAll(rota.pontos);
    });
    _mapa.move(_base!.latLng, 17);
  }

  /// O raio não pode encolher a ponto de deixar um waypoint já desenhado do lado
  /// de fora — isso quebraria a promessa de que a rota inteira é segura.
  double get _raioMinimoPermitido {
    if (_base == null || _pontos.isEmpty) return _raioMin;
    const d = Distance();
    var maior = _raioMin;
    for (final p in _pontos) {
      final dist = d.as(LengthUnit.Meter, _base!.latLng, p.latLng);
      if (dist > maior) maior = dist;
    }
    return maior.clamp(_raioMin, _raioMax);
  }

  void _aoTocar(LatLng ll) {
    final ponto = PontoRota(ll.latitude, ll.longitude);

    if (_base == null) {
      // O primeiro toque é o ponto de partida: ele vira o centro da cerca.
      setState(() {
        _base = ponto;
        _pontos.add(ponto);
      });
      return;
    }

    final cerca = Geofence(base: _base!, raioMetros: _raio);
    if (cerca.contem(ponto)) {
      setState(() => _pontos.add(ponto));
    } else {
      _avisar('Ponto fora do limite seguro — aumente o raio ou toque mais perto da base.');
    }
  }

  void _desfazer() {
    if (_pontos.isEmpty) return;
    setState(() {
      _pontos.removeLast();
      if (_pontos.isEmpty) _base = null;
    });
  }

  void _limpar() {
    setState(() {
      _pontos.clear();
      _base = null;
    });
  }

  RotaSegura _montarRota() => RotaSegura(
    nome: _nome,
    geofence: Geofence(base: _base!, raioMetros: _raio),
    pontos: List.of(_pontos),
  );

  Future<void> _salvar() async {
    if (_base == null) return;
    await RotaStore.salvar(_montarRota());
    if (mounted) _avisar('Rota guardada neste aparelho.');
  }

  Future<void> _enviar() async {
    final robot = RobotConnection.instance;
    if (_base == null || !robot.isConnected || _enviando) return;

    setState(() => _enviando = true);
    final ok = await robot.enviarRota(_montarRota());
    if (!mounted) return;
    setState(() => _enviando = false);
    _avisar(
      ok
          ? 'Rota enviada ao robô (${_pontos.length} pontos).'
          : 'Não consegui enviar — verifique a conexão com o robô.',
      erro: !ok,
    );
  }

  void _avisar(String mensagem, {bool erro = false}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(mensagem),
          backgroundColor: erro ? AppColors.danger : AppColors.surfaceAlta,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final pinos = [for (final p in _pontos) p.latLng];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Rota segura'),
        foregroundColor: AppColors.texto,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapa,
            options: MapOptions(
              initialCenter: _base?.latLng ?? _campus,
              initialZoom: 16,
              backgroundColor: AppColors.background,
              onTap: (_, ponto) => _aoTocar(ponto),
            ),
            children: [
              camadaTilesOsm(),
              if (_base != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _base!.latLng,
                      radius: _raio,
                      useRadiusInMeter: true,
                      color: AppColors.primary.withValues(alpha: 0.10),
                      borderColor: AppColors.primary.withValues(alpha: 0.6),
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
              if (pinos.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: pinos,
                      color: AppColors.primary,
                      strokeWidth: 4,
                      borderColor: Colors.black54,
                      borderStrokeWidth: 1,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  for (var i = 0; i < pinos.length; i++)
                    Marker(
                      point: pinos[i],
                      width: 18,
                      height: 18,
                      child: _Pino(
                        // O primeiro ponto é a partida: bandeira, não bolinha.
                        icone: i == 0 ? Icons.flag_rounded : Icons.circle,
                        cor: i == 0 ? Colors.white : AppColors.primary,
                      ),
                    ),
                ],
              ),
              const AtribuicaoOsm(),
            ],
          ),
          if (_base == null) const _Instrucao(),
          Align(
            alignment: Alignment.bottomCenter,
            child: _Controles(
              temPontos: _base != null,
              enviando: _enviando,
              raio: _raio,
              raioMin: _raioMin,
              raioMax: _raioMax,
              raioMinimoPermitido: _raioMinimoPermitido,
              qtdPontos: _pontos.length,
              comprimentoMetros: _base != null ? _montarRota().comprimentoMetros : 0,
              onRaio: (v) => setState(() => _raio = v),
              onDesfazer: _pontos.isEmpty ? null : _desfazer,
              onLimpar: _pontos.isEmpty ? null : _limpar,
              onSalvar: _base == null ? null : _salvar,
              onEnviar: _enviar,
            ),
          ),
        ],
      ),
    );
  }
}

/// A dica que aparece só enquanto o mapa está em branco, para não deixar quem
/// abre a tela sem saber que é o toque que começa a rota.
class _Instrucao extends StatelessWidget {
  const _Instrucao();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: AppSpacing.medium,
      left: AppSpacing.medium,
      right: AppSpacing.medium,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.background.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        ),
        child: const Text(
          'Toque no mapa para marcar o ponto de partida. Ele vira o centro da '
          'área segura; os próximos pontos precisam caber dentro dela.',
          style: AppText.meta,
        ),
      ),
    );
  }
}

/// O painel de baixo: o resumo da rota, o raio da cerca e as ações.
class _Controles extends StatelessWidget {
  const _Controles({
    required this.temPontos,
    required this.enviando,
    required this.raio,
    required this.raioMin,
    required this.raioMax,
    required this.raioMinimoPermitido,
    required this.qtdPontos,
    required this.comprimentoMetros,
    required this.onRaio,
    required this.onDesfazer,
    required this.onLimpar,
    required this.onSalvar,
    required this.onEnviar,
  });

  final bool temPontos;
  final bool enviando;
  final double raio;
  final double raioMin;
  final double raioMax;
  final double raioMinimoPermitido;
  final int qtdPontos;
  final double comprimentoMetros;
  final ValueChanged<double> onRaio;
  final VoidCallback? onDesfazer;
  final VoidCallback? onLimpar;
  final Future<void> Function()? onSalvar;
  final Future<void> Function()? onEnviar;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(AppSpacing.medium),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('ÁREA SEGURA', style: AppText.sobrancelha),
                const Spacer(),
                Text(
                  temPontos
                      ? '$qtdPontos pontos · ${comprimentoMetros.round()} m'
                      : 'nenhum ponto',
                  style: AppText.meta,
                ),
              ],
            ),
            Row(
              children: [
                const Icon(Icons.adjust_rounded, size: 16, color: AppColors.textoFraco),
                const SizedBox(width: 8),
                Text('raio ${raio.round()} m', style: AppText.meta),
                Expanded(
                  child: Slider(
                    value: raio.clamp(raioMin, raioMax),
                    min: raioMin,
                    max: raioMax,
                    activeColor: AppColors.primary,
                    onChanged: (v) => onRaio(v < raioMinimoPermitido ? raioMinimoPermitido : v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _BotaoIcone(icone: Icons.undo_rounded, rotulo: 'Desfazer', onTap: onDesfazer),
                const SizedBox(width: 8),
                _BotaoIcone(icone: Icons.delete_outline_rounded, rotulo: 'Limpar', onTap: onLimpar),
                const SizedBox(width: 8),
                _BotaoIcone(
                  icone: Icons.save_outlined,
                  rotulo: 'Salvar',
                  onTap: onSalvar == null ? null : () => onSalvar!(),
                ),
                const Spacer(),
                _BotaoEnviar(enviando: enviando, onEnviar: onEnviar),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BotaoIcone extends StatelessWidget {
  const _BotaoIcone({required this.icone, required this.rotulo, required this.onTap});

  final IconData icone;
  final String rotulo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ativo = onTap != null;
    final cor = ativo ? AppColors.texto : AppColors.textoApagado;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 22, color: cor),
            const SizedBox(height: 2),
            Text(rotulo, style: AppText.meta.copyWith(color: cor)),
          ],
        ),
      ),
    );
  }
}

/// Enviar depende da conexão: fica aceso só com o robô conectado, e por isso
/// escuta o [RobotConnection] — a conexão pode cair enquanto a tela está aberta.
class _BotaoEnviar extends StatelessWidget {
  const _BotaoEnviar({required this.enviando, required this.onEnviar});

  final bool enviando;
  final Future<void> Function()? onEnviar;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: RobotConnection.instance,
      builder: (context, _) {
        final conectado = RobotConnection.instance.isConnected;
        final habilitado = conectado && onEnviar != null && !enviando;
        return FilledButton.icon(
          onPressed: habilitado ? () => onEnviar!() : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onBrand,
            disabledBackgroundColor: AppColors.surfaceAlta,
          ),
          icon: enviando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onBrand),
                )
              : const Icon(Icons.upload_rounded, size: 18),
          label: Text(conectado ? 'Enviar' : 'Sem robô'),
        );
      },
    );
  }
}

class _Pino extends StatelessWidget {
  const _Pino({required this.icone, required this.cor});

  final IconData icone;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black45, width: 2),
      ),
      child: Icon(icone, size: 12, color: AppColors.background),
    );
  }
}
