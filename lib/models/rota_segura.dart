/// A rota segura que o robô poderá seguir: uma sequência de waypoints e um
/// limite ("cerca") que os contém.
///
/// Este arquivo é só dados e regra — não conhece mapa nem Bluetooth. Quem
/// desenha é a tela; quem envia é o [RobotConnection]. É o que permite testar
/// a validação e o fatiamento sem celular e sem robô (ver
/// `test/rota_segura_test.dart`).
library;

import 'dart:convert';

import 'package:latlong2/latlong.dart';

/// Cálculo de distância pela fórmula de Haversine (leva em conta a curvatura da
/// Terra). O mesmo que `mapa_trajeto.dart` usa para medir o percurso.
const _distancia = Distance();

/// Um waypoint da rota.
class PontoRota {
  const PontoRota(this.lat, this.lon);

  final double lat;
  final double lon;

  LatLng get latLng => LatLng(lat, lon);

  /// Arredonda para 6 casas (~0,11 m): mais que isso é ruído de GPS e só faz a
  /// mensagem BLE crescer à toa.
  Map<String, dynamic> toJson() => {
    'lat': double.parse(lat.toStringAsFixed(6)),
    'lon': double.parse(lon.toStringAsFixed(6)),
  };

  static PontoRota? fromJson(Map<String, dynamic> json) {
    final lat = _numero(json['lat']);
    final lon = _numero(json['lon']);
    if (lat == null || lon == null) return null;
    return PontoRota(lat, lon);
  }
}

/// A cerca virtual que torna a rota "segura": um círculo em volta do ponto de
/// partida. Nenhum waypoint pode ficar mais longe que [raioMetros] da [base] —
/// é o que impede alguém desenhar, sem querer, uma rota que leva o robô para
/// fora da área combinada.
class Geofence {
  const Geofence({required this.base, required this.raioMetros});

  final PontoRota base;
  final double raioMetros;

  bool contem(PontoRota ponto) =>
      _distancia.as(LengthUnit.Meter, base.latLng, ponto.latLng) <= raioMetros;

  Map<String, dynamic> toJson() => {
    'base': base.toJson(),
    'raio_m': raioMetros,
  };

  static Geofence? fromJson(Map<String, dynamic> json) {
    final baseJson = json['base'];
    final base = baseJson is Map
        ? PontoRota.fromJson(baseJson.cast<String, dynamic>())
        : null;
    final raio = _numero(json['raio_m']);
    if (base == null || raio == null || raio <= 0) return null;
    return Geofence(base: base, raioMetros: raio);
  }
}

/// Resultado de tentar adicionar um ponto — ou o ponto entrou, ou há um porquê
/// legível para mostrar a quem está desenhando.
enum ResultadoPonto { adicionado, foraDoLimite }

/// A rota inteira: um nome, os waypoints em ordem e a cerca que os contém.
class RotaSegura {
  RotaSegura({required this.nome, required this.geofence, List<PontoRota>? pontos})
    : pontos = pontos ?? <PontoRota>[];

  /// Nome curto para o operador reconhecer a rota (vira o campo `nome` do
  /// `inicio`). Pode ser vazio.
  final String nome;

  /// A cerca é a base da rota: o primeiro ponto define o centro, e todos os
  /// outros precisam caber dentro dela.
  final Geofence geofence;

  final List<PontoRota> pontos;

  bool get vazia => pontos.isEmpty;

  /// Comprimento total do trajeto, em metros (soma dos trechos).
  double get comprimentoMetros {
    var total = 0.0;
    for (var i = 1; i < pontos.length; i++) {
      total += _distancia.as(LengthUnit.Meter, pontos[i - 1].latLng, pontos[i].latLng);
    }
    return total;
  }

  /// Tenta acrescentar um waypoint. Recusa se cair fora da cerca, porque uma
  /// rota "segura" que sai da área combinada não é segura.
  ResultadoPonto adicionar(PontoRota ponto) {
    if (!geofence.contem(ponto)) return ResultadoPonto.foraDoLimite;
    pontos.add(ponto);
    return ResultadoPonto.adicionado;
  }

  void removerUltimo() {
    if (pontos.isNotEmpty) pontos.removeLast();
  }

  /// As linhas a enviar por BLE, em ordem: `inicio`, um `ponto` por waypoint e
  /// `fim`.
  ///
  /// É fatiado porque uma linha BLE não pode passar de 512 bytes (limite do
  /// firmware do ESP32, `MAX_LINE`): uma rota com muitos pontos jamais caberia
  /// numa mensagem só. Cada linha aqui fica em torno de 65 bytes, com folga de
  /// sobra. Sem o `\n` final — quem escreve no rádio o acrescenta.
  List<String> paraMensagensBle() {
    final inicio = <String, dynamic>{
      'tipo': 'rota',
      'acao': 'inicio',
      'total': pontos.length,
    };
    if (nome.trim().isNotEmpty) inicio['nome'] = nome.trim();

    return [
      jsonEncode(inicio),
      for (var i = 0; i < pontos.length; i++)
        jsonEncode({
          'tipo': 'rota',
          'acao': 'ponto',
          'i': i,
          ...pontos[i].toJson(),
        }),
      jsonEncode({'tipo': 'rota', 'acao': 'fim'}),
    ];
  }

  Map<String, dynamic> toJson() => {
    'nome': nome,
    'geofence': geofence.toJson(),
    'pontos': [for (final p in pontos) p.toJson()],
  };

  static RotaSegura? fromJson(Map<String, dynamic> json) {
    final geofenceJson = json['geofence'];
    final geofence = geofenceJson is Map
        ? Geofence.fromJson(geofenceJson.cast<String, dynamic>())
        : null;
    if (geofence == null) return null;

    final brutos = json['pontos'];
    final pontos = <PontoRota>[];
    if (brutos is List) {
      for (final bruto in brutos) {
        if (bruto is Map) {
          final ponto = PontoRota.fromJson(bruto.cast<String, dynamic>());
          if (ponto != null) pontos.add(ponto);
        }
      }
    }
    return RotaSegura(
      nome: json['nome']?.toString() ?? '',
      geofence: geofence,
      pontos: pontos,
    );
  }
}

double? _numero(Object? valor) {
  if (valor is num) return valor.toDouble();
  if (valor is String) return double.tryParse(valor);
  return null;
}
