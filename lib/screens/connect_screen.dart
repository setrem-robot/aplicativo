import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../app/theme.dart';
import '../services/robot_connection.dart';
import '../widgets/app_card.dart';
import '../widgets/device_tile.dart';
import 'control_screen.dart';
import 'telemetria_screen.dart';

/// PRIMEIRA TELA DO APP: escaneia por robos anunciando o servico BLE do
/// Atlas e, ao conectar, abre a [ControlScreen].
class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen>
    with SingleTickerProviderStateMixin {
  final _robot = RobotConnection.instance;

  StreamSubscription<List<ScanResult>>? _scanSub;
  List<ScanResult> _results = const [];
  bool _isScanning = false;
  String? _connectingId;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _setUpAndScan();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scanSub?.cancel();
    _robot.stopScan();
    super.dispose();
  }

  /// Sem permissao o SO devolve lista vazia sem erro (dificil de depurar).
  ///
  /// So o Android pede alguma coisa aqui, e a diferenca nao e cosmetica: no
  /// iOS o BLE nao usa permissao de localizacao, e pedir uma permissao sem a
  /// chave de descricao correspondente no `Info.plist` **derruba o app na
  /// hora** -- a Apple mata o processo, nao e um aviso. O Bluetooth em si o
  /// iOS pede sozinho, na primeira vez que o app liga o radio, usando a
  /// `NSBluetoothAlwaysUsageDescription` que ja esta declarada la.
  ///
  /// `permission_handler` tambem nao tem implementacao para desktop, entao
  /// sair fora dele evita `MissingPluginException` no Windows e no Linux.
  Future<void> _setUpAndScan() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await [
        // `bluetoothScan` e `bluetoothConnect` sao do Android 12+; nas versoes
        // anteriores o proprio plugin traduz para a permissao de localizacao,
        // que era o que o Android exigia para escanear BLE.
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ].request();
    }

    if (!await _robot.isBluetoothOn()) {
      await _robot.requestEnableBluetooth();
    }

    await _startScan();
  }

  Future<void> _startScan() async {
    await _scanSub?.cancel();
    setState(() {
      _isScanning = true;
      _results = const [];
    });

    _scanSub = _robot.scan().listen((results) {
      if (!mounted) return;
      setState(() => _results = results);
    });

    Future.delayed(const Duration(seconds: 8), () {
      if (mounted) setState(() => _isScanning = false);
    });
  }

  Future<void> _connect(BluetoothDevice device) async {
    setState(() => _connectingId = device.remoteId.str);

    final connected = await _robot.connect(device);

    if (!mounted) return;
    setState(() => _connectingId = null);

    if (connected) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ControlScreen()),
      );
    } else {
      _showError(_robot.lastError ?? 'Falha ao conectar. Tente novamente.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.danger),
    );
    _robot.clearError();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.large),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              _buildHeader(),
              const SizedBox(height: 24),
              _buildDadosButton(),
              const SizedBox(height: 24),
              _buildPulsingIcon(),
              const SizedBox(height: 40),
              Expanded(child: _buildDeviceList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    const titleStyle = TextStyle(
      fontSize: 40,
      fontWeight: FontWeight.w900,
      color: Colors.white,
      letterSpacing: -1,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ATLAS', style: titleStyle),
        // FittedBox+scaleDown: "CONTROLLER" nao cabe em 40pt em tela estreita
        // e estouraria com a listra de overflow sem isso.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: ShaderMask(
            shaderCallback: AppColors.brandGradient.createShader,
            child: const Text('CONTROLLER', style: titleStyle),
          ),
        ),
        const SizedBox(height: AppSpacing.small),
        const Text(
          'Procurando seu robo por Bluetooth',
          style: TextStyle(fontSize: 15, color: Colors.white38),
        ),
      ],
    );
  }

  /// Atalho para o historico guardado na nuvem.
  ///
  /// Fica NESTA tela, e nao na de controle, porque ver onde o robo andou ontem
  /// nao deveria exigir estar perto dele: os dados vem da API, nao do radio.
  /// Na tela de controle o botao so apareceria depois de conectar — que e
  /// exatamente a condicao que ele nao tem.
  Widget _buildDadosButton() {
    return AppCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const TelemetriaScreen()),
      ),
      child: const Row(
        children: [
          IconBadge(icon: Icons.insights_rounded),
          SizedBox(width: AppSpacing.medium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dados do robo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Trajeto, bateria e historico — funciona sem conectar',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: Colors.white24),
        ],
      ),
    );
  }

  Widget _buildPulsingIcon() {
    return Center(
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (_, child) =>
            Transform.scale(scale: _pulseAnimation.value, child: child),
        child: Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withValues(alpha: 0.2),
            border: Border.all(color: AppColors.primary, width: 2),
          ),
          child: const Icon(
            Icons.bluetooth,
            color: AppColors.primary,
            size: 52,
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Robos por perto',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
            IconButton(
              tooltip: 'Buscar novamente',
              onPressed: _isScanning ? null : _startScan,
              icon: _isScanning
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : const Icon(Icons.refresh, color: AppColors.primary),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _results.isEmpty && !_isScanning
              ? _buildEmptyState()
              : ListView.separated(
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final device = _results[i].device;
                    final isBusy = _connectingId != null;
                    return DeviceTile(
                      device: device,
                      isConnecting: _connectingId == device.remoteId.str,
                      onTap: isBusy ? null : () => _connect(device),
                    );
                  },
                ),
        ),
        const SizedBox(height: AppSpacing.medium),
        _buildScanHint(),
      ],
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bluetooth_searching, size: 48, color: Colors.white12),
          SizedBox(height: AppSpacing.medium),
          Text(
            'Nenhum robo encontrado',
            style: TextStyle(color: Colors.white38, fontSize: 15),
          ),
          SizedBox(height: AppSpacing.small),
          Text(
            'Verifique se o robo esta ligado\ne dentro do alcance',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white24, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildScanHint() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.2)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.secondary, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'BLE nao precisa de pareamento previo: so o robo estar ligado ja basta.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
