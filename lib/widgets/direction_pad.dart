import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/robot_command.dart';

/// A cruz direcional (o "D-pad") com o botao STOP no meio.
///
/// Nao sabe nada sobre Bluetooth: so avisa "apertaram X" / "soltaram" para
/// quem o usa decidir o que fazer.
class DirectionPad extends StatelessWidget {
  const DirectionPad({
    super.key,
    required this.onPress,
    required this.onRelease,
    this.enabled = true,
    this.buttonSize = 90,
  });

  /// Chamado no instante em que o dedo encosta num botao de direcao.
  final ValueChanged<RobotCommand> onPress;

  /// Chamado quando o dedo sai do botao (ou aperta o STOP).
  final VoidCallback onRelease;

  /// Quando `false`, os botoes ficam apagados e nao respondem.
  /// Usado quando a conexao com o robo cai.
  final bool enabled;

  final double buttonSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _button(RobotCommand.forward),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _button(RobotCommand.left),
            const SizedBox(width: 12),
            _stopButton(),
            const SizedBox(width: 12),
            _button(RobotCommand.right),
          ],
        ),
        const SizedBox(height: 12),
        _button(RobotCommand.backward),
      ],
    );
  }

  /// Um botao de direcao. Anda enquanto o dedo estiver pressionando e para
  /// assim que soltar — inclusive se o dedo escorregar para fora do botao
  /// (`onTapCancel`), que e o que evita o robo sair desgovernado.
  Widget _button(RobotCommand command) {
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: GestureDetector(
        onTapDown: enabled ? (_) => onPress(command) : null,
        onTapUp: enabled ? (_) => onRelease() : null,
        onTapCancel: enabled ? onRelease : null,
        child: Container(
          width: buttonSize,
          height: buttonSize,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Icon(
            command.icon,
            color: AppColors.primary,
            size: buttonSize / 2,
          ),
        ),
      ),
    );
  }

  Widget _stopButton() {
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: GestureDetector(
        onTap: enabled ? onRelease : null,
        child: Container(
          width: buttonSize,
          height: buttonSize,
          decoration: BoxDecoration(
            color: AppColors.danger,
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.stop_circle_outlined, color: Colors.white, size: 28),
              SizedBox(height: 2),
              Text(
                'STOP',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
