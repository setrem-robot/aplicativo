import 'package:robot_controller/models/telemetria.dart';
import 'package:flutter_test/flutter_test.dart';

/// A saúde do Pi guarda os números dentro de blocos (`cpu`, `memoria`,
/// `throttled`), então ler o painel depende de alcançar campos aninhados sem
/// quebrar quando um bloco não veio. Estes testes fixam esse contrato.
void main() {
  final agora = DateTime.now().toUtc().toIso8601String();

  EstadoRobo montar(Map<String, dynamic> sistema) => EstadoRobo.fromJson({
        'gerado_em': agora,
        'itens': {
          'sistema': {'ts': agora, 'idade_s': 2, 'dados': sistema},
        },
      });

  test('o estado expõe a leitura de sistema', () {
    final estado = montar({'temperatura_c': 66});
    expect(estado.sistema, isNotNull);
    expect(estado.sistema!.numero('temperatura_c'), 66);
  });

  test('numeroEm alcança um campo dentro de um bloco', () {
    final s = montar({
      'cpu': {'uso_pct': 42.5, 'freq_mhz': 1500},
      'memoria': {'uso_pct': 55},
    }).sistema!;
    expect(s.numeroEm('cpu', 'uso_pct'), 42.5);
    expect(s.numeroEm('cpu', 'freq_mhz'), 1500);
    expect(s.numeroEm('memoria', 'uso_pct'), 55);
  });

  test('numerosEm lê a lista de núcleos e descarta o que não é número', () {
    final s = montar({
      'cpu': {
        'por_nucleo': [10, 20.5, null, 30],
      },
    }).sistema!;
    expect(s.numerosEm('cpu', 'por_nucleo'), [10, 20.5, 30]);
  });

  test('bloco ausente não quebra — vira nulo/vazio, nunca exceção', () {
    final s = montar({'temperatura_c': 60}).sistema!;
    expect(s.numeroEm('cpu', 'uso_pct'), isNull);
    expect(s.numerosEm('cpu', 'por_nucleo'), isEmpty);
    expect(s.bloco('memoria'), isEmpty);
    expect(s.verdadeiroEm('throttled', 'ok'), isFalse);
  });

  test('verdadeiroEm lê um booleano aninhado', () {
    final s = montar({
      'throttled': {'ok': true, 'subtensao_agora': false},
    }).sistema!;
    expect(s.verdadeiroEm('throttled', 'ok'), isTrue);
    expect(s.verdadeiroEm('throttled', 'subtensao_agora'), isFalse);
  });
}
