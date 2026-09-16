import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robot_controller/app/theme.dart';
import 'package:robot_controller/models/telemetria.dart';
import 'package:robot_controller/widgets/listaEventos.dart';
import 'package:robot_controller/widgets/visorJson.dart';

/// O visor colore o JSON por família de valor. Se o tokenizador errar, o erro
/// é silencioso — um número pintado como texto — e só aparece a olho. Estes
/// testes olham por ele.
void main() {
  group('colorirJson', () {
    test('chave, texto, número, booleano e nulo ganham cada um a sua cor', () {
      final trechos = colorirJson(
        jsonBonito({'ssid': 'Atlas', 'rssi': -61, 'ok': true, 'ip': null}),
      );
      Color? corDe(String texto) =>
          trechos.firstWhere((t) => t.text == texto).style?.color;

      expect(corDe('"ssid"'), AppJson.chave);
      expect(corDe('"Atlas"'), AppJson.texto);
      expect(corDe('-61'), AppJson.numero);
      expect(corDe('true'), AppJson.booleano);
      expect(corDe('null'), AppJson.nulo);
    });

    test('o texto inteiro é preservado, só repartido', () {
      final original = jsonBonito({'a': [1, 2.5, 'x'], 'b': {'c': false}});
      final juntado = colorirJson(original).map((t) => t.text).join();
      expect(juntado, original);
    });

    test('um "true" dentro de um texto continua texto', () {
      final trechos = colorirJson(jsonBonito({'motivo': 'true story'}));
      final valor = trechos.firstWhere((t) => t.text == '"true story"');
      expect(valor.style?.color, AppJson.texto);
    });
  });

  group('resumirEvento', () {
    EventoTelemetria evento(String tipo, Map<String, dynamic> dados) => EventoTelemetria(
          instante: DateTime(2026, 9, 15, 14, 2, 11),
          tipo: tipo,
          topico: 'robo/telemetria/$tipo',
          dados: dados,
        );

    test('sistema resume em temperatura, CPU e memória', () {
      final linha = resumirEvento(evento('sistema', {
        'temperatura_c': 52.13,
        'cpu': {'uso_pct': 12.4},
        'memoria': {'uso_pct': 40},
        'throttled': {'ok': true},
      }));
      expect(linha, '52.1 °C · CPU 12% · mem 40%');
    });

    test('sistema avisa quando o Pi está em throttling', () {
      final linha = resumirEvento(evento('sistema', {
        'temperatura_c': 81.0,
        'throttled': {'ok': false, 'limite_termico_agora': true},
      }));
      expect(linha, '81.0 °C · throttled!');
    });

    test('sistema sem os campos conhecidos cai no JSON, não numa linha vazia', () {
      final linha = resumirEvento(evento('sistema', {'uptime_s': 10}));
      expect(linha, contains('uptime_s'));
    });
  });

  test('instanteCompleto mostra os milissegundos só quando pedido', () {
    final momento = DateTime(2026, 9, 15, 14, 2, 11, 348);
    expect(instanteCompleto(momento), '15/09 14:02:11');
    expect(instanteCompleto(momento, comMilissegundos: true), '15/09 14:02:11.348');
  });
}
