import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme.dart';
import '../models/telemetria.dart';

/// O payload de um evento, inteiro e legível.
///
/// Antes era um `SelectableText` monoespaçado num bottom sheet: certo, mas
/// um payload de `sistema` tem trinta linhas e cinco blocos aninhados, e achar
/// `throttled.subtensao_agora` ali era rolar e ler linha por linha. Aqui o
/// JSON vira uma **árvore**: cada bloco recolhe com um toque, cada família de
/// valor tem uma cor, e segurar numa linha copia `caminho = valor` — o que se
/// cola numa mensagem quando se pergunta "por que isto veio assim?".
///
/// A visão de texto continua existindo, para quem quer o JSON como ele é.
void mostrarEvento(BuildContext context, EventoTelemetria evento) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      // Abre em 72% da tela: alto o bastante para um payload comum caber sem
      // rolar, e ainda mostrando a lista atrás, para lembrar de onde se veio.
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, rolagem) => _Folha(evento: evento, rolagem: rolagem),
    ),
  );
}

class _Folha extends StatefulWidget {
  const _Folha({required this.evento, required this.rolagem});

  final EventoTelemetria evento;
  final ScrollController rolagem;

  @override
  State<_Folha> createState() => _FolhaState();
}

class _FolhaState extends State<_Folha> {
  bool _arvore = true;

  @override
  Widget build(BuildContext context) {
    final evento = widget.evento;
    final cor = AppColors.fonte(evento.tipo);

    // Um `ScaffoldMessenger` próprio: o "copiado" precisa aparecer **dentro**
    // da folha. Sem ele, o aviso iria para o Scaffold da tela de trás — e a
    // folha, que é modal, o taparia por inteiro.
    return ScaffoldMessenger(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: _Corpo(evento: evento, cor: cor, arvore: _arvore, rolagem: widget.rolagem,
            aoTrocar: (arvore) => setState(() => _arvore = arvore)),
      ),
    );
  }
}

class _Corpo extends StatelessWidget {
  const _Corpo({
    required this.evento,
    required this.cor,
    required this.arvore,
    required this.rolagem,
    required this.aoTrocar,
  });

  final EventoTelemetria evento;
  final Color cor;
  final bool arvore;
  final ScrollController rolagem;
  final ValueChanged<bool> aoTrocar;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLarge)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          _Cabecalho(evento: evento, cor: cor),
          _Ferramentas(
            arvore: arvore,
            aoTrocar: aoTrocar,
            aoCopiar: () => _copiar(context, jsonBonito(evento.dados), 'JSON copiado'),
          ),
          Expanded(
            child: arvore
                ? _Arvore(dados: evento.dados, rolagem: rolagem)
                : _Texto(dados: evento.dados, rolagem: rolagem),
          ),
        ],
      ),
    );
  }
}

/// Tipo, tópico e instante — o que identifica a mensagem antes do conteúdo.
class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.evento, required this.cor});

  final EventoTelemetria evento;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.large, 14, AppSpacing.large, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 44,
            margin: const EdgeInsets.only(top: 3),
            decoration: BoxDecoration(
              color: cor,
              borderRadius: BorderRadius.circular(2),
              boxShadow: [BoxShadow(color: cor.withValues(alpha: 0.5), blurRadius: 8)],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      evento.tipo,
                      style: TextStyle(
                        color: cor,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${evento.dados.length} ${evento.dados.length == 1 ? 'campo' : 'campos'}',
                      style: AppText.meta,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                if (evento.topico.isNotEmpty)
                  Text(
                    evento.topico,
                    style: AppText.mono.copyWith(fontSize: 11.5, color: AppColors.textoFraco, height: 1.3),
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 3),
                Text(instanteCompleto(evento.instante, comMilissegundos: true), style: AppText.meta),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A troca árvore/texto e o botão de copiar.
class _Ferramentas extends StatelessWidget {
  const _Ferramentas({
    required this.arvore,
    required this.aoTrocar,
    required this.aoCopiar,
  });

  final bool arvore;
  final ValueChanged<bool> aoTrocar;
  final VoidCallback aoCopiar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.large, 14, AppSpacing.medium, 6),
      child: Row(
        children: [
          _Alternador(
            opcoes: const ['árvore', 'texto'],
            escolhida: arvore ? 0 : 1,
            aoEscolher: (i) => aoTrocar(i == 0),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: aoCopiar,
            // save_outlined já está na fonte (tela da rota): reaproveitar
            // mantém o visor entregável por patch OTA sem glifo novo.
            icon: const Icon(Icons.save_outlined, size: 16),
            label: const Text('copiar JSON'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dois botões colados num trilho, com o escolhido em relevo. Menor e mais
/// quieto que o `SegmentedButton`, que aqui pesaria mais que o conteúdo.
class _Alternador extends StatelessWidget {
  const _Alternador({
    required this.opcoes,
    required this.escolhida,
    required this.aoEscolher,
  });

  final List<String> opcoes;
  final int escolhida;
  final ValueChanged<int> aoEscolher;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < opcoes.length; i++)
            GestureDetector(
              onTap: () => aoEscolher(i),
              child: AnimatedContainer(
                duration: AppDurations.press,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: i == escolhida ? AppColors.surfaceAlta : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: i == escolhida
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.transparent,
                  ),
                ),
                child: Text(
                  opcoes[i],
                  style: TextStyle(
                    color: i == escolhida ? AppColors.texto : AppColors.textoApagado,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Árvore
// ---------------------------------------------------------------------------

class _Arvore extends StatefulWidget {
  const _Arvore({required this.dados, required this.rolagem});

  final Map<String, dynamic> dados;
  final ScrollController rolagem;

  @override
  State<_Arvore> createState() => _ArvoreState();
}

class _ArvoreState extends State<_Arvore> {
  /// Os caminhos recolhidos (`cpu`, `rede.eth0`). Guardar os recolhidos, e não
  /// os abertos, é o que faz a árvore nascer toda aberta — o padrão certo para
  /// um payload que se abre para **ler**, não para navegar.
  final _recolhidos = <String>{};

  @override
  Widget build(BuildContext context) {
    final linhas = <Widget>[];
    _achatar(widget.dados, '', 0, linhas);

    if (linhas.isEmpty) {
      return const Center(child: Text('payload vazio', style: AppText.meta));
    }

    return ListView(
      controller: widget.rolagem,
      padding: const EdgeInsets.fromLTRB(AppSpacing.medium, 4, AppSpacing.medium, AppSpacing.large),
      children: linhas,
    );
  }

  /// Percorre o JSON em profundidade e emite uma linha por nó, pulando o que
  /// estiver dentro de um bloco recolhido.
  void _achatar(Object? valor, String caminho, int nivel, List<Widget> saida) {
    if (valor is Map) {
      final entradas = valor.entries.toList();
      for (final entrada in entradas) {
        final chave = entrada.key.toString();
        final sub = caminho.isEmpty ? chave : '$caminho.$chave';
        _emitir(chave, entrada.value, sub, nivel, saida);
      }
    } else if (valor is List) {
      for (var i = 0; i < valor.length; i++) {
        final sub = '$caminho[$i]';
        _emitir('[$i]', valor[i], sub, nivel, saida);
      }
    }
  }

  void _emitir(String chave, Object? valor, String caminho, int nivel, List<Widget> saida) {
    final bloco = valor is Map || valor is List;
    final recolhido = _recolhidos.contains(caminho);
    saida.add(_Linha(
      chave: chave,
      valor: valor,
      caminho: caminho,
      nivel: nivel,
      bloco: bloco,
      recolhido: recolhido,
      aoTocar: bloco
          ? () => setState(() {
                if (!_recolhidos.remove(caminho)) _recolhidos.add(caminho);
              })
          : null,
    ));
    if (bloco && !recolhido) _achatar(valor, caminho, nivel + 1, saida);
  }
}

/// Uma linha da árvore: recuo, chave e valor (ou o resumo de um bloco).
class _Linha extends StatelessWidget {
  const _Linha({
    required this.chave,
    required this.valor,
    required this.caminho,
    required this.nivel,
    required this.bloco,
    required this.recolhido,
    required this.aoTocar,
  });

  final String chave;
  final Object? valor;
  final String caminho;
  final int nivel;
  final bool bloco;
  final bool recolhido;
  final VoidCallback? aoTocar;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: aoTocar,
      onLongPress: () => _copiar(
        context,
        '$caminho = ${bloco ? jsonBonito(valor) : jsonEncode(valor)}',
        '$caminho copiado',
      ),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.only(left: 14.0 * nivel, top: 3, bottom: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // A guia do bloco: a seta que gira ao recolher. Nas folhas, um
            // espaço do mesmo tamanho, para as chaves alinharem numa coluna.
            SizedBox(
              width: 18,
              height: 19,
              child: bloco
                  ? AnimatedRotation(
                      turns: recolhido ? 0 : 0.25,
                      duration: AppDurations.press,
                      child: const Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: AppColors.textoApagado,
                      ),
                    )
                  : null,
            ),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: chave,
                      style: TextStyle(
                        color: bloco ? AppColors.textoFraco : AppJson.chave,
                        fontWeight: bloco ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    if (!bloco) ...[
                      const TextSpan(text: ': ', style: TextStyle(color: AppJson.pontuacao)),
                      _tokenDeValor(valor),
                    ] else
                      TextSpan(
                        text: recolhido ? '  ${_resumoBloco(valor)}' : '',
                        style: const TextStyle(color: AppJson.pontuacao),
                      ),
                  ],
                ),
                style: AppText.mono,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `{5 campos}` ou `[3 itens]` — o que um bloco recolhido mostra no lugar do
/// conteúdo, para a pessoa saber o que está escondendo.
String _resumoBloco(Object? valor) {
  if (valor is Map) return '{${valor.length} ${valor.length == 1 ? 'campo' : 'campos'}}';
  if (valor is List) return '[${valor.length} ${valor.length == 1 ? 'item' : 'itens'}]';
  return '';
}

/// O valor de uma folha, colorido pela família: texto, número, booleano, nulo.
TextSpan _tokenDeValor(Object? valor) {
  if (valor == null) return const TextSpan(text: 'null', style: TextStyle(color: AppJson.nulo));
  if (valor is bool) return TextSpan(text: '$valor', style: const TextStyle(color: AppJson.booleano));
  if (valor is num) return TextSpan(text: '$valor', style: const TextStyle(color: AppJson.numero));
  return TextSpan(text: jsonEncode(valor), style: const TextStyle(color: AppJson.texto));
}

// ---------------------------------------------------------------------------
// Texto
// ---------------------------------------------------------------------------

/// O JSON como texto, com as mesmas cores da árvore.
///
/// Selecionável: aqui é onde se copia um pedaço, e não o todo. As cores vêm de
/// um tokenizador de uma expressão só sobre o JSON já indentado — cabe numa
/// função porque o texto é sempre o que o `JsonEncoder` produziu, nunca o que
/// alguém digitou.
class _Texto extends StatelessWidget {
  const _Texto({required this.dados, required this.rolagem});

  final Map<String, dynamic> dados;
  final ScrollController rolagem;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: rolagem,
      padding: const EdgeInsets.fromLTRB(AppSpacing.large, 4, AppSpacing.large, AppSpacing.large),
      // Largura total: sem ela o texto encolhe ao tamanho da linha mais longa
      // e o `SingleChildScrollView` o centraliza, com o JSON boiando no meio.
      child: SizedBox(
        width: double.infinity,
        child: SelectableText.rich(
          TextSpan(children: colorirJson(jsonBonito(dados))),
          style: AppText.mono,
        ),
      ),
    );
  }
}

final _tokens = RegExp(
  r'("(?:\\.|[^"\\])*")(\s*:)?' // texto, e ":" quando é chave
  r'|(-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)' // número
  r'|\b(true|false|null)\b' // literal
  r'|([{}\[\],])', // pontuação
);

/// Divide o JSON indentado em trechos coloridos. Visível para o teste.
List<TextSpan> colorirJson(String texto) {
  final trechos = <TextSpan>[];
  var cursor = 0;
  for (final m in _tokens.allMatches(texto)) {
    if (m.start > cursor) trechos.add(TextSpan(text: texto.substring(cursor, m.start)));
    if (m[1] != null) {
      final ehChave = m[2] != null;
      trechos.add(TextSpan(
        text: m[1],
        style: TextStyle(
          color: ehChave ? AppJson.chave : AppJson.texto,
          fontWeight: ehChave ? FontWeight.w500 : FontWeight.w400,
        ),
      ));
      if (ehChave) trechos.add(TextSpan(text: m[2], style: const TextStyle(color: AppJson.pontuacao)));
    } else if (m[3] != null) {
      trechos.add(TextSpan(text: m[3], style: const TextStyle(color: AppJson.numero)));
    } else if (m[4] != null) {
      trechos.add(TextSpan(
        text: m[4],
        style: TextStyle(color: m[4] == 'null' ? AppJson.nulo : AppJson.booleano),
      ));
    } else {
      trechos.add(TextSpan(text: m[5], style: const TextStyle(color: AppJson.pontuacao)));
    }
    cursor = m.end;
  }
  if (cursor < texto.length) trechos.add(TextSpan(text: texto.substring(cursor)));
  return trechos;
}

// ---------------------------------------------------------------------------
// Miúdos compartilhados com a lista
// ---------------------------------------------------------------------------

String jsonBonito(Object? dados) => const JsonEncoder.withIndent('  ').convert(dados);

/// "15/09 14:02:11" — ou com os milissegundos, no visor, onde dois eventos
/// do mesmo segundo precisam ser distinguíveis.
String instanteCompleto(DateTime momento, {bool comMilissegundos = false}) {
  String dois(int n) => n.toString().padLeft(2, '0');
  final base = '${dois(momento.day)}/${dois(momento.month)} '
      '${dois(momento.hour)}:${dois(momento.minute)}:${dois(momento.second)}';
  if (!comMilissegundos) return base;
  return '$base.${momento.millisecond.toString().padLeft(3, '0')}';
}

void _copiar(BuildContext context, String texto, String aviso) {
  Clipboard.setData(ClipboardData(text: texto));
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(aviso),
      duration: const Duration(seconds: 1),
      behavior: SnackBarBehavior.floating,
    ));
}
