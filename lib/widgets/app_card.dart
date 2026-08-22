import 'package:flutter/material.dart';

import '../app/theme.dart';

/// O "cartao" escuro de cantos arredondados usado em quase toda tela.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.medium),
    this.borderColor,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Cor da borda. Se nao informar, usa um branco bem discreto.
  final Color? borderColor;

  /// Se informado, o cartao vira clicavel.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        border: Border.all(
          color: borderColor ?? Colors.white.withValues(alpha: 0.07),
          width: 1.5,
        ),
      ),
      child: child,
    );

    if (onTap == null) return card;

    return GestureDetector(onTap: onTap, child: card);
  }
}

/// Um quadrado colorido com um icone dentro — o "selo" que aparece a esquerda
/// dos cartoes.
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    this.size = 44,
    this.color = AppColors.primary,
  });

  final IconData icon;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: size / 2),
    );
  }
}
