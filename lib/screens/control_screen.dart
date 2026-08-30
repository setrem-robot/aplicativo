import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/robot_command.dart';
import '../services/robot_connection.dart';
import 'rota_segura_screen.dart';
import '../widgets/app_card.dart';
import '../widgets/brand_glow.dart';
import '../widgets/direction_pad.dart';

/// SEGUNDA TELA DO APP: o controle do robo.
///
/// Ela e envolvida por um [ListenableBuilder] que escuta a [RobotConnection].
/// Sempre que a conexao muda de estado — inclusive quando cai sozinha — esta
/// tela se redesenha. E por isso que o indicador "Conectado / Desconectado"
/// agora fala a verdade.
class ControlScreen extends StatelessWidget {
  const ControlScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final robot = RobotConnection.instance;

    return ListenableBuilder(
      listenable: robot,
      builder: (context, _) {
        return Scaffold(
          body: Stack(
            children: [
              const BrandGlow(alignment: Alignment(0, 0.35)),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.large,
                    vertical: 20,
                  ),
                  child: Column(
                    children: [
                      _TopBar(robot: robot),
                      const SizedBox(height: 20),
                      _StatusCard(robot: robot),
                      const Spacer(),
                      DirectionPad(
                        enabled: robot.isConnected,
                        onPress: robot.send,
                        onRelease: () => robot.send(RobotCommand.stop),
                      ),
                      const Spacer(),
                      const _CommandLegend(),
                      const SizedBox(height: AppSpacing.medium),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Barra superior: botao de desconectar, nome do robo e o selo da marca.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.robot});

  final RobotConnection robot;

  Future<void> _disconnect(BuildContext context) async {
    final navigator = Navigator.of(context);
    await robot.disconnect();
    // `pop` devolve para a tela de conexao, que continua viva por baixo.
    if (navigator.canPop()) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final connected = robot.isConnected;

    return Row(
      children: [
        AppCard(
          onTap: () => _disconnect(context),
          padding: const EdgeInsets.all(10),
          child: const Icon(
            Icons.bluetooth_disabled,
            color: Colors.redAccent,
            size: 20,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                robot.deviceName ?? 'Robo',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Row(
                children: [
                  _StatusDot(connected: connected),
                  const SizedBox(width: 5),
                  // AnimatedDefaultTextStyle: a cor viaja de verde a vermelho
                  // quando a conexao cai, em vez de trocar num quadro so.
                  AnimatedDefaultTextStyle(
                    duration: AppDurations.swap,
                    style: TextStyle(
                      color: connected ? AppColors.success : Colors.red,
                      fontSize: 12,
                    ),
                    child: Text(connected ? 'Conectado' : 'Desconectado'),
                  ),
                ],
              ),
            ],
          ),
        ),
        AppCard(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const RotaSeguraScreen()),
          ),
          padding: const EdgeInsets.all(10),
          child: const Icon(Icons.route_rounded, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'ATLAS v2',
            style: TextStyle(
              // Escuro, e nao branco: este selo e pintado com o degrade da
              // marca, que agora e verde claro nas duas pontas. Texto branco
              // em cima dele sumia.
              color: AppColors.onBrand,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

/// Cartao que mostra o ultimo comando enviado — ou o aviso de queda de conexao.
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.robot});

  final RobotConnection robot;

  @override
  Widget build(BuildContext context) {
    final connected = robot.isConnected;
    final isMoving = connected && robot.lastCommand != RobotCommand.stop;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          IconBadge(
            icon: connected ? Icons.sports_esports : Icons.link_off,
            size: 40,
            color: connected ? AppColors.primary : Colors.redAccent,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'STATUS ATUAL',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 2),
                // O rotulo muda a cada toque na cruz. Trocar o texto seco
                // fazia a linha "piscar"; com o switcher ele se dissolve.
                AnimatedSwitcher(
                  duration: AppDurations.press,
                  child: Text(
                    connected ? robot.lastCommand.label : 'CONEXAO PERDIDA',
                    // A key e o proprio texto: sem ela o switcher acha que e
                    // o mesmo widget e nao anima a troca.
                    key: ValueKey(
                      connected ? robot.lastCommand : 'perdida',
                    ),
                    style: TextStyle(
                      color: !connected
                          ? Colors.redAccent
                          : isMoving
                              ? AppColors.primary
                              : Colors.white54,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Rodape com a tabela "letra -> movimento". Serve de referencia rapida para
/// quem for mexer no firmware do ESP32.
class _CommandLegend extends StatelessWidget {
  const _CommandLegend();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      borderColor: Colors.white.withValues(alpha: 0.05),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        // A legenda e montada a partir do proprio enum: adicionou um comando
        // novo em RobotCommand, ele aparece aqui sozinho.
        children: RobotCommand.values.map((command) {
          // Expanded divide a largura em partes iguais: assim a legenda nunca
          // "estoura" a tela, mesmo num celular estreito.
          return Expanded(
            child: Column(
              children: [
                Icon(command.icon, color: Colors.white30, size: 18),
                const SizedBox(height: 2),
                Text(
                  command.code,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  command.label,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white24, fontSize: 9),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// O pontinho ao lado de "Conectado".
///
/// Quando conectado ele respira devagar; caido, fica parado em vermelho. Um
/// ponto que pulsa diz "o link esta vivo agora" -- um ponto verde parado
/// poderia ser so uma tela congelada.
class _StatusDot extends StatefulWidget {
  const _StatusDot({required this.connected});

  final bool connected;

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.connected) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_StatusDot old) {
    super.didUpdateWidget(old);
    if (widget.connected == old.connected) return;
    if (widget.connected) {
      _controller.repeat(reverse: true);
    } else {
      // Volta ao brilho cheio antes de parar: congelar no meio do ciclo
      // deixaria o ponto vermelho apagado pela metade.
      _controller.animateTo(0, duration: AppDurations.swap);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.connected ? AppColors.success : Colors.red;

    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        // O halo cresce e some junto com o ciclo.
        final t = _controller.value;
        return Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.5 * (1 - t)),
                blurRadius: 4 + 6 * t,
                spreadRadius: 1 + 2 * t,
              ),
            ],
          ),
        );
      },
    );
  }
}
