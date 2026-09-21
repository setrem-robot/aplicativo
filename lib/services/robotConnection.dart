import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/iaModo.dart';
import '../models/robotCommand.dart';
import '../models/rotaSegura.dart';

/// Em que ponto da conexao o app esta.
enum ConnectionStatus { disconnected, connecting, connected }

/// UUIDs do servico BLE que o robo expoe (padrao Nordic UART Service).
/// Se mudar aqui, tem que mudar na ponte BLE do robo tambem
/// (RobotEye, `src/roboteye/ble/nus.py`).
class RobotBleIds {
  RobotBleIds._();

  static final serviceUuid = Guid('6e400001-b5a3-f393-e0a9-e50e24dcca9e');
  static final rxCharacteristicUuid = Guid(
    '6e400002-b5a3-f393-e0a9-e50e24dcca9e',
  ); // celular escreve aqui
  static final txCharacteristicUuid = Guid(
    '6e400003-b5a3-f393-e0a9-e50e24dcca9e',
  ); // o robo notifica aqui
}

/// Tudo que fala com o robo passa por aqui — as telas nunca conversam com o
/// Bluetooth diretamente. E um `ChangeNotifier` porque a conexao pode cair
/// sozinha (robo desligou, saiu do alcance); quando isso acontece,
/// `notifyListeners()` avisa as telas escutando, que se redesenham mostrando
/// "Desconectado" sem precisar de nenhum polling.
class RobotConnection extends ChangeNotifier {
  RobotConnection._() {
    // A escolha de IA e conveniencia local, como o filtro e o endereco da API:
    // carrega no arranque e, quando chega, avisa as telas para refletirem o
    // que a pessoa deixou marcado. Nunca lanca — um valor de versao antiga
    // vira o padrao.
    _restaurarIaModo();
  }

  /// So ha um robo e um radio Bluetooth por app.
  static final RobotConnection instance = RobotConnection._();

  /// Onde a preferencia de IA fica guardada entre sessoes.
  static const _chaveIaModo = 'ia_modo';

  BluetoothDevice? _device;
  BluetoothCharacteristic? _rxCharacteristic;
  StreamSubscription<BluetoothConnectionState>? _connectionSub;
  StreamSubscription<List<int>>? _notifySub;

  ConnectionStatus _status = ConnectionStatus.disconnected;
  ConnectionStatus get status => _status;

  bool get isConnected => _status == ConnectionStatus.connected;

  String? _deviceName;
  String? get deviceName => _deviceName;

  RobotCommand _lastCommand = RobotCommand.stop;
  RobotCommand get lastCommand => _lastCommand;

  /// Qual IA o robo deve usar. Nasce em nuvem, mas o valor guardado da ultima
  /// vez sobrescreve isso assim que carrega. E enviado ao robo ao conectar e a
  /// cada troca no switch, para os dois lados nunca discordarem.
  IaModo _iaModo = IaModo.nuvem;
  IaModo get iaModo => _iaModo;

  /// Repete o comando de movimento enquanto o dedo estiver no botao. Ver
  /// [send] para o porque.
  Timer? _repeater;

  /// De quanto em quanto tempo repetir. O lado do robo para os motores depois
  /// de 1 s sem noticias, entao isto da margem para tres repeticoes perdidas.
  static const _repeatInterval = Duration(milliseconds: 300);

  /// `null` = sem erro.
  String? _lastError;
  String? get lastError => _lastError;

  /// BLE nao usa pareamento previo do sistema como o Classic usava: escaneia
  /// e conecta direto em quem estiver anunciando o servico certo.
  Stream<List<ScanResult>> scan({
    Duration timeout = const Duration(seconds: 8),
  }) {
    FlutterBluePlus.startScan(
      withServices: [RobotBleIds.serviceUuid],
      timeout: timeout,
    );
    return FlutterBluePlus.scanResults;
  }

  Future<void> stopScan() => FlutterBluePlus.stopScan();

  Future<bool> isBluetoothOn() async {
    return await FlutterBluePlus.adapterState.first ==
        BluetoothAdapterState.on;
  }

  /// So funciona no Android — no iOS a Apple nao deixa apps ligarem o
  /// Bluetooth sozinhos, o usuario precisa ir nos Ajustes.
  Future<void> requestEnableBluetooth() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await FlutterBluePlus.turnOn();
    }
  }

  Future<bool> connect(BluetoothDevice device) async {
    _lastError = null;
    _status = ConnectionStatus.connecting;
    notifyListeners();

    await FlutterBluePlus.stopScan();

    try {
      // License.nonprofit: projeto academico sem fins lucrativos (PIE da
      // Setrem) -- exigido pela licenca do flutter_blue_plus.
      await device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 10),
      );

      // No BLE nao existe "onDone" de stream como no Classic; o estado da
      // conexao e o unico sinal confiavel de que o robo caiu.
      _connectionSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _handleDrop('O robo encerrou a conexao.');
        }
      });

      final services = await device.discoverServices();
      final service = services.firstWhere(
        (s) => s.uuid == RobotBleIds.serviceUuid,
        orElse: () =>
            throw Exception('O robo nao expoe o servico BLE esperado.'),
      );

      _rxCharacteristic = service.characteristics.firstWhere(
        (c) => c.uuid == RobotBleIds.rxCharacteristicUuid,
        orElse: () =>
            throw Exception('Servico BLE sem a caracteristica de comando.'),
      );

      final txCharacteristic = service.characteristics.firstWhere(
        (c) => c.uuid == RobotBleIds.txCharacteristicUuid,
        orElse: () =>
            throw Exception('Servico BLE sem a caracteristica de resposta.'),
      );
      await txCharacteristic.setNotifyValue(true);
      _notifySub = txCharacteristic.onValueReceived.listen(_onDataFromRobot);

      _device = device;
      _deviceName = device.platformName.isNotEmpty
          ? device.platformName
          : device.remoteId.str;
      _lastCommand = RobotCommand.stop;
      _status = ConnectionStatus.connected;
      notifyListeners();
      // O robo sobe sempre em nuvem; se a pessoa tinha deixado "local"
      // marcado, os dois lados discordariam ate o primeiro toque no switch.
      // Empurrar a escolha atual aqui alinha os dois logo na conexao.
      await _enviarIaModo();
      return true;
    } catch (e) {
      _lastError = 'Falha ao conectar. Verifique se o robo esta ligado.';
      _status = ConnectionStatus.disconnected;
      await device.disconnect();
      _device = null;
      notifyListeners();
      return false;
    }
  }

  /// Manda o comando e, se for movimento, continua mandando ate parar.
  ///
  /// A repeticao nao e capricho: o app manda o comando quando o dedo desce e
  /// `stop` quando o dedo sobe, e entre os dois nao passa nada. Se a conexao
  /// morrer justamente nesse intervalo -- o celular saiu de alcance, ficou sem
  /// bateria, o app foi fechado --, o `stop` nunca chega e o robo fica andando
  /// sozinho. Repetindo, o silencio passa a significar "pare": o servico de
  /// motores no Raspberry Pi para os motores quando fica 1 s sem receber nada
  /// (ver `motores/vigia.py` no repositorio do orquestrador).
  ///
  /// Payload `{"cmd":"F"}\n` -- a ponte BLE do robo espera exatamente esse
  /// formato; mudou aqui, muda la tambem.
  Future<void> send(RobotCommand command) async {
    _repeater?.cancel();
    _repeater = null;

    final enviou = await _write(command);
    if (!enviou) return;

    _lastCommand = command;
    notifyListeners();

    if (command != RobotCommand.stop) {
      _repeater = Timer.periodic(_repeatInterval, (_) => _write(command));
    }
  }

  Future<bool> _write(RobotCommand command) =>
      _writeRaw('{"cmd":"${command.code}"}');

  /// Troca a IA do robo (switch da tela de controle).
  ///
  /// Guarda a escolha e avisa as telas na hora — o switch responde ao toque
  /// mesmo que o envio demore — e so entao manda ao robo. Desconectado, a
  /// preferencia fica guardada e vai junto na proxima conexao.
  Future<void> setIaModo(IaModo modo) async {
    _iaModo = modo;
    notifyListeners();
    await _salvarIaModo(modo);
    if (isConnected) await _enviarIaModo();
  }

  Future<bool> _enviarIaModo() =>
      _writeRaw('{"tipo":"ia","modo":"${_iaModo.code}"}');

  Future<void> _restaurarIaModo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _iaModo = IaModo.fromCode(prefs.getString(_chaveIaModo));
      notifyListeners();
    } catch (_) {
      // Sem persistencia (primeira execucao, armazenamento indisponivel): fica
      // o padrao. Preferencia perdida nao pode impedir o app de abrir.
    }
  }

  Future<void> _salvarIaModo(IaModo modo) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chaveIaModo, modo.code);
    } catch (_) {
      // Idem: guardar e conveniencia, nao requisito.
    }
  }

  /// Escreve uma linha JSON crua na caracteristica. Devolve false se nao deu.
  ///
  /// O `\n` final e o delimitador que a ponte BLE do robo usa para saber onde
  /// uma mensagem termina; por isso ele entra aqui, num lugar so, e nao em cada
  /// chamador.
  ///
  /// `withoutResponse` porque comando de direcao e sempre substituivel: o
  /// proximo ja esta a caminho, e esperar a confirmacao de cada um so
  /// adicionaria atraso entre o dedo e a roda.
  Future<bool> _writeRaw(String linhaJson) async {
    final characteristic = _rxCharacteristic;
    if (characteristic == null || !isConnected) return false;

    try {
      await characteristic.write(utf8.encode('$linhaJson\n'), withoutResponse: true);
      return true;
    } catch (e) {
      _handleDrop('Nao foi possivel enviar o comando.');
      return false;
    }
  }

  /// Envia a rota segura planejada no app, fatiada em linhas que cabem no limite
  /// BLE (ver [RotaSegura.paraMensagensBle]). Devolve false se a conexao caiu no
  /// meio — o chamador mostra o resultado.
  ///
  /// Um respiro entre as linhas evita empurrar varias mensagens no mesmo pacote
  /// e dar mais margem para o `withoutResponse` (que nao confirma entrega) sob
  /// congestionamento do radio. Como sao poucos pontos, o custo total e de
  /// fracao de segundo.
  Future<bool> enviarRota(RotaSegura rota) async {
    if (!isConnected) return false;
    for (final linha in rota.paraMensagensBle()) {
      if (!await _writeRaw(linha)) return false;
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
    return true;
  }

  void _stopRepeating() {
    _repeater?.cancel();
    _repeater = null;
  }

  Future<void> disconnect() async {
    _stopRepeating();
    await _notifySub?.cancel();
    _notifySub = null;
    await _connectionSub?.cancel();
    _connectionSub = null;
    await _device?.disconnect();
    _device = null;
    _rxCharacteristic = null;
    _deviceName = null;
    _lastCommand = RobotCommand.stop;
    _status = ConnectionStatus.disconnected;
    notifyListeners();
  }

  void _onDataFromRobot(List<int> data) {
    // So log de depuracao por enquanto; telemetria futura (bateria,
    // distancia) entraria aqui.
    if (kDebugMode) {
      debugPrint('Robo respondeu: ${utf8.decode(data, allowMalformed: true)}');
    }
  }

  void _handleDrop(String reason) {
    if (_status == ConnectionStatus.disconnected) return;
    // Sem isto o timer continuaria acordando para escrever numa caracteristica
    // que nao existe mais, uma vez a cada 300 ms, para sempre.
    _stopRepeating();
    _lastError = reason;
    _status = ConnectionStatus.disconnected;
    _notifySub?.cancel();
    _notifySub = null;
    _connectionSub?.cancel();
    _connectionSub = null;
    _device = null;
    _rxCharacteristic = null;
    notifyListeners();
  }

  void clearError() {
    if (_lastError == null) return;
    _lastError = null;
    notifyListeners();
  }
}
