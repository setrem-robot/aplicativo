import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';

import '../models/robot_command.dart';

/// Em que ponto da conexao o app esta.
enum ConnectionStatus { disconnected, connecting, connected }

/// Tudo que fala com o robo passa por aqui. As telas NUNCA conversam com o
/// Bluetooth diretamente — elas pedem para este objeto.
///
/// ## Por que ele e um ChangeNotifier
///
/// A conexao pode cair sozinha (robo desligou, saiu do alcance). Quando isso
/// acontece este objeto chama `notifyListeners()` e as telas que estao
/// escutando se redesenham sozinhas mostrando "Desconectado". Antes o app
/// continuava exibindo "Conectado" para sempre, ate voce tentar mover o robo.
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

  BluetoothConnection? _connection;
  StreamSubscription<Uint8List>? _incoming;

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

  /// Lista os dispositivos ja pareados nas configuracoes do Android.
  ///
  /// Este app NAO faz busca por dispositivos novos: o ESP32 precisa ser
  /// pareado antes em Configuracoes -> Bluetooth.
  Future<List<BluetoothDevice>> pairedDevices() async {
    try {
      return await FlutterBluetoothSerial.instance.getBondedDevices();
    } catch (e) {
      _lastError = 'Nao foi possivel ler os dispositivos pareados: $e';
      notifyListeners();
      return const [];
    }
  }

  /// O radio Bluetooth do celular esta ligado?
  Future<bool> isBluetoothOn() async {
    return await FlutterBluetoothSerial.instance.isEnabled ?? false;
  }

  /// Pede ao Android para ligar o Bluetooth (mostra o dialogo do sistema).
  Future<void> requestEnableBluetooth() async {
    await FlutterBluetoothSerial.instance.requestEnable();
  }

  /// Tenta conectar. Devolve `true` se deu certo.
  Future<bool> connect(BluetoothDevice device) async {
    _lastError = null;
    _status = ConnectionStatus.connecting;
    notifyListeners();

    try {
      _connection = await BluetoothConnection.toAddress(device.address);
      _deviceName = device.name?.isNotEmpty == true ? device.name : device.address;
      _lastCommand = RobotCommand.stop;
      _status = ConnectionStatus.connected;

      // Ficamos escutando o canal de entrada por dois motivos:
      // 1. e assim que descobrimos que a conexao caiu (o `onDone` dispara);
      // 2. permite no futuro receber dados do robo (sensores, bateria...).
      _incoming = _connection!.input.listen(
        _onDataFromRobot,
        onDone: () => _handleDrop('O robo encerrou a conexao.'),
        onError: (Object e) => _handleDrop('Erro na conexao: $e'),
        cancelOnError: true,
      );

      notifyListeners();
      return true;
    } catch (e) {
      _lastError = 'Falha ao conectar. Verifique se o robo esta ligado.';
      _status = ConnectionStatus.disconnected;
      _connection = null;
      notifyListeners();
      return false;
    }
  }

  /// Envia um comando para o robo.
  ///
  /// O formato do que vai pelo ar e `{"cmd":"F"}` seguido de uma quebra de
  /// linha. O firmware do ESP32 espera exatamente isso — se mudar aqui,
  /// tem que mudar la tambem.
  Future<void> send(RobotCommand command) async {
    final connection = _connection;
    if (connection == null || !isConnected) return;

    try {
      final payload = '{"cmd":"${command.code}"}\n';
      connection.output.add(Uint8List.fromList(utf8.encode(payload)));
      await connection.output.allSent;
      _lastCommand = command;
      notifyListeners();
    } catch (e) {
      _handleDrop('Nao foi possivel enviar o comando.');
    }
  }

  /// Encerra a conexao de proposito (o usuario apertou o botao de sair).
  Future<void> disconnect() async {
    await _incoming?.cancel();
    _incoming = null;
    await _connection?.close();
    _connection = null;
    _deviceName = null;
    _lastCommand = RobotCommand.stop;
    _status = ConnectionStatus.disconnected;
    notifyListeners();
  }

  /// Chamado quando chegam bytes vindos do robo.
  ///
  /// Hoje o app so escreve no log de depuracao. Se um dia o ESP32 mandar
  /// telemetria (bateria, distancia), o tratamento entra aqui.
  void _onDataFromRobot(Uint8List data) {
    if (kDebugMode) {
      debugPrint('Robo respondeu: ${utf8.decode(data, allowMalformed: true)}');
    }
  }

  /// A conexao caiu sem o usuario pedir.
  void _handleDrop(String reason) {
    if (_status == ConnectionStatus.disconnected) return;
    _lastError = reason;
    _status = ConnectionStatus.disconnected;
    _incoming?.cancel();
    _incoming = null;
    _connection = null;
    notifyListeners();
  }

  /// Limpa a mensagem de erro depois que a tela ja a mostrou.
  void clearError() {
    if (_lastError == null) return;
    _lastError = null;
    notifyListeners();
  }
}
