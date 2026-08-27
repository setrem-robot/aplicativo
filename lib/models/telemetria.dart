/// O que a API devolve, em objetos que as telas sabem ler.
///
/// Cada classe traz um `fromJson`, e todos eles são **tolerantes**: um campo
/// ausente ou com o tipo errado vira `null`, nunca uma exceção. O motivo é que
/// o payload da telemetria é JSON livre — o robô publica o que cada grupo do
/// projeto decidir publicar, e o formato muda sem o app ficar sabendo. Um app
/// que quebra a tela inteira porque o GPS parou de mandar `satelites` seria
/// pior que um que mostra um traço no lugar.
library;

/// Uma leitura de posição, para desenhar no mapa.
class PontoTrajeto {
  const PontoTrajeto({
    required this.instante,
    required this.lat,
    required this.lon,
    this.velocidadeKmh,
    this.satelites,
  });

  final DateTime instante;
  final double lat;
  final double lon;
  final double? velocidadeKmh;
  final int? satelites;

  /// Devolve `null` quando o ponto não serve para o mapa.
  ///
  /// Sem latitude ou longitude não há o que desenhar; a API já descarta os
  /// pontos sem sinal de GPS, mas um payload malformado ainda pode chegar aqui,
  /// e um ponto desses arrastaria a linha do trajeto até (0, 0) — no golfo da
  /// Guiné, do outro lado do oceano.
  static PontoTrajeto? fromJson(Map<String, dynamic> json) {
    final instante = _data(json['ts']);
    final lat = _numero(json['lat']);
    final lon = _numero(json['lon']);
    if (instante == null || lat == null || lon == null) return null;
    return PontoTrajeto(
      instante: instante,
      lat: lat,
      lon: lon,
      velocidadeKmh: _numero(json['velocidade_kmh']),
      satelites: _inteiro(json['satelites']),
    );
  }
}

/// A última leitura de um tipo de telemetria, com a idade dela junto.
class LeituraAtual {
  const LeituraAtual({
    required this.tipo,
    required this.instante,
    required this.idade,
    required this.dados,
  });

  final String tipo;
  final DateTime instante;

  /// Há quanto tempo esse dado chegou.
  ///
  /// Vem calculado da API, e não do relógio do celular, de propósito: o celular
  /// pode estar com a hora errada, e aí "bateria 83%" de anteontem apareceria
  /// como se fosse de agora — exatamente o erro que faz alguém confiar num robô
  /// que está desligado.
  final Duration idade;

  /// O payload cru, do jeito que o robô publicou.
  final Map<String, dynamic> dados;

  /// Se o dado é recente o bastante para ser lido como "agora".
  ///
  /// Um minuto: o robô publica GPS a cada poucos segundos e bateria a cada
  /// minuto, então passar disso significa que alguma coisa parou.
  bool get recente => idade.inSeconds < 60;

  static LeituraAtual? fromJson(String tipo, Map<String, dynamic> json) {
    final instante = _data(json['ts']);
    if (instante == null) return null;
    final segundos = _numero(json['idade_s']) ?? 0;
    return LeituraAtual(
      tipo: tipo,
      instante: instante,
      idade: Duration(milliseconds: (segundos * 1000).round()),
      dados: (json['dados'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  /// Um campo do payload como número, ou `null` se não vier ou não for número.
  double? numero(String campo) => _numero(dados[campo]);

  /// Um campo do payload como texto, vazio se não vier.
  String texto(String campo) => dados[campo]?.toString() ?? '';
}

/// O estado do robô agora: a última leitura de cada tipo.
class EstadoRobo {
  const EstadoRobo({required this.geradoEm, required this.itens});

  final DateTime geradoEm;
  final Map<String, LeituraAtual> itens;

  LeituraAtual? get gps => itens['gps'];
  LeituraAtual? get bateria => itens['bateria'];
  LeituraAtual? get motores => itens['motores'];
  LeituraAtual? get wifi => itens['wifi'];

  bool get vazio => itens.isEmpty;

  factory EstadoRobo.fromJson(Map<String, dynamic> json) {
    final brutos = (json['itens'] as Map?)?.cast<String, dynamic>() ?? const {};
    final itens = <String, LeituraAtual>{};
    brutos.forEach((tipo, valor) {
      if (valor is Map) {
        final leitura = LeituraAtual.fromJson(tipo, valor.cast<String, dynamic>());
        if (leitura != null) itens[tipo] = leitura;
      }
    });
    return EstadoRobo(
      geradoEm: _data(json['gerado_em']) ?? DateTime.now(),
      itens: itens,
    );
  }
}

/// Um ponto do gráfico: a média de um campo numa faixa de tempo.
class PontoSerie {
  const PontoSerie({required this.instante, required this.valor});

  final DateTime instante;
  final double valor;

  static PontoSerie? fromJson(Map<String, dynamic> json) {
    final instante = _data(json['ts']);
    final valor = _numero(json['valor']);
    if (instante == null || valor == null) return null;
    return PontoSerie(instante: instante, valor: valor);
  }
}

/// Uma mensagem de telemetria como ela chegou ao banco.
class EventoTelemetria {
  const EventoTelemetria({
    required this.instante,
    required this.tipo,
    required this.topico,
    required this.dados,
  });

  final DateTime instante;
  final String tipo;
  final String topico;
  final Map<String, dynamic> dados;

  static EventoTelemetria? fromJson(Map<String, dynamic> json) {
    final instante = _data(json['ts']);
    if (instante == null) return null;
    return EventoTelemetria(
      instante: instante,
      tipo: json['tipo']?.toString() ?? '?',
      topico: json['topico']?.toString() ?? '',
      dados: (json['dados'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }
}

// ---------------------------------------------------------------------------
// Conversões tolerantes
// ---------------------------------------------------------------------------
DateTime? _data(Object? valor) {
  if (valor is! String) return null;
  // A API manda ISO 8601 com fuso; `toLocal` põe no fuso do celular, que é
  // como a pessoa espera ler a hora.
  return DateTime.tryParse(valor)?.toLocal();
}

double? _numero(Object? valor) {
  if (valor is num) return valor.toDouble();
  if (valor is String) return double.tryParse(valor);
  return null;
}

int? _inteiro(Object? valor) {
  if (valor is int) return valor;
  if (valor is num) return valor.round();
  if (valor is String) return int.tryParse(valor);
  return null;
}
