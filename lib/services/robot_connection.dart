import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/robot_command.dart';

/// Em que ponto da conexao o app esta.
enum ConnectionStatus { disconnected, connecting, connected }

/// UUIDs do servico BLE que o ESP32 expoe (padrao Nordic UART Service —
/// NUS, o mesmo usado por praticamente todo firmware BLE "serial-like").
/// Se mudar aqui, tem que mudar em `esp32_ble_bridge.ino` tambem.
class RobotBleIds {
  RobotBleIds._();

  static final serviceUuid = Guid('6e400001-b5a3-f393-e0a9-e50e24dcca9e');

  /// O celular escreve aqui — comandos indo para o robo.
  static final rxCharacteristicUuid = Guid(
    '6e400002-b5a3-f393-e0a9-e50e24dcca9e',
  );

  /// O ESP32 notifica aqui — acks e futura telemetria vindo do robo.
  static final txCharacteristicUuid = Guid(
    '6e400003-b5a3-f393-e0a9-e50e24dcca9e',
  );
}

/// Tudo que fala com o robo passa por aqui. As telas NUNCA conversam com o
/// Bluetooth diretamente — elas pedem para este objeto.
///
/// ## Por que ele e um ChangeNotifier
///
/// A conexao pode cair sozinha (robo desligou, saiu do alcance). Quando isso
/// acontece este objeto chama `notifyListeners()` e as telas que estao
/// escutando se redesenham sozinhas mostrando "Desconectado".
///
/// ## Como usar em uma tela
///
/// ```dart
/// ListenableBuilder(
///   listenable: RobotConnection.instance,
///   builder: (context, _) => Text(RobotConnection.instance.isConnected ? 'ok' : 'caiu'),
/// )
/// ```
class RobotConnection extends ChangeNotifier {
  RobotConnection._();

  /// Existe um unico objeto de conexao no app inteiro (so ha um robo e um
  /// radio Bluetooth). Use sempre `RobotConnection.instance`.
  static final RobotConnection instance = RobotConnection._();

  BluetoothDevice? _device;
  BluetoothCharacteristic? _rxCharacteristic;
  StreamSubscription<BluetoothConnectionState>? _connectionSub;
  StreamSubscription<List<int>>? _notifySub;

  ConnectionStatus _status = ConnectionStatus.disconnected;
  ConnectionStatus get status => _status;

  bool get isConnected => _status == ConnectionStatus.connected;

  /// Nome do robo conectado, para a tela mostrar no topo.
  String? _deviceName;
  String? get deviceName => _deviceName;

  /// Ultimo comando enviado com sucesso. A tela de controle usa para o
  /// cartao "STATUS ATUAL".
  RobotCommand _lastCommand = RobotCommand.stop;
  RobotCommand get lastCommand => _lastCommand;

  /// Descricao do ultimo erro, para mostrar ao usuario. `null` = sem erro.
  String? _lastError;
  String? get lastError => _lastError;

  /// Escaneia por robos anunciando o servico BLE do Atlas.
  ///
  /// Diferente do Bluetooth Classic (que exigia parear o ESP32 antes, nas
  /// configuracoes do sistema), BLE nao usa pareamento previo: o app escaneia
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

  /// O radio Bluetooth do celular esta ligado?
  Future<bool> isBluetoothOn() async {
    return await FlutterBluePlus.adapterState.first ==
        BluetoothAdapterState.on;
  }

  /// Pede para ligar o Bluetooth. So funciona no Android — no iOS o usuario
  /// precisa ligar manualmente pelos Ajustes (a Apple nao deixa apps fazerem
  /// isso sozinhos).
  Future<void> requestEnableBluetooth() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await FlutterBluePlus.turnOn();
    }
  }

  /// Tenta conectar. Devolve `true` se deu certo.
  Future<bool> connect(BluetoothDevice device) async {
    _lastError = null;
    _status = ConnectionStatus.connecting;
    notifyListeners();

    await FlutterBluePlus.stopScan();

    try {
      // `License.nonprofit`: este e um projeto academico (PIE da Setrem),
      // sem fins lucrativos — se o app for comercializado algum dia, troque
      // para `License.commercial` (paga). Veja a licenca do flutter_blue_plus.
      await device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 10),
      );

      // Ficamos escutando o estado da conexao por dois motivos:
      // 1. e assim que descobrimos que a conexao caiu (o robo desligou, saiu
      //    de alcance...);
      // 2. no BLE, ao contrario do Classic, nao existe "onDone" de stream —
      //    o estado da conexao e o unico sinal confiavel disso.
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

  /// Envia um comando para o robo.
  ///
  /// O formato do que vai pelo ar e `{"cmd":"F"}` seguido de uma quebra de
  /// linha. O firmware do ESP32 espera exatamente isso — se mudar aqui, tem
  /// que mudar la tambem. So o transporte mudou (BLE em vez de Classic); o
  /// formato da mensagem continua o mesmo de propositio, para nao precisar
  /// tocar no resto do firmware.
  Future<void> send(RobotCommand command) async {
    final characteristic = _rxCharacteristic;
    if (characteristic == null || !isConnected) return;

    try {
      final payload = '{"cmd":"${command.code}"}\n';
      await characteristic.write(utf8.encode(payload), withoutResponse: true);
      _lastCommand = command;
      notifyListeners();
    } catch (e) {
      _handleDrop('Nao foi possivel enviar o comando.');
    }
  }

  /// Encerra a conexao de proposito (o usuario apertou o botao de sair).
  Future<void> disconnect() async {
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

  /// Chamado quando chegam bytes vindos do robo pela caracteristica de
  /// notificacao.
  ///
  /// Hoje o app so escreve no log de depuracao. Se um dia o ESP32 mandar
  /// telemetria (bateria, distancia), o tratamento entra aqui.
  void _onDataFromRobot(List<int> data) {
    if (kDebugMode) {
      debugPrint('Robo respondeu: ${utf8.decode(data, allowMalformed: true)}');
    }
  }

  /// A conexao caiu sem o usuario pedir.
  void _handleDrop(String reason) {
    if (_status == ConnectionStatus.disconnected) return;
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

  /// Limpa a mensagem de erro depois que a tela ja a mostrou.
  void clearError() {
    if (_lastError == null) return;
    _lastError = null;
    notifyListeners();
  }
}
