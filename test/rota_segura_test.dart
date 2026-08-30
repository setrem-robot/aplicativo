import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:robot_controller/models/rota_segura.dart';

/// A rota segura é lógica pura — validação da cerca e fatiamento para o BLE. São
/// exatamente as regras que, se quebrarem, mandam o robô para fora da área
/// combinada ou estouram o buffer do ESP32: falhas que aparecem na frente do
/// robô, não no `flutter analyze`.
void main() {
  // Campus da Setrem, a mesma base dos dados de demonstração.
  const base = PontoRota(-27.7708, -54.2406);

  group('Geofence', () {
    const cerca = Geofence(base: base, raioMetros: 200);

    test('aceita um ponto dentro do raio', () {
      // ~11 m ao lado: bem dentro dos 200 m.
      expect(cerca.contem(const PontoRota(-27.7709, -54.2406)), isTrue);
    });

    test('recusa um ponto além do raio', () {
      // ~1,1 km ao norte: muito fora.
      expect(cerca.contem(const PontoRota(-27.7608, -54.2406)), isFalse);
    });
  });

  group('RotaSegura.adicionar', () {
    test('ponto dentro entra; ponto fora é recusado e não altera a rota', () {
      final rota = RotaSegura(
        nome: 'teste',
        geofence: const Geofence(base: base, raioMetros: 200),
      );

      expect(rota.adicionar(const PontoRota(-27.7709, -54.2407)), ResultadoPonto.adicionado);
      expect(rota.adicionar(const PontoRota(-27.7608, -54.2406)), ResultadoPonto.foraDoLimite);
      expect(rota.pontos.length, 1);
    });
  });

  group('paraMensagensBle', () {
    RotaSegura comPontos(int n) {
      final rota = RotaSegura(
        nome: 'volta-quadra',
        geofence: const Geofence(base: base, raioMetros: 300),
      );
      for (var i = 0; i < n; i++) {
        // Pequenos passos a partir da base, todos dentro dos 300 m.
        rota.adicionar(PontoRota(-27.7708 - i * 0.0001, -54.2406));
      }
      return rota;
    }

    test('emite inicio, um ponto por waypoint e fim, em ordem', () {
      final linhas = comPontos(3).paraMensagensBle();
      expect(linhas.length, 5); // inicio + 3 pontos + fim

      final inicio = jsonDecode(linhas.first) as Map<String, dynamic>;
      expect(inicio['acao'], 'inicio');
      expect(inicio['total'], 3);
      expect(inicio['nome'], 'volta-quadra');

      for (var i = 0; i < 3; i++) {
        final ponto = jsonDecode(linhas[i + 1]) as Map<String, dynamic>;
        expect(ponto['acao'], 'ponto');
        expect(ponto['i'], i); // índices em ordem
      }

      expect(jsonDecode(linhas.last)['acao'], 'fim');
    });

    test('omite o nome quando ele é vazio', () {
      final rota = RotaSegura(
        nome: '   ',
        geofence: const Geofence(base: base, raioMetros: 300),
      )..adicionar(base);
      final inicio = jsonDecode(rota.paraMensagensBle().first) as Map<String, dynamic>;
      expect(inicio.containsKey('nome'), isFalse);
    });

    test('nenhuma linha passa do limite BLE do ESP32 (512 bytes)', () {
      // Uma rota grande: se alguma linha estourar, é aqui que aparece — não com
      // o robô na mão.
      for (final linha in comPontos(50).paraMensagensBle()) {
        // +1 pelo '\n' que o RobotConnection acrescenta ao escrever.
        expect(utf8.encode(linha).length + 1, lessThanOrEqualTo(512));
      }
    });
  });

  group('toJson / fromJson', () {
    test('sobrevive a uma ida e volta', () {
      final original = RotaSegura(
        nome: 'campus',
        geofence: const Geofence(base: base, raioMetros: 150),
      )
        ..adicionar(base)
        ..adicionar(const PontoRota(-27.7710, -54.2407));

      final volta = RotaSegura.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );

      expect(volta, isNotNull);
      expect(volta!.nome, 'campus');
      expect(volta.geofence.raioMetros, 150);
      expect(volta.pontos.length, 2);
      expect(volta.pontos[1].lon, -54.2407);
    });

    test('sem geofence, não há rota que valha (null, sem exceção)', () {
      expect(RotaSegura.fromJson({'nome': 'x', 'pontos': []}), isNull);
    });
  });
}
