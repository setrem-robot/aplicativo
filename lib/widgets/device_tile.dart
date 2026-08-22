import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../app/theme.dart';
import 'app_card.dart';

/// Uma linha da lista de robos encontrados no escaneamento BLE.
class DeviceTile extends StatelessWidget {
  const DeviceTile({
    super.key,
    required this.device,
    required this.onTap,
    this.isConnecting = false,
  });

  final BluetoothDevice device;
  final VoidCallback? onTap;

  /// Quando `true`, mostra a rodinha de carregando no lugar da seta.
  final bool isConnecting;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      borderColor: isConnecting ? AppColors.primary : null,
      child: Row(
        children: [
          const IconBadge(icon: Icons.developer_board),
          const SizedBox(width: AppSpacing.medium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.platformName.isNotEmpty
                      ? device.platformName
                      : 'Dispositivo sem nome',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  device.remoteId.str,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
          if (isConnecting)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primary,
              ),
            )
          else
            const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
        ],
      ),
    );
  }
}
