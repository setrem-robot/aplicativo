import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/robot_command.dart';
import '../services/robot_connection.dart';
import '../widgets/app_card.dart';
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
          body: SafeArea(
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
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: connected ? AppColors.success : Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    connected ? 'Conectado' : 'Desconectado',
                    style: TextStyle(
                      color: connected ? AppColors.success : Colors.red,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'ROBO',
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
                Text(
                  connected ? robot.lastCommand.label : 'CONEXAO PERDIDA',
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
