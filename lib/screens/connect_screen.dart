import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../app/theme.dart';
import '../services/robot_connection.dart';
import '../widgets/app_card.dart';
import '../widgets/device_tile.dart';
import '../widgets/brand_glow.dart';
import '../widgets/radar_pulse.dart';
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

  /// Anima a entrada da tela. Roda uma vez so, na abertura.
  late final AnimationController _enterController;

  @override
  void initState() {
    super.initState();
    _enterController = AnimationController(
      vsync: this,
      duration: AppDurations.enter,
    )..forward();
    _setUpAndScan();
  }

  @override
  void dispose() {
    _enterController.dispose();
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
      body: Stack(
        children: [
          const BrandGlow(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.large),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  // Os quatro blocos entram em sequencia, de cima para baixo.
                  // O olho segue a ordem em vez de receber a tela pronta de
                  // uma vez -- e o que faz a abertura parecer calma.
                  _entrance(order: 0, child: _buildHeader()),
                  const SizedBox(height: 24),
                  // Antes do radar de proposito: ver os dados nao depende de
                  // conectar, entao o atalho nao deve ficar atras do que so
                  // serve para conectar.
                  _entrance(order: 1, child: _buildDadosButton()),
                  const SizedBox(height: 36),
                  _entrance(order: 2, child: Center(child: _buildRadar())),
                  const SizedBox(height: 36),
                  Expanded(
                    child: _entrance(order: 3, child: _buildDeviceList()),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Fade + sobe alguns pixels, com atraso proporcional a [order].
  Widget _entrance({required int order, required Widget child}) {
    // Interval recorta um pedaco do controller para cada bloco: o de baixo so
    // comeca quando o de cima ja esta na metade.
    final curve = CurvedAnimation(
      parent: _enterController,
      curve: Interval(order * 0.15, 0.7 + order * 0.1, curve: Curves.easeOut),
    );

    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(curve),
        child: child,
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
        // e estouraria com a listra de overflow sem isso. O selo "v2" entra
        // dentro do mesmo FittedBox para encolher junto com a palavra, em vez
        // de continuar grande e empurrar o texto.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ShaderMask(
                shaderCallback: AppColors.brandGradient.createShader,
                child: const Text('CONTROLLER', style: titleStyle),
              ),
              const SizedBox(width: 10),
              const _VersionBadge(),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.small),
        const Text(
          'Procurando seu robo por Bluetooth Low Energy',
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

  Widget _buildRadar() => RadarPulse(isScanning: _isScanning);

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
          // Sem o AnimatedSwitcher, o "Nenhum robo encontrado" era trocado
          // pela lista num corte seco no meio do escaneamento.
          child: AnimatedSwitcher(
            duration: AppDurations.swap,
            child: _results.isEmpty && !_isScanning
                ? _buildEmptyState()
                : ListView.separated(
                    // A key diz ao AnimatedSwitcher que isto e outro widget:
                    // sem ela ele nao percebe a troca e nao anima nada.
                    key: const ValueKey('lista'),
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final device = _results[i].device;
                      final isBusy = _connectingId != null;
                      return _TileEntrance(
                        // A key e o endereco BLE: sem ela o Flutter reusaria
                        // a posicao da lista e um robo novo herdaria a
                        // animacao ja terminada do que estava ali antes.
                        key: ValueKey(device.remoteId.str),
                        child: DeviceTile(
                          device: device,
                          isConnecting: _connectingId == device.remoteId.str,
                          onTap: isBusy ? null : () => _connect(device),
                        ),
                      );
                    },
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.medium),
        _buildScanHint(),
      ],
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      key: ValueKey('vazio'),
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

/// O selo "v2" ao lado do titulo.
class _VersionBadge extends StatelessWidget {
  const _VersionBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'v2',
        style: TextStyle(
          // Escuro sobre o degrade da marca: o degrade e verde claro nas duas
          // pontas e engoliria texto branco.
          color: AppColors.onBrand,
          fontSize: 16,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Faz um robo recem-descoberto entrar deslizando da direita, em vez de
/// aparecer de estalo no meio da lista.
class _TileEntrance extends StatefulWidget {
  const _TileEntrance({super.key, required this.child});

  final Widget child;

  @override
  State<_TileEntrance> createState() => _TileEntranceState();
}

class _TileEntranceState extends State<_TileEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppDurations.swap,
  )..forward();

  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0.12, 0),
          end: Offset.zero,
        ).animate(_curve),
        child: widget.child,
      ),
    );
  }
}
