import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

/// Em que ponto está a atualização do app pelo Shorebird.
///
/// O app se atualiza por patch — código Dart novo que viaja pela rede, sem
/// reinstalar nada. Até aqui isso era invisível: não dava para saber se um
/// patch estava baixando. Estes estados são o que a [FaixaAtualizacao] mostra,
/// para a pergunta "está baixando algo ou não?" ter resposta na tela.
enum EstadoAtualizacao {
  /// Ainda não checou (logo ao abrir).
  desconhecido,

  /// Build sem Shorebird — `flutter run`, emulador, ou um APK de debug. Não há
  /// atualização por patch aqui, então não há o que mostrar.
  indisponivel,

  /// Consultando o servidor: existe patch novo?
  procurando,

  /// Rodando o patch mais novo. Nada a fazer.
  atualizada,

  /// Um patch novo está sendo baixado agora.
  baixando,

  /// O patch foi baixado; falta **reabrir o app** para ele valer.
  pronta,

  /// A checagem ou o download falharam (rede?). O app segue funcionando no
  /// código que já tem — a falha só significa "não atualizou agora".
  falhou,
}

/// Descobre e conduz a atualização OTA, e conta em que ponto ela está.
///
/// É um `ChangeNotifier` (ao contrário do `TelemetryApi`) porque o estado
/// **muda sozinho** enquanto o download acontece: procurando → baixando →
/// pronta. Quem escuta (a faixa e o selo) se redesenha a cada passo.
///
/// Com `auto_update: false` no `shorebird.yaml`, é [verificar] quem dispara o
/// download — e é isso que permite mostrar o "baixando". Todo o caminho é
/// **não-bloqueante e engole exceções**: o app abre e funciona normalmente
/// mesmo se a rede estiver fora ou o Shorebird indisponível.
class AtualizacaoService extends ChangeNotifier {
  AtualizacaoService({ShorebirdUpdater? updater})
      : _updater = updater ?? ShorebirdUpdater();

  static final AtualizacaoService instance = AtualizacaoService();

  final ShorebirdUpdater _updater;

  EstadoAtualizacao estado = EstadoAtualizacao.desconhecido;

  /// A versão REAL do build (`1.2.3+10`), lida da plataforma — não uma
  /// constante que alguém pode esquecer de atualizar. Vazia até a primeira
  /// leitura, ou se a plataforma não responder.
  String versao = '';

  /// O número do patch instalado, ou `null` quando roda só o release (sem
  /// nenhum patch por cima ainda).
  int? patch;

  bool _emCurso = false;

  /// Consulta o servidor e, se houver patch novo, baixa — atualizando [estado]
  /// a cada passo. Idempotente: chamadas concorrentes são ignoradas.
  Future<void> verificar() async {
    if (_emCurso) return;
    _emCurso = true;
    try {
      await _lerVersao();

      if (!_updater.isAvailable) {
        _mudar(EstadoAtualizacao.indisponivel);
        return;
      }

      patch = (await _updater.readCurrentPatch())?.number;
      _mudar(EstadoAtualizacao.procurando);

      final status = await _updater.checkForUpdate();
      switch (status) {
        case UpdateStatus.upToDate:
          _mudar(EstadoAtualizacao.atualizada);
        case UpdateStatus.restartRequired:
          _mudar(EstadoAtualizacao.pronta);
        case UpdateStatus.unavailable:
          _mudar(EstadoAtualizacao.indisponivel);
        case UpdateStatus.outdated:
          _mudar(EstadoAtualizacao.baixando);
          await _updater.update();
          // O patch novo vira o "próximo" até o app reabrir; mostrar o número
          // dele já deixa claro o que vai passar a rodar.
          patch = (await _updater.readNextPatch())?.number ?? patch;
          _mudar(EstadoAtualizacao.pronta);
      }
    } catch (erro) {
      debugPrint('atualizacao: $erro');
      // Uma falha aqui não pode prender o app. Se estava baixando, foi a baixa
      // que falhou; senão, seguimos como "atualizada" (ou indisponível fora do
      // Shorebird) para a faixa não gritar à toa.
      _mudar(
        estado == EstadoAtualizacao.baixando
            ? EstadoAtualizacao.falhou
            : (_updater.isAvailable
                ? EstadoAtualizacao.atualizada
                : EstadoAtualizacao.indisponivel),
      );
    } finally {
      _emCurso = false;
    }
  }

  Future<void> _lerVersao() async {
    try {
      final info = await PackageInfo.fromPlatform();
      versao = '${info.version}+${info.buildNumber}';
    } catch (_) {
      // Deixa vazio; o selo cai para o texto de reserva.
    }
  }

  void _mudar(EstadoAtualizacao novo) {
    estado = novo;
    notifyListeners();
  }
}
