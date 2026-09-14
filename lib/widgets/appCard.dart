import 'package:flutter/material.dart';

import '../app/theme.dart';

/// O "cartao" escuro de cantos arredondados usado em quase toda tela.
class AppCard extends StatefulWidget {
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
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final highlighted = widget.borderColor != null;

    // AnimatedContainer, e nao Container: quando `borderColor` muda (o cartao
    // do robo que voce acabou de tocar fica verde), a borda transita em vez
    // de piscar de uma cor para a outra.
    final card = AnimatedContainer(
      duration: AppDurations.press,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        border: Border.all(
          color: widget.borderColor ?? Colors.white.withValues(alpha: 0.07),
          width: 1.5,
        ),
        boxShadow: highlighted ? AppShadows.brandGlow(opacity: 0.22) : null,
      ),
      child: widget.child,
    );

    if (widget.onTap == null) return card;

    // O encolhimento e o unico retorno de que o toque foi registrado: estes
    // cartoes nao tem ripple do Material por serem Container puro.
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      // onTapCancel importa: sem ele, arrastar o dedo para fora deixaria o
      // cartao encolhido para sempre.
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: AppDurations.press,
        curve: Curves.easeOut,
        child: card,
      ),
    );
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
