import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    // AnimatedOpacity: quando a conexao cai no meio do uso, a cruz apaga
    // suavemente em vez de piscar -- o que ajuda a perceber que foi a
    // conexao que mudou, e nao a tela que travou.
    return AnimatedOpacity(
      opacity: enabled ? 1 : 0.35,
      duration: AppDurations.swap,
      child: Column(
        children: [
          _direction(RobotCommand.forward),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _direction(RobotCommand.left),
              const SizedBox(width: 12),
              _stopButton(),
              const SizedBox(width: 12),
              _direction(RobotCommand.right),
            ],
          ),
          const SizedBox(height: 12),
          _direction(RobotCommand.backward),
        ],
      ),
    );
  }

  Widget _direction(RobotCommand command) {
    return _PadButton(
      size: buttonSize,
      enabled: enabled,
      // Anda enquanto o dedo estiver pressionando e para assim que soltar --
      // inclusive se o dedo escorregar para fora do botao, que e o que evita
      // o robo sair desgovernado.
      onPress: () => onPress(command),
      onRelease: onRelease,
      child: Icon(command.icon, size: buttonSize / 2),
    );
  }

  Widget _stopButton() {
    return _PadButton(
      size: buttonSize,
      enabled: enabled,
      isStop: true,
      // O STOP nao tem "segurar": ele dispara e acabou.
      onPress: onRelease,
      onRelease: null,
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
    );
  }
}

/// Um botao da cruz. Existe separado porque cada botao precisa lembrar se
/// esta pressionado -- e um `setState` no D-pad inteiro redesenharia os cinco
/// a cada toque.
class _PadButton extends StatefulWidget {
  const _PadButton({
    required this.child,
    required this.size,
    required this.enabled,
    required this.onPress,
    required this.onRelease,
    this.isStop = false,
  });

  final Widget child;
  final double size;
  final bool enabled;
  final VoidCallback onPress;

  /// `null` no STOP, que nao tem acao de soltar.
  final VoidCallback? onRelease;

  final bool isStop;

  @override
  State<_PadButton> createState() => _PadButtonState();
}

class _PadButtonState extends State<_PadButton> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  void _handleDown() {
    _set(true);
    // Vibracao curta. Num controle que se usa olhando para o ROBO, e nao
    // para a tela, o toque no dedo e o unico retorno que chega.
    HapticFeedback.selectionClick();
    widget.onPress();
  }

  void _handleUp() {
    _set(false);
    widget.onRelease?.call();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    final active = _pressed && enabled;

    final Color base = widget.isStop ? AppColors.danger : AppColors.surface;
    final Color accent = widget.isStop ? AppColors.danger : AppColors.primary;

    return GestureDetector(
      onTapDown: enabled ? (_) => _handleDown() : null,
      onTapUp: enabled ? (_) => _handleUp() : null,
      onTapCancel: enabled ? () => _handleUp() : null,
      child: AnimatedScale(
        scale: active ? 0.93 : 1,
        duration: AppDurations.press,
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: AppDurations.press,
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            // Pressionado, o botao se acende com a cor da marca em vez de so
            // encolher: da para ver de canto de olho qual direcao esta ativa.
            color: active && !widget.isStop
                ? AppColors.primary.withValues(alpha: 0.22)
                : base,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
            border: widget.isStop
                ? null
                : Border.all(
                    color: accent.withValues(alpha: active ? 0.9 : 0.3),
                    width: 1.5,
                  ),
            boxShadow: active
                ? AppShadows.brandGlow(
                    opacity: widget.isStop ? 0 : 0.4,
                    blur: 22,
                  )
                : null,
          ),
          child: IconTheme.merge(
            data: IconThemeData(color: widget.isStop ? Colors.white : accent),
            child: Center(child: widget.child),
          ),
        ),
      ),
    );
  }
}
