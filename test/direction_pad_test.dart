import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robot_controller/models/robot_command.dart';
import 'package:robot_controller/widgets/direction_pad.dart';

/// Testes da cruz direcional.
///
/// Repare que estes testes NAO precisam de Bluetooth nem de celular: como o
/// DirectionPad so avisa "apertaram tal botao" em vez de falar com o robo
/// direto, da para testar ele sozinho, em milissegundos.
void main() {
  /// Monta o widget na tela de teste e devolve as listas onde os avisos
  /// disparados vao sendo anotados.
  Future<(List<RobotCommand>, List<void>)> pumpPad(
    WidgetTester tester, {
    bool enabled = true,
  }) async {
    final pressed = <RobotCommand>[];
    final released = <void>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DirectionPad(
            enabled: enabled,
            onPress: pressed.add,
            onRelease: () => released.add(null),
          ),
        ),
      ),
    );

    return (pressed, released);
  }

  testWidgets('apertar FRENTE avisa o comando forward', (tester) async {
    final (pressed, released) = await pumpPad(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(RobotCommand.forward.icon)),
    );
    await tester.pump();

    expect(pressed, [RobotCommand.forward]);
    expect(released, isEmpty, reason: 'ainda nao soltou o dedo');

    await gesture.up();
    await tester.pump();

    expect(released.length, 1, reason: 'soltar o dedo tem que parar o robo');
  });

  testWidgets('o botao STOP avisa que deve parar', (tester) async {
    final (pressed, released) = await pumpPad(tester);

    await tester.tap(find.text('STOP'));
    await tester.pump();

    expect(pressed, isEmpty);
    expect(released.length, 1);
  });

  testWidgets('desconectado, os botoes nao respondem', (tester) async {
    final (pressed, released) = await pumpPad(tester, enabled: false);

    await tester.tap(find.byIcon(RobotCommand.right.icon));
    await tester.tap(find.text('STOP'));
    await tester.pump();

    expect(pressed, isEmpty);
    expect(released, isEmpty);
  });

  testWidgets('a cruz sumir da tela com o dedo apertado conta como soltar', (
    tester,
  ) async {
    // O caso real: a tela e trocada, ou a cruz e retirada da arvore, enquanto
    // alguem segura uma direcao. Sem o aviso de "soltou", quem repete o comando
    // a cada 300 ms continua repetindo — com o robo andando e ninguem mais na
    // tela para mandar parar.
    final pressed = <RobotCommand>[];
    final released = <void>[];

    Widget montar({required bool mostrarCruz}) => MaterialApp(
      home: Scaffold(
        body: mostrarCruz
            ? DirectionPad(
                onPress: pressed.add,
                onRelease: () => released.add(null),
              )
            : const SizedBox.shrink(),
      ),
    );

    await tester.pumpWidget(montar(mostrarCruz: true));
    await tester.startGesture(
      tester.getCenter(find.byIcon(RobotCommand.forward.icon)),
    );
    await tester.pump();
    expect(pressed, [RobotCommand.forward]);
    expect(released, isEmpty);

    // A cruz sai da tela sem que o dedo tenha subido.
    await tester.pumpWidget(montar(mostrarCruz: false));
    await tester.pump();

    expect(
      released.length,
      1,
      reason: 'sumir com o dedo apertado tem que parar o robo',
    );
  });

  testWidgets('sumir sem ninguem apertando nao manda parar a toa', (
    tester,
  ) async {
    final released = <void>[];

    Widget montar({required bool mostrarCruz}) => MaterialApp(
      home: Scaffold(
        body: mostrarCruz
            ? DirectionPad(onPress: (_) {}, onRelease: () => released.add(null))
            : const SizedBox.shrink(),
      ),
    );

    await tester.pumpWidget(montar(mostrarCruz: true));
    await tester.pumpWidget(montar(mostrarCruz: false));
    await tester.pump();

    expect(released, isEmpty);
  });
}
