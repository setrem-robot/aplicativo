import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../app/versao.dart';

/// Um selo pequeno de versão, no canto superior direito, em todas as telas.
///
/// Fica sobre o app inteiro (montado uma vez no `MaterialApp.builder`), então
/// nenhuma tela precisa saber que ele existe — some no dia em que o build
/// deixar de ser `dev` mexendo num arquivo só.
///
/// `IgnorePointer` porque ele não é botão: se ficasse capturando toque, comeria
/// o clique de qualquer coisa que passasse embaixo dele no canto da tela.
class SeloVersao extends StatelessWidget {
  const SeloVersao({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Num build estável o selo não aparece — a constante decide, não a tela.
    if (kAppCanal != 'dev') return child;

    return Stack(
      children: [
        child,
        Positioned(
          top: MediaQuery.of(context).padding.top + 6,
          right: 8,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
              ),
              child: Text(
                kVersaoCurta,
                style: TextStyle(
                  color: AppColors.primary.withValues(alpha: 0.9),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
