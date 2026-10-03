import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robot_controller/services/telemetryApi.dart';
import 'package:robot_controller/widgets/carregando.dart';

/// Uma "API" de mentira: cada chamada devolve o próximo valor, ou lança.
class _Fonte {
  int chamadas = 0;
  Object? falharCom;

  Future<int> buscar() async {
    chamadas++;
    final erro = falharCom;
    if (erro != null) throw erro;
    return chamadas;
  }
}

Widget _montar(_Fonte fonte, {Duration? atualizarACada}) {
  return MaterialApp(
    home: Scaffold(
      body: Carregando<int>(
        buscar: fonte.buscar,
        atualizarACada: atualizarACada,
        construir: (context, n) => Text('leitura $n'),
      ),
    ),
  );
}

void main() {
  testWidgets('sem atualizarACada, busca uma vez só', (tester) async {
    final fonte = _Fonte();
    await tester.pumpWidget(_montar(fonte));
    await tester.pump();
    expect(find.text('leitura 1'), findsOneWidget);

    await tester.pump(const Duration(minutes: 1));
    expect(fonte.chamadas, 1);
  });

  testWidgets('com atualizarACada, o que chega aparece sozinho', (tester) async {
    final fonte = _Fonte();
    await tester.pumpWidget(_montar(fonte, atualizarACada: const Duration(seconds: 5)));
    await tester.pump();
    expect(find.text('leitura 1'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(find.text('leitura 2'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(find.text('leitura 3'), findsOneWidget);
  });

  testWidgets('a atualização é silenciosa: sem giro entre uma leitura e outra',
      (tester) async {
    final fonte = _Fonte();
    await tester.pumpWidget(_montar(fonte, atualizarACada: const Duration(seconds: 5)));
    await tester.pump();

    // Exatamente no instante da rodada, antes de a resposta chegar.
    await tester.pump(const Duration(seconds: 5));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('leitura'), findsOneWidget);
  });

  testWidgets('falha passageira não apaga a última leitura boa', (tester) async {
    final fonte = _Fonte();
    await tester.pumpWidget(_montar(fonte, atualizarACada: const Duration(seconds: 5)));
    await tester.pump();

    fonte.falharCom = const ErroApi('sem rede');
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(find.text('leitura 1'), findsOneWidget);
    expect(find.text('sem rede'), findsNothing);

    fonte.falharCom = null;
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(find.text('leitura 3'), findsOneWidget);
  });

  testWidgets('falha que não passa sozinha aparece mesmo com dados', (tester) async {
    final fonte = _Fonte();
    await tester.pumpWidget(_montar(fonte, atualizarACada: const Duration(seconds: 5)));
    await tester.pump();

    fonte.falharCom = const ErroApi('token recusado', podeTentarDeNovo: false);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(find.text('token recusado'), findsOneWidget);
  });

  testWidgets('pausa em segundo plano e busca na hora ao voltar', (tester) async {
    final fonte = _Fonte();
    await tester.pumpWidget(_montar(fonte, atualizarACada: const Duration(seconds: 5)));
    await tester.pump();
    expect(fonte.chamadas, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(minutes: 1));
    expect(fonte.chamadas, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(fonte.chamadas, 2);
    expect(find.text('leitura 2'), findsOneWidget);
  });

  testWidgets('para de buscar quando sai da tela', (tester) async {
    final fonte = _Fonte();
    await tester.pumpWidget(_montar(fonte, atualizarACada: const Duration(seconds: 5)));
    await tester.pump();

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump(const Duration(minutes: 1));
    expect(fonte.chamadas, 1);
  });
}
