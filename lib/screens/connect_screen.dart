import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../app/theme.dart';
import '../services/robot_connection.dart';
import '../widgets/device_tile.dart';
import 'control_screen.dart';

/// PRIMEIRA TELA DO APP.
///
/// Mostra os dispositivos Bluetooth ja pareados no Android e deixa o usuario
/// escolher um. Ao conectar com sucesso, abre a [ControlScreen].
class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen>
    with SingleTickerProviderStateMixin {
  final _robot = RobotConnection.instance;

  List<BluetoothDevice> _devices = const [];
  bool _isLoading = false;
  String? _connectingAddress;

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
    _setUpAndLoad();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  /// Pede as permissoes do Android, garante que o Bluetooth esta ligado e
  /// entao carrega a lista. Sem as permissoes o Android devolve uma lista
  /// vazia sem dar erro nenhum, o que confunde muito na hora de depurar.
  Future<void> _setUpAndLoad() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.locationWhenInUse,
    ].request();

    if (!await _robot.isBluetoothOn()) {
      await _robot.requestEnableBluetooth();
    }

    await _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() => _isLoading = true);
    final devices = await _robot.pairedDevices();
    if (!mounted) return;
    setState(() {
      _devices = devices;
      _isLoading = false;
    });
  }

  Future<void> _connect(BluetoothDevice device) async {
    setState(() => _connectingAddress = device.address);

    final connected = await _robot.connect(device);

    if (!mounted) return;
    setState(() => _connectingAddress = null);

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
              const SizedBox(height: 40),
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
        // ShaderMask pinta o texto com o degrade da marca.
        //
        // O FittedBox existe porque "CONTROLLER" e uma palavra longa: em
        // celular estreito ela nao cabe em 40pt e o Flutter desenharia a
        // listra amarela de overflow. Com `scaleDown` o texto so encolhe
        // quando falta espaco -- na maioria dos aparelhos ele fica no
        // tamanho cheio, igual a linha de cima.
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
          'Conecte ao seu ESP32',
          style: TextStyle(fontSize: 15, color: Colors.white38),
        ),
      ],
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
              'Dispositivos Pareados',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
            IconButton(
              tooltip: 'Atualizar lista',
              onPressed: _isLoading ? null : _loadDevices,
              icon: _isLoading
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
          child: _devices.isEmpty && !_isLoading
              ? _buildEmptyState()
              : ListView.separated(
                  itemCount: _devices.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final device = _devices[i];
                    final isBusy = _connectingAddress != null;
                    return DeviceTile(
                      device: device,
                      isConnecting: _connectingAddress == device.address,
                      onTap: isBusy ? null : () => _connect(device),
                    );
                  },
                ),
        ),
        const SizedBox(height: AppSpacing.medium),
        _buildPairHint(),
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
            'Nenhum dispositivo encontrado',
            style: TextStyle(color: Colors.white38, fontSize: 15),
          ),
          SizedBox(height: AppSpacing.small),
          Text(
            'Pareie o ESP32 nas\nconfiguracoes do Android primeiro',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white24, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildPairHint() {
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
              'Para parear: Configuracoes -> Bluetooth -> Adicionar dispositivo',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
