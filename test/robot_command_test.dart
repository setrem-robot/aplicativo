import 'package:flutter_test/flutter_test.dart';
import 'package:robot_controller/models/robot_command.dart';

/// Testes da tabela de comandos.
///
/// Rode com: `flutter test`
void main() {
  test('cada comando tem uma letra diferente', () {
    // Se alguem adicionar um comando novo repetindo uma letra ja usada, o
    // robo obedeceria o comando errado. Este teste pega isso antes.
    final codes = RobotCommand.values.map((c) => c.code).toList();
    expect(codes.toSet().length, codes.length, reason: 'ha letras repetidas');
  });

  test('as letras sao maiusculas e de um caractere so', () {
    for (final command in RobotCommand.values) {
      expect(command.code.length, 1, reason: '${command.name} nao tem 1 letra');
      expect(command.code, command.code.toUpperCase());
    }
  });

  test('a lista de direcoes nao inclui o STOP', () {
    expect(RobotCommand.directions, isNot(contains(RobotCommand.stop)));
    expect(RobotCommand.directions.length, 4);
  });
}
