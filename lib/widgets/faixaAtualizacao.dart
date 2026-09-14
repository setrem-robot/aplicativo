import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../services/atualizacao.dart';

/// A faixa que diz, de relance, se o app está baixando uma atualização.
///
/// Aparece só quando há o que dizer — procurando, baixando, pronta ou falhou —
/// e some (encolhe a zero) quando o app já está no patch mais novo ou quando o
/// Shorebird não está disponível (build de debug). É esse recolhimento que a
/// torna barata de deixar sempre montada no topo da tela inicial.
///
/// Escuta o [AtualizacaoService] por um `AnimatedBuilder`; não guarda estado
/// próprio. Tocar nela re-checa — útil se a pessoa quer forçar uma olhada.
class FaixaAtualizacao extends StatelessWidget {
  const FaixaAtualizacao({super.key, required this.servico});

  final AtualizacaoService servico;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: servico,
      builder: (context, _) {
        final visual = _visualDe(servico.estado);
        return AnimatedSize(
          duration: AppDurations.swap,
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: visual == null
              ? const SizedBox(width: double.infinity)
              : _Faixa(visual: visual, aoTocar: servico.verificar),
        );
      },
    );
  }
}

class _Visual {
  const _Visual({
    required this.texto,
    required this.cor,
    required this.icone,
    this.girando = false,
  });

  final String texto;
  final Color cor;

  /// `null` no estado "baixando": ali entra um giro no lugar do ícone.
  final IconData? icone;
  final bool girando;
}

_Visual? _visualDe(EstadoAtualizacao estado) => switch (estado) {
      EstadoAtualizacao.procurando => const _Visual(
          texto: 'Procurando atualização…',
          cor: AppColors.textoFraco,
          icone: null,
          girando: true,
        ),
      EstadoAtualizacao.baixando => const _Visual(
          texto: 'Baixando atualização…',
          cor: AppColors.primary,
          icone: null,
          girando: true,
        ),
      EstadoAtualizacao.pronta => const _Visual(
          texto: 'Atualização pronta — reabra o app para aplicar',
          cor: AppColors.success,
          icone: Icons.check_circle_rounded,
        ),
      EstadoAtualizacao.falhou => const _Visual(
          texto: 'Não consegui buscar atualização — toque para tentar de novo',
          cor: AppColors.atencao,
          icone: Icons.refresh_rounded,
        ),
      // Atualizada, indisponível e desconhecido não desenham faixa: o número do
      // patch no selo já diz em que versão o app está.
      _ => null,
    };

class _Faixa extends StatelessWidget {
  const _Faixa({required this.visual, required this.aoTocar});

  final _Visual visual;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.medium),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: aoTocar,
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: visual.cor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppSpacing.radius),
              border: Border.all(color: visual.cor.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: visual.girando
                      ? CircularProgressIndicator(strokeWidth: 2, color: visual.cor)
                      : Icon(visual.icone, size: 18, color: visual.cor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    visual.texto,
                    style: TextStyle(
                      color: visual.cor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
