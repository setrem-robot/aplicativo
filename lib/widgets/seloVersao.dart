import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme.dart';
import '../app/versao.dart';
import '../services/atualizacao.dart';

/// A versão do build, à vista mas fora do caminho.
///
/// Fica sobre o app inteiro (montado uma vez no `MaterialApp.builder`), então
/// nenhuma tela precisa saber que ele existe — some no dia em que o build
/// deixar de ser `dev` mexendo num arquivo só.
///
/// **É um carimbo que também responde uma pergunta.** As duas primeiras
/// versões disto eram texto branco solto no canto: presente, mas feio, e sem
/// dizer nada além do número. Esta é uma pílula miúda, no tom do fundo, com
/// um ponto colorido na frente — e o ponto **é** o estado da atualização: verde
/// quando o app está no patch mais novo, âmbar enquanto baixa, vermelho se a
/// busca falhou, apagado num build sem Shorebird. Tocar abre a ficha do build
/// inteira, com o botão de copiar para colar num relato de problema.
///
/// A pílula é a única parte que captura toque; o resto do canto continua
/// passando o clique para o que estiver embaixo.
class SeloVersao extends StatelessWidget {
  /// A chave do `Navigator` do app, que o `main.dart` entrega ao `MaterialApp`.
  ///
  /// O selo vive **acima** do Navigator (é montado no `builder`, ao lado dele,
  /// não dentro), então `Navigator.of(context)` daqui não acha navegador
  /// nenhum. A ficha abre pelo contexto desta chave, que está dentro.
  static final navegador = GlobalKey<NavigatorState>();

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
          // Rodapé, e não topo: em cima ele disputa com a barra de título e com
          // os botões de ação de cada tela; embaixo a faixa é sempre folgada.
          bottom: MediaQuery.of(context).padding.bottom + 6,
          right: 10,
          // `Material` porque o selo está fora de qualquer Scaffold: sem ele o
          // Flutter sublinha o texto de amarelo em debug, avisando disso.
          child: Material(
            type: MaterialType.transparency,
            child: AnimatedBuilder(
              animation: AtualizacaoService.instance,
              builder: (context, _) => _Pilula(servico: AtualizacaoService.instance),
            ),
          ),
        ),
      ],
    );
  }
}

class _Pilula extends StatelessWidget {
  const _Pilula({required this.servico});

  final AtualizacaoService servico;

  @override
  Widget build(BuildContext context) {
    final versao = servico.versao.isNotEmpty ? servico.versao : kVersaoCurta;
    final cor = _corDoEstado(servico.estado);

    return Semantics(
      button: true,
      label: 'versão $versao',
      child: GestureDetector(
        onTap: () {
          final dentro = SeloVersao.navegador.currentContext;
          if (dentro != null) _mostrarFicha(dentro, servico);
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: AppDurations.swap,
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: cor,
                  shape: BoxShape.circle,
                  boxShadow: cor == AppColors.parado
                      ? null
                      : [BoxShadow(color: cor.withValues(alpha: 0.6), blurRadius: 5)],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _textoCurto(versao, servico.patch),
                style: AppText.mono.copyWith(
                  fontSize: 10,
                  height: 1,
                  color: AppColors.textoFraco,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `1.2.3 (10)` ou `1.2.3 (10) +p3`: a versão, o build entre parênteses e o
/// patch quando há um. O "+" é o mesmo do `pubspec`, para quem lê o número
/// saber de onde ele veio.
String _textoCurto(String versao, int? patch) {
  final partes = versao.split('+');
  final base = partes.length == 2 ? '${partes[0]} (${partes[1]})' : versao;
  return patch == null ? base : '$base +p$patch';
}

Color _corDoEstado(EstadoAtualizacao estado) => switch (estado) {
      EstadoAtualizacao.atualizada => AppColors.success,
      EstadoAtualizacao.pronta => AppColors.primary,
      EstadoAtualizacao.procurando || EstadoAtualizacao.baixando => AppColors.atencao,
      EstadoAtualizacao.falhou => AppColors.danger,
      EstadoAtualizacao.indisponivel || EstadoAtualizacao.desconhecido => AppColors.parado,
    };

String _textoDoEstado(EstadoAtualizacao estado) => switch (estado) {
      EstadoAtualizacao.atualizada => 'no patch mais novo',
      EstadoAtualizacao.pronta => 'patch baixado — reabra o app para aplicar',
      EstadoAtualizacao.procurando => 'procurando atualização…',
      EstadoAtualizacao.baixando => 'baixando atualização…',
      EstadoAtualizacao.falhou => 'não conseguiu buscar atualização',
      EstadoAtualizacao.indisponivel => 'build sem Shorebird (debug ou flutter run)',
      EstadoAtualizacao.desconhecido => 'ainda não verificou',
    };

/// A ficha do build: tudo que se pergunta quando alguém diz "não funciona".
void _mostrarFicha(BuildContext context, AtualizacaoService servico) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    builder: (context) => AnimatedBuilder(
      animation: servico,
      builder: (context, _) {
        final versao = servico.versao.isNotEmpty ? servico.versao : kVersaoCurta;
        final partes = versao.split('+');
        final linhas = <(String, String)>[
          ('versão', partes.first),
          ('build', partes.length == 2 ? partes[1] : '—'),
          ('patch', servico.patch?.toString() ?? 'nenhum (release puro)'),
          ('canal', kAppCanal),
          ('atualização', _textoDoEstado(servico.estado)),
        ];
        final ficha = [for (final (rotulo, valor) in linhas) '$rotulo: $valor'].join('\n');

        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.large,
            0,
            AppSpacing.large,
            AppSpacing.large + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Este build', style: AppText.sobrancelha),
              const SizedBox(height: AppSpacing.medium),
              for (final (rotulo, valor) in linhas)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 96,
                        child: Text(rotulo, style: AppText.meta.copyWith(fontSize: 13)),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            if (rotulo == 'atualização') ...[
                              Container(
                                width: 7,
                                height: 7,
                                margin: const EdgeInsets.only(right: 7),
                                decoration: BoxDecoration(
                                  color: _corDoEstado(servico.estado),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                            Expanded(
                              child: Text(
                                valor,
                                style: rotulo == 'atualização'
                                    ? const TextStyle(color: AppColors.texto, fontSize: 13.5)
                                    : AppText.mono.copyWith(fontSize: 13, height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.medium),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: ficha));
                      // O aviso vai para a tela de trás, depois de a folha
                      // fechar — por isso o messenger é pego antes do `pop`.
                      final mensageiro = ScaffoldMessenger.of(context);
                      Navigator.of(context).pop();
                      mensageiro.showSnackBar(const SnackBar(
                        content: Text('Ficha do build copiada'),
                        duration: Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ));
                    },
                    icon: const Icon(Icons.save_outlined, size: 16),
                    label: const Text('Copiar ficha'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                  ),
                  const Spacer(),
                  if (servico.estado != EstadoAtualizacao.indisponivel)
                    TextButton.icon(
                      onPressed: servico.verificar,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Procurar atualização'),
                      style: TextButton.styleFrom(foregroundColor: AppColors.textoFraco),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    ),
  );
}
