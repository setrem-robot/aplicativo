import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../app/theme.dart';
import '../models/telemetria.dart';

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
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              // A política de uso do tile server da OSM exige identificar quem
              // está pedindo. Sem isto o servidor pode recusar as imagens, e a
              // tela fica cinza sem dizer por quê.
              userAgentPackageName: 'br.edu.setrem.atlas.controller',
              // O tema do app é escuro e o mapa da OSM é claro. Escurecer o
              // tile inteiro pouparia esse contraste, mas apagaria as ruas —
              // que é justamente o que dá sentido ao trajeto. Fica claro.
              tileProvider: NetworkTileProvider(),
            ),
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
                  width: 34,
                  height: 34,
                  child: const _Pino(cor: AppColors.primary, icone: Icons.smart_toy_rounded),
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
        // Atribuição exigida pela licença dos dados da OpenStreetMap.
        const Positioned(
          right: 0,
          bottom: 0,
          child: ColoredBox(
            color: Colors.black54,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                '© OpenStreetMap',
                style: TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ),
          ),
        ),
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${pontos.length} pontos · ${_distanciaEmTexto(distancia)}',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          const SizedBox(height: 2),
          Text(
            'último às ${_hora(ultimo.instante)}',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

String _hora(DateTime momento) =>
    '${momento.hour.toString().padLeft(2, '0')}:${momento.minute.toString().padLeft(2, '0')}';

String _distanciaEmTexto(double metros) =>
    metros >= 1000 ? '${(metros / 1000).toStringAsFixed(2)} km' : '${metros.round()} m';

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
