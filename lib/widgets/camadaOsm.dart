import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// A camada de tiles do OpenStreetMap e a atribuição que a licença exige,
/// num lugar só.
///
/// Duas telas desenham sobre o mapa (o trajeto da telemetria e a rota segura), e
/// a configuração do tile server — o `urlTemplate`, o `userAgent` que a política
/// da OSM pede e a atribuição ODbL — é idêntica nas duas. Copiar isso seria
/// deixar as duas divergirem com o tempo; aqui existe uma vez.

/// A camada de tiles clara da OSM. O tema do app é escuro, mas escurecer o mapa
/// apagaria as ruas — que é justamente o que dá sentido a um trajeto.
TileLayer camadaTilesOsm() => TileLayer(
  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  // A política de uso do tile server da OSM exige identificar quem está pedindo.
  // Sem isto o servidor pode recusar as imagens, e a tela fica cinza sem dizer
  // por quê.
  userAgentPackageName: 'br.edu.setrem.atlas.controller',
  tileProvider: NetworkTileProvider(),
);

/// A atribuição exigida pela licença dos dados da OpenStreetMap (ODbL). Não a
/// remova. Posicione-a num canto do `Stack` do mapa.
class AtribuicaoOsm extends StatelessWidget {
  const AtribuicaoOsm({super.key});

  @override
  Widget build(BuildContext context) {
    return const Positioned(
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
    );
  }
}
