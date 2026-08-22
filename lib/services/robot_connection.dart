import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/robot_command.dart';

/// Em que ponto da conexao o app esta.
enum ConnectionStatus { disconnected, connecting, connected }

/// UUIDs do servico BLE que o ESP32 expoe (padrao Nordic UART Service).
/// Se mudar aqui, tem que mudar em `esp32_ble_bridge.ino` tambem.
class RobotBleIds {
  RobotBleIds._();

  static final serviceUuid = Guid('6e400001-b5a3-f393-e0a9-e50e24dcca9e');
  static final rxCharacteristicUuid = Guid(
    '6e400002-b5a3-f393-e0a9-e50e24dcca9e',
  ); // celular escreve aqui
  static final txCharacteristicUuid = Guid(
    '6e400003-b5a3-f393-e0a9-e50e24dcca9e',
  ); // ESP32 notifica aqui
}

/// Tudo que fala com o robo passa por aqui — as telas nunca conversam com o
/// Bluetooth diretamente. E um `ChangeNotifier` porque a conexao pode cair
/// sozinha (robo desligou, saiu do alcance); quando isso acontece,
/// `notifyListeners()` avisa as telas escutando, que se redesenham mostrando
/// "Desconectado" sem precisar de nenhum polling.
class RobotConnection extends ChangeNotifier {
  RobotConnection._();

  /// So ha um robo e um radio Bluetooth por app.
  static final RobotConnection instance = RobotConnection._();

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

  /// Payload `{"cmd":"F"}\n` -- o firmware do ESP32 espera exatamente esse
  /// formato; mudou aqui, muda la tambem.
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

  void _onDataFromRobot(List<int> data) {
    // So log de depuracao por enquanto; telemetria futura (bateria,
    // distancia) entraria aqui.
    if (kDebugMode) {
      debugPrint('Robo respondeu: ${utf8.decode(data, allowMalformed: true)}');
    }
  }

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

  void clearError() {
    if (_lastError == null) return;
    _lastError = null;
    notifyListeners();
  }
}
