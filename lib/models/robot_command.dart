import 'package:flutter/material.dart';

/// Os comandos que o app sabe enviar para o robo. Adicionar um novo: uma
/// linha aqui + o firmware do ESP32 entender a letra nova.
enum RobotCommand {
  forward('F', 'FRENTE', Icons.keyboard_arrow_up_rounded),
  backward('B', 'RE', Icons.keyboard_arrow_down_rounded),
  left('L', 'ESQUERDA', Icons.keyboard_arrow_left_rounded),
  right('R', 'DIREITA', Icons.keyboard_arrow_right_rounded),
  stop('S', 'PARADO', Icons.stop_circle_outlined);

  const RobotCommand(this.code, this.label, this.icon);

  final String code; // letra enviada ao ESP32
  final String label;
  final IconData icon;

  static const List<RobotCommand> directions = [forward, backward, left, right];
}
