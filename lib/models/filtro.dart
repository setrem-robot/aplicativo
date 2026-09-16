/// O que dá para escolher ver na tela de dados: as fontes e as grandezas.
///
/// Antes cada aba tinha a sua lista solta — uma de strings no filtro de
/// eventos, uma de `_Grandeza` no histórico — e "só sistema e GPS" não tinha
/// como ser dito, porque os chips escolhiam **um** de cada vez. Aqui as duas
/// listas viram objetos com identidade (`Fonte.gps`, `Grandeza.id`), para que
/// um conjunto delas possa ser guardado, dado um nome e trazido de volta.
///
/// Nada aqui sabe o que é tela nem o que é `SharedPreferences`: quem guarda é
/// o `FiltroStore`, quem desenha é `barraFiltro.dart`.
library;

/// As fontes de telemetria que o robô publica — os `tipo` das mensagens.
///
/// Fechado em enum de propósito: a lista de chips precisa existir antes de
/// chegar qualquer dado (senão o filtro nasce vazio), e o app já dá a cada uma
/// um cartão, um resumo e uma cor. Um tipo desconhecido que apareça no banco
/// continua sendo mostrado na lista de eventos — só não ganha chip.
enum Fonte {
  sistema('sistema', 'Raspberry Pi'),
  bateria('bateria', 'Bateria'),
  gps('gps', 'GPS'),
  motores('motores', 'Motores'),
  wifi('wifi', 'Rede');

  const Fonte(this.tipo, this.rotulo);

  /// O `tipo` como vem no JSON e no tópico MQTT.
  final String tipo;

  /// O nome que aparece no chip.
  final String rotulo;

  /// A fonte de um `tipo`, ou `null` se o banco mandou um tipo que o app não
  /// conhece. Nunca lança: o payload é livre.
  static Fonte? deTipo(String? tipo) {
    for (final fonte in values) {
      if (fonte.tipo == tipo) return fonte;
    }
    return null;
  }

  /// Todas, na ordem em que aparecem nos chips e nos cartões.
  static Set<Fonte> get todas => Set.unmodifiable(values);
}

/// O que dá para ver em gráfico, e com que escala.
///
/// A escala fixa da bateria (0 a 100) não é detalhe: sem ela, uma variação de
/// 82% a 84% ocuparia a altura inteira do gráfico e pareceria um tombo.
class Grandeza {
  const Grandeza({
    required this.rotulo,
    required this.fonte,
    required this.campo,
    required this.unidade,
    this.minimo,
    this.maximo,
  });

  final String rotulo;

  /// A que fonte a grandeza pertence. É de onde vem a cor da linha do gráfico
  /// e o rótulo do grupo na barra de filtros.
  final Fonte fonte;

  /// O campo do payload, que pode ser aninhado (`cpu.uso_pct`) — a API resolve
  /// navegando pelo JSON.
  final String campo;
  final String unidade;
  final double? minimo;
  final double? maximo;

  /// Identidade estável para guardar a escolha: `sistema.temperatura_c`.
  String get id => '${fonte.tipo}.$campo';

  /// A grandeza de um [id] guardado, ou `null` se ela deixou de existir.
  static Grandeza? deId(String? id) {
    for (final grandeza in todas) {
      if (grandeza.id == id) return grandeza;
    }
    return null;
  }

  /// As grandezas que dá para plotar, agrupadas por fonte.
  ///
  /// A saúde do Pi entrou aqui junto: sem ela, o histórico do robô pararia na
  /// bateria e no GPS — e a pergunta "ele passou calor ontem?" não teria
  /// resposta no app, só no monitor.
  static const List<Grandeza> todas = [
    Grandeza(rotulo: 'Temperatura', fonte: Fonte.sistema, campo: 'temperatura_c', unidade: '°C'),
    Grandeza(rotulo: 'CPU', fonte: Fonte.sistema, campo: 'cpu.uso_pct', unidade: '%', minimo: 0, maximo: 100),
    Grandeza(rotulo: 'Memória', fonte: Fonte.sistema, campo: 'memoria.uso_pct', unidade: '%', minimo: 0, maximo: 100),
    Grandeza(rotulo: 'Bateria', fonte: Fonte.bateria, campo: 'percentual', unidade: '%', minimo: 0, maximo: 100),
    Grandeza(rotulo: 'Tensão', fonte: Fonte.bateria, campo: 'tensao_v', unidade: 'V'),
    Grandeza(rotulo: 'Velocidade', fonte: Fonte.gps, campo: 'velocidade_kmh', unidade: 'km/h', minimo: 0),
    Grandeza(rotulo: 'Satélites', fonte: Fonte.gps, campo: 'satelites', unidade: '', minimo: 0),
  ];
}

/// Um conjunto de fontes com nome — "Pi + GPS", "energia" — para voltar a ele
/// com um toque em vez de remontar chip por chip.
class PresetFiltro {
  const PresetFiltro({required this.nome, required this.fontes});

  final String nome;
  final Set<Fonte> fontes;

  Map<String, dynamic> toJson() => {
        'nome': nome,
        'fontes': [for (final f in fontes) f.tipo],
      };

  /// Devolve `null` para o que não dá para ler: nome vazio, lista ausente, ou
  /// só fontes que o app não conhece mais. Um preset guardado por uma versão
  /// antiga do app não pode derrubar a barra de filtros da versão nova.
  static PresetFiltro? fromJson(Map<String, dynamic> json) {
    final nome = json['nome']?.toString().trim() ?? '';
    final brutas = json['fontes'];
    if (nome.isEmpty || brutas is! List) return null;
    final fontes = {
      for (final tipo in brutas)
        if (Fonte.deTipo(tipo?.toString()) != null) Fonte.deTipo(tipo.toString())!,
    };
    if (fontes.isEmpty) return null;
    return PresetFiltro(nome: nome, fontes: fontes);
  }
}
