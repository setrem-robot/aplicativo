import 'package:flutter/material.dart';

/// Qual IA responde no robo.
///
/// - [nuvem]: o modelo maior, que roda numa maquina da rede. Se a rede cair, o
///   robo troca sozinho para a local — "nuvem" quer dizer "use a rede quando
///   der", nao "a qualquer custo".
/// - [local]: o modelo do proprio robo (Raspberry Pi). Responde offline e mais
///   rapido, com respostas mais simples.
///
/// O switch da tela de controle troca entre as duas. O codigo viaja ao robo em
/// `{"tipo":"ia","modo":"<code>"}` pela mesma ponte BLE dos comandos de motor;
/// o RobotEye aplica (ver `core/controle.py` no repositorio da face). Mudou o
/// `code` aqui, muda la tambem.
enum IaModo {
  nuvem(
    'nuvem',
    'IA Nuvem',
    'Modelo maior na rede, com queda automatica para a local',
    // Icone ja embutido no app: um icone novo mudaria a fonte MaterialIcons
    // (tree-shaking) e o Shorebird se recusa a mandar isso num patch OTA.
    Icons.cloud_outlined,
  ),
  local(
    'local',
    'IA Local',
    'Modelo no proprio robo: responde offline e mais rapido',
    Icons.developer_board,
  );

  const IaModo(this.code, this.label, this.descricao, this.icon);

  /// O que vai no JSON enviado ao robo.
  final String code;
  final String label;
  final String descricao;
  final IconData icon;

  /// Le um `code` guardado ou recebido. Um valor desconhecido — de uma versao
  /// antiga, ou lixo — vira o padrao [nuvem], nunca um erro.
  static IaModo fromCode(String? code) =>
      values.firstWhere((m) => m.code == code, orElse: () => IaModo.nuvem);
}
