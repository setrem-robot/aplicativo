import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../app/theme.dart';
import '../models/telemetria.dart';
import 'camada_osm.dart';

/// O percurso do robô desenhado sobre o mapa.
///
/// OpenStreetMap em vez do Google Maps: não exige chave de API nem conta de
/// faturamento. Um projeto de curso não deve precisar de um cartão de crédito
/// para abrir uma tela — e a atribuição no rodapé é o que a licença dos dados
/// (ODbL) pede em troca. Não a remova.
class MapaTrajeto extends StatefulWidget {
  const MapaTrajeto({super.key, required this.pontos});

  final List<PontoTrajeto> pontos;

  @override
  State<MapaTrajeto> createState() => _MapaTrajetoState();
}

class _MapaTrajetoState extends State<MapaTrajeto> {
  final MapController _controle = MapController();

  /// Se a câmera já foi enquadrada no trajeto.
  ///
  /// Só uma vez, e é de propósito: reenquadrar a cada atualização arrancaria o
  /// mapa da mão de quem tivesse acabado de dar zoom para olhar um trecho.
  bool _enquadrou = false;

  @override
  Widget build(BuildContext context) {
    final caminho = widget.pontos.map((p) => LatLng(p.lat, p.lon)).toList();
    final ultimo = caminho.last;

    return Stack(
      children: [
        FlutterMap(
          mapController: _controle,
          options: MapOptions(
            initialCenter: ultimo,
            initialZoom: 17,
            backgroundColor: AppColors.background,
            onMapReady: () => _enquadrar(caminho),
          ),
          children: [
            camadaTilesOsm(),
            if (caminho.length > 1)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: caminho,
                    color: AppColors.primary,
                    strokeWidth: 4,
                    borderColor: Colors.black54,
                    borderStrokeWidth: 1,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                if (caminho.length > 1)
                  Marker(
                    point: caminho.first,
                    width: 18,
                    height: 18,
                    child: const _Pino(cor: Colors.white70, icone: Icons.flag_rounded),
                  ),
                Marker(
                  point: ultimo,
                  // Maior que o pino para caber o anel do farol pulsando à
                  // volta — senão o anel seria recortado na borda do marcador.
                  width: 56,
                  height: 56,
                  child: const _Farol(),
                ),
              ],
            ),
          ],
        ),
        Positioned(
          left: AppSpacing.medium,
          top: AppSpacing.medium,
          child: _Resumo(pontos: widget.pontos),
        ),
        Positioned(
          right: AppSpacing.medium,
          bottom: AppSpacing.large + 16,
          child: FloatingActionButton.small(
            heroTag: 'enquadrar',
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.primary,
            onPressed: () {
              _enquadrou = false;
              _enquadrar(caminho);
            },
            child: const Icon(Icons.center_focus_strong_rounded),
          ),
        ),
        const AtribuicaoOsm(),
      ],
    );
  }

  /// Ajusta a câmera para o trajeto inteiro caber na tela.
  void _enquadrar(List<LatLng> caminho) {
    if (_enquadrou || caminho.isEmpty) return;
    _enquadrou = true;

    if (caminho.length == 1) {
      _controle.move(caminho.first, 17);
      return;
    }
    _controle.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(caminho),
        // Margem para os pinos e o cartão de resumo não ficarem em cima da
        // borda do trajeto.
        padding: const EdgeInsets.all(48),
      ),
    );
  }
}

/// O robô na sua última posição, como um farol: o pino fixo no centro e um anel
/// que cresce e some, repetindo. Puxa o olho para "onde ele está agora" sem
/// precisar de legenda — é o único ponto do mapa que se move.
class _Farol extends StatefulWidget {
  const _Farol();

  @override
  State<_Farol> createState() => _FarolState();
}

class _FarolState extends State<_Farol> with SingleTickerProviderStateMixin {
  late final AnimationController _controle = AnimationController(
    vsync: this,
    // Lento de propósito: um pulso rápido vira estroboscópio numa tela que
    // fica minutos aberta. Este é o mesmo ritmo do radar da tela de conexão.
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void dispose() {
    _controle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controle,
      builder: (context, child) {
        final t = _controle.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            // O anel: cresce de 40% a 100% do quadro e desvanece nesse caminho.
            Container(
              width: 56 * (0.4 + 0.6 * t),
              height: 56 * (0.4 + 0.6 * t),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: (1 - t) * 0.6),
                  width: 2,
                ),
              ),
            ),
            child!,
          ],
        );
      },
      child: const _Pino(cor: AppColors.primary, icone: Icons.smart_toy_rounded),
    );
  }
}

class _Pino extends StatelessWidget {
  const _Pino({required this.cor, required this.icone});

  final Color cor;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black45, width: 2),
      ),
      child: Icon(icone, size: 14, color: AppColors.background),
    );
  }
}

class _Resumo extends StatelessWidget {
  const _Resumo({required this.pontos});

  final List<PontoTrajeto> pontos;

  @override
  Widget build(BuildContext context) {
    final ultimo = pontos.last;
    final distancia = _distanciaTotalMetros(pontos);

    // A distância é o número que interessa aqui — é ela que responde "quanto
    // ele andou". Vai grande; a contagem de pontos e a hora ficam de apoio.
    final metros = distancia >= 1000
        ? (distancia / 1000).toStringAsFixed(2)
        : distancia.round().toString();
    final unidade = distancia >= 1000 ? 'km' : 'm';

    return Container(
      padding: const EdgeInsets.fromLTRB(13, 9, 14, 10),
      decoration: BoxDecoration(
        // Mais opaco que antes: sobre o mapa claro da OSM, 92% deixava as ruas
        // passarem por baixo do texto e tirava a legibilidade justamente do
        // número que o cartão existe para mostrar.
        color: AppColors.background.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('PERCURSO', style: AppText.sobrancelha),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(metros, style: AppText.valor.copyWith(fontSize: 26)),
              const SizedBox(width: 3),
              Text(unidade, style: AppText.unidade.copyWith(fontSize: 13)),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            '${pontos.length} pontos · último às ${_hora(ultimo.instante)}',
            style: AppText.meta,
          ),
        ],
      ),
    );
  }
}

String _hora(DateTime momento) =>
    '${momento.hour.toString().padLeft(2, '0')}:${momento.minute.toString().padLeft(2, '0')}';

/// Soma das distâncias entre pontos consecutivos.
///
/// `Distance()` do latlong2 usa a fórmula de Haversine — leva em conta a
/// curvatura da Terra. Numa volta de campus a diferença para o cálculo plano é
/// de centímetros, mas usar a certa não custa nada e não vira uma surpresa se
/// um dia o robô andar quilômetros.
double _distanciaTotalMetros(List<PontoTrajeto> pontos) {
  const calculo = Distance();
  var total = 0.0;
  for (var i = 1; i < pontos.length; i++) {
    total += calculo.as(
      LengthUnit.Meter,
      LatLng(pontos[i - 1].lat, pontos[i - 1].lon),
      LatLng(pontos[i].lat, pontos[i].lon),
    );
  }
  return total;
}
