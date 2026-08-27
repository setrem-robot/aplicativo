import 'package:flutter/material.dart';

import '../app/theme.dart';

/// O radar da tela de conexao: aneis que nascem no centro e se expandem ate
/// sumir, com o icone de Bluetooth parado no meio.
///
/// Substitui o pulso anterior (o circulo inteiro crescia e encolhia). A
/// diferenca nao e so estetica: anel que sai para fora "procura", circulo que
/// respira so decora. Quando o scan para, os aneis param junto -- a animacao
/// passa a ser informacao, nao enfeite.
class RadarPulse extends StatefulWidget {
  const RadarPulse({super.key, required this.isScanning, this.size = 108});

  /// Com `false`, os aneis somem e o icone fica opaco.
  final bool isScanning;

  final double size;

  @override
  State<RadarPulse> createState() => _RadarPulseState();
}

class _RadarPulseState extends State<RadarPulse>
    with SingleTickerProviderStateMixin {
  static const _ringCount = 3;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppDurations.radar,
  );

  @override
  void initState() {
    super.initState();
    if (widget.isScanning) _controller.repeat();
  }

  @override
  void didUpdateWidget(RadarPulse old) {
    super.didUpdateWidget(old);
    if (widget.isScanning == old.isScanning) return;
    // `animateTo(1)` em vez de `stop()`: parar no meio deixaria um anel
    // congelado na tela. Assim ele termina de sair antes de sumir.
    if (widget.isScanning) {
      _controller.repeat();
    } else {
      _controller.animateTo(1, duration: AppDurations.swap);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Os aneis so existem enquanto escaneia. Fora disso nem sao
          // construidos -- nada de widget invisivel animando de graca.
          if (widget.isScanning)
            AnimatedBuilder(
              animation: _controller,
              builder: (_, __) => CustomPaint(
                size: Size.square(widget.size),
                painter: _RingPainter(
                  progress: _controller.value,
                  ringCount: _ringCount,
                ),
              ),
            ),
          AnimatedContainer(
            duration: AppDurations.swap,
            width: widget.size * 0.55,
            height: widget.size * 0.55,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(
                alpha: widget.isScanning ? 0.18 : 0.08,
              ),
              border: Border.all(
                color: AppColors.primary.withValues(
                  alpha: widget.isScanning ? 1 : 0.35,
                ),
                width: 2,
              ),
            ),
            // Os dois icones sao os NAO-rounded de proposito. A fonte de
            // icones e tree-shaken: so os glifos usados entram no APK. Trocar
            // por uma variante que o release nao tem muda esse arquivo, e
            // asset nao viaja em patch -- o icone chegaria quebrado.
            child: Icon(
              widget.isScanning ? Icons.bluetooth_searching : Icons.bluetooth,
              color: AppColors.primary.withValues(
                alpha: widget.isScanning ? 1 : 0.5,
              ),
              size: widget.size * 0.28,
            ),
          ),
        ],
      ),
    );
  }
}

/// Desenha os aneis. Cada um esta no mesmo ciclo, so que defasado: com 3
/// aneis, um sai quando o anterior esta a um terco do caminho.
class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress, required this.ringCount});

  final double progress;
  final int ringCount;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.width / 2;
    final minRadius = maxRadius * 0.28;

    for (var i = 0; i < ringCount; i++) {
      // `% 1` fecha o ciclo: quando passa de 1 volta para 0 sem salto.
      final t = (progress + i / ringCount) % 1;

      // Some enquanto cresce. O quadrado faz a opacidade cair rapido no
      // comeco e devagar no fim, que e o que da a sensacao de onda.
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.primary.withValues(alpha: (1 - t) * (1 - t) * 0.55);

      canvas.drawCircle(center, minRadius + (maxRadius - minRadius) * t, paint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}
