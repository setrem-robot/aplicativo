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
///
/// Sem `IconData` de proposito: um icone novo entra na fonte MaterialIcons
/// (tree-shaking) e o Shorebird recusa isso num patch OTA. O switch usa so
/// texto, para chegar ao celular sem exigir um APK novo.
enum IaModo {
  nuvem(
    'nuvem',
    'IA Nuvem',
    'Modelo maior na rede, com queda automatica para a local',
  ),
  local(
    'local',
    'IA Local',
    'Modelo no proprio robo: responde offline e mais rapido',
  );

  const IaModo(this.code, this.label, this.descricao);

  /// O que vai no JSON enviado ao robo.
  final String code;
  final String label;
  final String descricao;

  /// Le um `code` guardado ou recebido. Um valor desconhecido — de uma versao
  /// antiga, ou lixo — vira o padrao [nuvem], nunca um erro.
  static IaModo fromCode(String? code) =>
      values.firstWhere((m) => m.code == code, orElse: () => IaModo.nuvem);
}
