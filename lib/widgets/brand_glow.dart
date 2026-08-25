import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Brilho verde da marca no topo da tela, atras de todo o conteudo.
///
/// E so um gradiente radial parado -- nada de blur, que custa caro em GPU e
/// deixaria o celular quente numa tela que fica minutos aberta. `IgnorePointer`
/// porque ele cobre a tela inteira e engoliria os toques do que esta embaixo.
class BrandGlow extends StatelessWidget {
  const BrandGlow({super.key, this.alignment = const Alignment(0, -0.75)});

  /// Onde fica o centro do brilho. A tela de conexao usa em cima, atras do
  /// radar; a de controle usa mais embaixo, atras da cruz direcional.
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: alignment,
            radius: 1.1,
            colors: [
              AppColors.primary.withValues(alpha: 0.15),
              AppColors.background.withValues(alpha: 0),
            ],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}
