import 'package:flutter/material.dart';

/// Os comandos que o app sabe enviar para o robo.
///
/// Antes estes comandos eram letras soltas espalhadas pelo codigo ('F', 'L',
/// 'S'...). Isso era perigoso: um erro de digitacao so aparecia com o robo na
/// mao. Agora eles vivem aqui, e o Dart avisa na hora se voce usar um comando
/// que nao existe.
///
/// ## Como adicionar um comando novo
///
/// 1. Acrescente uma linha nesta lista (ex: `buzina('H', 'BUZINA', Icons.campaign)`).
/// 2. Faca o firmware do ESP32 entender a letra nova.
/// 3. Coloque o comando na tela onde ele deve aparecer.
///
/// Nada mais precisa mudar.
enum RobotCommand {
  forward('F', 'FRENTE', Icons.keyboard_arrow_up_rounded),
  backward('B', 'RE', Icons.keyboard_arrow_down_rounded),
  left('L', 'ESQUERDA', Icons.keyboard_arrow_left_rounded),
  right('R', 'DIREITA', Icons.keyboard_arrow_right_rounded),
  stop('S', 'PARADO', Icons.stop_circle_outlined);

  const RobotCommand(this.code, this.label, this.icon);

  /// A letra que viaja pelo Bluetooth ate o ESP32.
  final String code;

  /// O texto mostrado na tela para o usuario.
  final String label;

  /// O icone mostrado no botao.
  final IconData icon;

  /// Os quatro comandos de movimento, sem o STOP.
  /// Util para montar listas na tela sem repetir a mao.
  static const List<RobotCommand> directions = [forward, backward, left, right];
}
