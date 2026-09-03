import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/telemetria.dart';

/// Erro que a tela sabe mostrar para uma pessoa.
///
/// A mensagem crua de um cliente HTTP diz o que aconteceu na camada dele
/// ("SocketException: Failed host lookup"), não o que a pessoa tem de
/// conferir. Quem está com o celular na mão precisa da segunda coisa — é a
/// mesma ideia do `explain()` em `llm/probe.py`, no repositório do RobotEye.
class ErroApi implements Exception {
  const ErroApi(this.mensagem, {this.podeTentarDeNovo = true});

  final String mensagem;
  final bool podeTentarDeNovo;

  @override
  String toString() => mensagem;
}

/// Tudo que fala com a API da telemetria passa por aqui.
///
/// É a mesma regra que já vale para o rádio: **as telas não sabem o que é
/// HTTP, e o HTTP não sabe o que é tela.** Trocar a API por outra coisa —
/// GraphQL, um arquivo local, um mock em teste — reescreve este arquivo e mais
/// nenhum.
///
/// Diferente do [RobotConnection], este serviço **não** é um `ChangeNotifier`.
/// A telemetria não chega sozinha: as telas pedem quando abrem e quando a
/// pessoa puxa para atualizar. Um `ChangeNotifier` aqui daria a impressão de
/// que os dados se atualizam sozinhos, o que não é verdade.
class TelemetryApi {
  TelemetryApi._();

  static final TelemetryApi instance = TelemetryApi._();

  /// Valores gravados na build, para o APK sair já configurado:
  ///
  ///     flutter build apk --dart-define=ATLAS_API_URL=https://api.exemplo.com \
  ///                       --dart-define=ATLAS_API_TOKEN=...
  ///
  /// Quem instala o app não precisa digitar endereço nenhum; quem está
  /// desenvolvendo continua podendo trocar pela tela de ajustes.
  static const _urlPadrao = String.fromEnvironment('ATLAS_API_URL');
  static const _tokenPadrao = String.fromEnvironment('ATLAS_API_TOKEN');

  static const _chaveUrl = 'atlas_api_url';
  static const _chaveToken = 'atlas_api_token';

  /// Uma conexão só, reaproveitada. Um `http.Client` novo por requisição
  /// refaria o aperto de mão TLS toda vez — e o app pergunta o estado do robô
  /// a cada poucos segundos.
  final http.Client _http = http.Client();

  String _url = _urlPadrao;
  String _token = _tokenPadrao;
  bool _carregado = false;

  String get url => _url;
  bool get configurado => _url.isNotEmpty && _token.isNotEmpty;

  /// Lê o endereço e o token gravados. Idempotente.
  Future<void> carregar() async {
    if (_carregado) return;
    final prefs = await SharedPreferences.getInstance();
    _url = prefs.getString(_chaveUrl) ?? _urlPadrao;
    _token = prefs.getString(_chaveToken) ?? _tokenPadrao;
    _carregado = true;
  }

  /// Grava endereço e token. `token` nulo ou vazio mantém o que já está lá.
  ///
  /// Manter é o que permite corrigir só o endereço sem redigitar 64 caracteres
  /// — e é por isso que a tela de ajustes nunca precisa exibir o token de
  /// volta, deixando-o à vista de quem estiver por perto.
  ///
  /// O token fica em `SharedPreferences`, que **não é cofre**: num celular com
  /// root ou num backup do aparelho, ele é legível. É aceitável aqui porque o
  /// token só dá acesso de leitura à telemetria de um robô de projeto escolar —
  /// não a dinheiro, nem a dado de pessoa. Se um dia der acesso a mais que
  /// isso, o lugar certo passa a ser `flutter_secure_storage`.
  Future<void> salvar({required String url, String? token}) async {
    await carregar();
    // Barra no fim quebraria os caminhos montados abaixo, e o erro apareceria
    // como 404 — que parece problema no servidor, não de digitação.
    _url = url.trim().replaceAll(RegExp(r'/+$'), '');
    final novo = token?.trim() ?? '';
    if (novo.isNotEmpty) _token = novo;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chaveUrl, _url);
    await prefs.setString(_chaveToken, _token);
  }

  // -- consultas -----------------------------------------------------------

  /// Confere se o endereço responde e se o token serve.
  ///
  /// Existe para a tela de ajustes poder dizer "funcionou" antes de a pessoa
  /// sair dela. Descobrir o endereço errado só na tela do mapa, como uma lista
  /// vazia, é o tipo de silêncio que faz alguém procurar o problema no lugar
  /// errado.
  Future<String> testar() async {
    final saude = await _pegar('/saude', autenticado: false);
    if (saude['banco'] != true) {
      throw const ErroApi('a API respondeu, mas não está falando com o banco');
    }
    // `/saude` não exige token; esta segunda chamada é quem prova que ele vale.
    await _pegar('/v1/estado');
    return 'API respondendo e token aceito';
  }

  Future<EstadoRobo> estado() async {
    return EstadoRobo.fromJson(await _pegar('/v1/estado'));
  }

  Future<List<PontoTrajeto>> trajeto({
    DateTime? desde,
    DateTime? ate,
    int limite = 1000,
  }) async {
    final json = await _pegar('/v1/trajeto', parametros: {
      'limite': '$limite',
      if (desde != null) 'desde': desde.toUtc().toIso8601String(),
      if (ate != null) 'ate': ate.toUtc().toIso8601String(),
    });
    return _lista(json['pontos'], PontoTrajeto.fromJson);
  }

  Future<List<PontoSerie>> serie({
    required String tipo,
    required String campo,
    String intervalo = '1h',
    DateTime? desde,
  }) async {
    final json = await _pegar('/v1/serie/$tipo', parametros: {
      'campo': campo,
      'intervalo': intervalo,
      if (desde != null) 'desde': desde.toUtc().toIso8601String(),
    });
    return _lista(json['pontos'], PontoSerie.fromJson);
  }

  Future<List<EventoTelemetria>> eventos({
    String? tipo,
    int limite = 100,
    DateTime? antesDe,
  }) async {
    final json = await _pegar('/v1/eventos', parametros: {
      'limite': '$limite',
      if (tipo != null && tipo.isNotEmpty) 'tipo': tipo,
      if (antesDe != null) 'antes_de': antesDe.toUtc().toIso8601String(),
    });
    return _lista(json['eventos'], EventoTelemetria.fromJson);
  }

  // -- encanamento ---------------------------------------------------------

  /// Converte a lista crua do JSON, descartando o que não deu para ler.
  ///
  /// Descartar em silêncio é a decisão certa aqui: um ponto malformado no meio
  /// de mil não vale perder os outros novecentos e noventa e nove.
  List<T> _lista<T>(Object? bruto, T? Function(Map<String, dynamic>) converter) {
    if (bruto is! List) return const [];
    final saida = <T>[];
    for (final item in bruto) {
      if (item is Map) {
        final convertido = converter(item.cast<String, dynamic>());
        if (convertido != null) saida.add(convertido);
      }
    }
    return saida;
  }

  /// O Android recusou o `http://` antes de a requisição sair do aparelho?
  ///
  /// Desde o Android 9, texto claro é bloqueado por padrão. O sintoma engana
  /// muito: o navegador do MESMO celular abre o MESMO endereço sem problema,
  /// porque ele não obedece a essa política — e quem está depurando vai
  /// procurar firewall, IP e Wi-Fi, que estão todos certos.
  bool _ehCleartextBloqueado(Object erro) =>
      erro.toString().toUpperCase().contains('CLEARTEXT');

  /// Traduz a falha para o que a pessoa tem de conferir.
  String _explicar(Object erro, Uri uri) {
    if (_ehCleartextBloqueado(erro)) {
      return 'o Android bloqueou a conexão porque o endereço é http:// e não '
          'https://. Este app já vem configurado para permitir isso na rede '
          'local — se está vendo esta mensagem, a versão instalada é antiga.';
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return 'o endereço precisa começar com http:// ou https://';
    }
    return 'não consegui alcançar a API — confira o endereço e a internet';
  }

  Future<Map<String, dynamic>> _pegar(
    String caminho, {
    Map<String, String>? parametros,
    bool autenticado = true,
  }) async {
    await carregar();
    if (_url.isEmpty) {
      throw const ErroApi(
        'endereço da API não configurado — abra os ajustes e informe',
        podeTentarDeNovo: false,
      );
    }

    // `Uri.parse` levanta `FormatException` no que uma pessoa digita errado com
    // facilidade — um espaço no meio do endereço, por exemplo. Sem este `catch`
    // a exceção crua subia até a tela, e o que aparecia era um traço de pilha
    // do Dart em vez da frase que diz onde está o erro.
    final Uri uri;
    try {
      uri = Uri.parse('$_url$caminho').replace(queryParameters: parametros);
    } on FormatException {
      throw ErroApi(
        'o endereço "$_url" não é um endereço válido — confira nos ajustes',
        podeTentarDeNovo: false,
      );
    }

    http.Response resposta;
    try {
      resposta = await _http
          .get(uri, headers: {
            if (autenticado) 'Authorization': 'Bearer $_token',
            'Accept': 'application/json',
          })
          // Sem teto, um celular numa rede ruim fica com a tela girando para
          // sempre. Dez segundos é mais que o suficiente para uma consulta que
          // dura milissegundos do outro lado.
          .timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw const ErroApi('a API não respondeu a tempo — a internet está de pé?');
    } catch (erro) {
      debugPrint('telemetria: falha de rede em $uri: $erro');
      throw ErroApi(_explicar(erro, uri), podeTentarDeNovo: !_ehCleartextBloqueado(erro));
    }

    if (resposta.statusCode == 401) {
      throw const ErroApi(
        'token recusado — confira o token nos ajustes',
        podeTentarDeNovo: false,
      );
    }
    if (resposta.statusCode == 429) {
      throw const ErroApi('perguntei demais em pouco tempo; espere um minuto');
    }
    if (resposta.statusCode == 503) {
      throw const ErroApi('a API está no ar, mas o banco de dados não respondeu');
    }
    if (resposta.statusCode != 200) {
      throw ErroApi('a API respondeu ${resposta.statusCode}');
    }

    try {
      // `bodyBytes` e não `body`: o `body` decide a codificação pelo cabeçalho
      // e cai para latin-1 quando ele não diz nada, o que transformaria
      // "início" em "inÃ­cio" na tela.
      final decodificado = jsonDecode(utf8.decode(resposta.bodyBytes));
      if (decodificado is! Map) {
        throw const ErroApi('a API devolveu algo que não é um objeto JSON');
      }
      return decodificado.cast<String, dynamic>();
    } on FormatException {
      throw const ErroApi('a API devolveu uma resposta que não consegui ler');
    }
  }
}
