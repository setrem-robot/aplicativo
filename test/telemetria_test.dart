import 'package:flutter_test/flutter_test.dart';
import 'package:robot_controller/models/telemetria.dart';

/// O payload da telemetria é JSON livre: cada grupo do projeto publica o que
/// decidir, e o formato muda sem o app ficar sabendo. Estes testes cobrem
/// justamente o que acontece quando ele muda — que é o modo de falhar que
/// aparece na frente da plateia, e não no `flutter analyze`.
void main() {
  group('PontoTrajeto', () {
    test('lê um ponto completo', () {
      final ponto = PontoTrajeto.fromJson({
        'ts': '2026-08-27T12:00:00Z',
        'lat': -27.7708,
        'lon': -54.2406,
        'velocidade_kmh': 1.8,
        'satelites': 9,
      });

      expect(ponto, isNotNull);
      expect(ponto!.lat, -27.7708);
      expect(ponto.velocidadeKmh, 1.8);
      expect(ponto.satelites, 9);
    });

    test('sem coordenada, o ponto é descartado', () {
      // Um ponto sem lat/lon arrastaria a linha do trajeto até (0, 0) — no
      // golfo da Guiné, do outro lado do oceano.
      expect(PontoTrajeto.fromJson({'ts': '2026-08-27T12:00:00Z'}), isNull);
      expect(
        PontoTrajeto.fromJson({'ts': '2026-08-27T12:00:00Z', 'lat': -27.7}),
        isNull,
      );
    });

    test('sem instante, o ponto é descartado', () {
      expect(PontoTrajeto.fromJson({'lat': -27.7, 'lon': -54.2}), isNull);
    });

    test('número que veio como texto ainda é lido', () {
      // JSON de origens diferentes serializa número como string com uma
      // facilidade surpreendente.
      final ponto = PontoTrajeto.fromJson({
        'ts': '2026-08-27T12:00:00Z',
        'lat': '-27.7708',
        'lon': '-54.2406',
      });
      expect(ponto?.lat, -27.7708);
    });

    test('campo opcional ausente vira null, não exceção', () {
      final ponto = PontoTrajeto.fromJson({
        'ts': '2026-08-27T12:00:00Z',
        'lat': -27.7,
        'lon': -54.2,
      });
      expect(ponto?.velocidadeKmh, isNull);
      expect(ponto?.satelites, isNull);
    });
  });

  group('EstadoRobo', () {
    final json = {
      'gerado_em': '2026-08-27T12:00:00Z',
      'itens': {
        'bateria': {
          'ts': '2026-08-27T11:59:30Z',
          'idade_s': 30.0,
          'dados': {'percentual': 83.4, 'tensao_v': 12.35},
        },
        'gps': {
          'ts': '2026-08-27T09:00:00Z',
          'idade_s': 10800.0,
          'dados': {'lat': -27.77, 'lon': -54.24, 'fix': true},
        },
      },
    };

    test('separa cada tipo', () {
      final estado = EstadoRobo.fromJson(json);
      expect(estado.bateria?.numero('percentual'), 83.4);
      expect(estado.gps?.dados['fix'], true);
      expect(estado.motores, isNull);
    });

    test('a idade vem da API, não do relógio do celular', () {
      // O celular pode estar com a hora errada; se a idade viesse dele, um dado
      // de anteontem apareceria como se fosse de agora — que é exatamente o
      // erro que faz alguém confiar num robô desligado.
      final estado = EstadoRobo.fromJson(json);
      expect(estado.bateria!.idade, const Duration(seconds: 30));
      expect(estado.gps!.idade, const Duration(hours: 3));
    });

    test('só é recente abaixo de um minuto', () {
      final estado = EstadoRobo.fromJson(json);
      expect(estado.bateria!.recente, isTrue);
      expect(estado.gps!.recente, isFalse);
    });

    test('itens vazios não quebram', () {
      final estado = EstadoRobo.fromJson({'gerado_em': '2026-08-27T12:00:00Z'});
      expect(estado.vazio, isTrue);
      expect(estado.bateria, isNull);
    });

    test('item malformado é ignorado sem derrubar os outros', () {
      final estado = EstadoRobo.fromJson({
        'gerado_em': '2026-08-27T12:00:00Z',
        'itens': {
          'bateria': {'ts': '2026-08-27T12:00:00Z', 'idade_s': 1, 'dados': {}},
          'gps': 'isto deveria ser um objeto',
        },
      });
      expect(estado.bateria, isNotNull);
      expect(estado.gps, isNull);
    });

    test('campo que não é número devolve null em vez de explodir', () {
      final estado = EstadoRobo.fromJson({
        'gerado_em': '2026-08-27T12:00:00Z',
        'itens': {
          'bateria': {
            'ts': '2026-08-27T12:00:00Z',
            'idade_s': 1,
            'dados': {'percentual': 'cheia'},
          },
        },
      });
      expect(estado.bateria!.numero('percentual'), isNull);
      expect(estado.bateria!.texto('percentual'), 'cheia');
    });
  });

  group('PontoSerie', () {
    test('descarta ponto sem valor', () {
      // A API já filtra as médias nulas, mas um bucket vazio que escape não
      // pode virar um degrau até o zero no gráfico.
      expect(PontoSerie.fromJson({'ts': '2026-08-27T12:00:00Z'}), isNull);
      expect(
        PontoSerie.fromJson({'ts': '2026-08-27T12:00:00Z', 'valor': null}),
        isNull,
      );
    });

    test('lê valor numérico', () {
      final ponto = PontoSerie.fromJson({'ts': '2026-08-27T12:00:00Z', 'valor': 83.2});
      expect(ponto?.valor, 83.2);
    });
  });

  group('EventoTelemetria', () {
    test('lê o registro cru', () {
      final evento = EventoTelemetria.fromJson({
        'ts': '2026-08-27T12:00:00Z',
        'tipo': 'motores',
        'topico': 'robo/telemetria/motores',
        'dados': {'acao': 'frente', 'esquerda': 0.8},
      });
      expect(evento?.tipo, 'motores');
      expect(evento?.dados['acao'], 'frente');
    });

    test('sem instante não entra na lista', () {
      expect(EventoTelemetria.fromJson({'tipo': 'gps'}), isNull);
    });

    test('tipo ausente não quebra a etiqueta', () {
      final evento = EventoTelemetria.fromJson({'ts': '2026-08-27T12:00:00Z'});
      expect(evento?.tipo, '?');
      expect(evento?.dados, isEmpty);
    });
  });
}
