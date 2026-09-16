import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/filtro.dart';
import '../services/filtroStore.dart';

/// A barra de filtros da tela de dados: as fontes, e os filtros com nome.
///
/// Os chips **somam** em vez de escolher: tocar GPS com Sistema aceso deixa os
/// dois acesos. É o que permite dizer "só o Pi e o GPS" — antes cada chip
/// desligava o anterior, e a única forma de ver duas fontes era ver todas.
/// Tocar e segurar num chip deixa **só ele**, o atalho de quem está atrás de
/// uma coisa.
///
/// A segunda fileira são os filtros guardados. Aparece só quando há algo nela
/// para mostrar — um preset salvo, ou um filtro que vale a pena salvar —
/// porque uma fileira vazia com um botão "salvar" seria um convite permanente
/// a uma ação que quase nunca se quer.
class BarraFontes extends StatelessWidget {
  const BarraFontes({super.key, required this.filtro});

  final FiltroStore filtro;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: filtro,
      builder: (context, _) {
        final ativo = filtro.presetAtivo;
        final podeSalvar = !filtro.todasAsFontes &&
            ativo == null &&
            filtro.presets.length < FiltroStore.maximoPresets;
        final mostrarPresets = filtro.presets.isNotEmpty || podeSalvar;

        return Padding(
          padding: const EdgeInsets.fromLTRB(0, AppSpacing.medium, 0, AppSpacing.small),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Fileira(
                children: [
                  ChipFiltro(
                    rotulo: 'todas',
                    selecionado: filtro.todasAsFontes,
                    aoTocar: filtro.todasFontes,
                  ),
                  const _Separador(),
                  for (final fonte in Fonte.values)
                    ChipFiltro(
                      rotulo: fonte.rotulo,
                      cor: AppColors.fonte(fonte.tipo),
                      selecionado: filtro.fonteMarcada(fonte),
                      aoTocar: () => filtro.alternarFonte(fonte),
                      aoSegurar: () => filtro.somenteFonte(fonte),
                    ),
                ],
              ),
              // `AnimatedSize` para a fileira dos presets entrar e sair
              // deslizando em vez de fazer a lista pular 40 px de uma vez.
              AnimatedSize(
                duration: AppDurations.swap,
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: mostrarPresets
                    ? Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.small),
                        child: _Fileira(
                          children: [
                            for (final preset in filtro.presets)
                              ChipFiltro(
                                rotulo: preset.nome,
                                icone: Icons.flag_rounded,
                                selecionado: identical(preset, ativo),
                                aoTocar: () => filtro.aplicarPreset(preset),
                                aoSegurar: () => _confirmarRemocao(context, preset),
                              ),
                            if (podeSalvar)
                              ChipFiltro(
                                rotulo: 'salvar este filtro',
                                icone: Icons.save_outlined,
                                tracejado: true,
                                aoTocar: () => _pedirNome(context),
                              ),
                          ],
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pedirNome(BuildContext context) async {
    final nome = await showDialog<String>(
      context: context,
      builder: (context) => _DialogoNome(sugestao: _sugestao()),
    );
    if (nome == null) return;
    // Nome em branco vale como a sugestão: quem só quer o filtro guardado não
    // deveria ter de inventar um nome para ele.
    final escolhido = nome.trim();
    filtro.salvarPreset(escolhido.isEmpty ? _sugestao() : escolhido);
  }

  /// "Pi + GPS": as fontes marcadas, curtas. Serve de sugestão de nome.
  String _sugestao() {
    const curtos = {
      Fonte.sistema: 'Pi',
      Fonte.bateria: 'Bateria',
      Fonte.gps: 'GPS',
      Fonte.motores: 'Motores',
      Fonte.wifi: 'Rede',
    };
    return [for (final f in Fonte.values) if (filtro.fonteMarcada(f)) curtos[f]!].join(' + ');
  }

  Future<void> _confirmarRemocao(BuildContext context, PresetFiltro preset) async {
    final apagar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceAlta,
        title: Text('Apagar "${preset.nome}"?'),
        content: const Text(
          'O filtro some da barra. As fontes marcadas agora continuam como estão.',
          style: TextStyle(color: AppColors.textoFraco),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Manter'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (apagar == true) filtro.removerPreset(preset);
  }
}

/// A barra do histórico: quais grandezas plotar, e em que janela.
///
/// Os chips vêm agrupados pela fonte, com o ponto colorido dela na frente do
/// grupo: é a mesma cor que a linha do gráfico vai ter, então a pessoa já sabe
/// que a curva rosa é a temperatura antes de o gráfico carregar.
class BarraGrandezas extends StatelessWidget {
  const BarraGrandezas({
    super.key,
    required this.filtro,
    required this.janelas,
  });

  final FiltroStore filtro;

  /// Os nomes das janelas ("6 h", "24 h", ...), na ordem dos botões.
  final List<String> janelas;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: filtro,
      builder: (context, _) {
        final grandezas = Grandeza.todas;
        return Padding(
          padding: const EdgeInsets.fromLTRB(0, AppSpacing.medium, 0, AppSpacing.small),
          child: Column(
            children: [
              _Fileira(
                children: [
                  for (var i = 0; i < grandezas.length; i++) ...[
                    if (i == 0 || grandezas[i].fonte != grandezas[i - 1].fonte)
                      _RotuloGrupo(
                        fonte: grandezas[i].fonte,
                        primeiro: i == 0,
                      ),
                    ChipFiltro(
                      rotulo: grandezas[i].rotulo,
                      cor: AppColors.fonte(grandezas[i].fonte.tipo),
                      selecionado: filtro.grandezaMarcada(grandezas[i]),
                      aoTocar: () => filtro.alternarGrandeza(grandezas[i]),
                      semPonto: true,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.small + 2),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.medium),
                child: SegmentedButton<String>(
                  segments: [
                    for (final nome in janelas) ButtonSegment(value: nome, label: Text(nome)),
                  ],
                  selected: {filtro.janela},
                  onSelectionChanged: (escolha) => filtro.definirJanela(escolha.first),
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.textoFraco,
                    selectedBackgroundColor: AppColors.primary,
                    selectedForegroundColor: AppColors.onBrand,
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
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

/// O diálogo que pede o nome do preset. Dono do `TextEditingController`, para
/// ele ser descartado quando o diálogo some — e não antes, no meio da animação
/// de fechar, que é o que acontece quando quem abre o diálogo o cria e destrói.
class _DialogoNome extends StatefulWidget {
  const _DialogoNome({required this.sugestao});

  final String sugestao;

  @override
  State<_DialogoNome> createState() => _DialogoNomeState();
}

class _DialogoNomeState extends State<_DialogoNome> {
  final _controle = TextEditingController();

  @override
  void dispose() {
    _controle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceAlta,
      title: const Text('Nome do filtro'),
      content: TextField(
        controller: _controle,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        maxLength: 24,
        decoration: InputDecoration(
          hintText: widget.sugestao,
          hintStyle: const TextStyle(color: AppColors.textoApagado),
        ),
        onSubmitted: (texto) => Navigator.of(context).pop(texto),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controle.text),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onBrand,
          ),
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

/// O nome do grupo antes do primeiro chip dele, com o ponto na cor da fonte.
class _RotuloGrupo extends StatelessWidget {
  const _RotuloGrupo({required this.fonte, required this.primeiro});

  final Fonte fonte;
  final bool primeiro;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: primeiro ? 0 : AppSpacing.small, right: AppSpacing.small),
      child: Row(
        children: [
          _Ponto(cor: AppColors.fonte(fonte.tipo), aceso: true),
          const SizedBox(width: 5),
          Text(
            fonte.rotulo,
            style: AppText.meta.copyWith(fontSize: 11, color: AppColors.textoFraco),
          ),
        ],
      ),
    );
  }
}

/// Uma fileira rolável de chips, com a margem da tela nas pontas.
class _Fileira extends StatelessWidget {
  const _Fileira({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.medium),
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Separador extends StatelessWidget {
  const _Separador();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: Colors.white.withValues(alpha: 0.08),
    );
  }
}

/// Um chip do filtro.
///
/// Feito à mão em vez do `FilterChip` do Material por causa da cor: aqui o
/// chip aceso pega a cor **da fonte** (rosa para o Pi, azul para o GPS), e o
/// `FilterChip` só sabe pintar de uma cor para todos. Aceso, ele ganha fundo
/// e borda na cor; apagado, o ponto fica só com a borda e o texto recua. É a
/// mesma linguagem do painel: o que está ativo tem cor, o que não está, não.
class ChipFiltro extends StatelessWidget {
  const ChipFiltro({
    super.key,
    required this.rotulo,
    required this.aoTocar,
    this.aoSegurar,
    this.cor,
    this.icone,
    this.selecionado = false,
    this.tracejado = false,
    this.semPonto = false,
  });

  final String rotulo;
  final VoidCallback aoTocar;
  final VoidCallback? aoSegurar;

  /// A cor da fonte. Sem ela, o chip é neutro e acende na cor da marca — é o
  /// caso de "todas" e dos presets, que não são uma fonte.
  final Color? cor;
  final IconData? icone;
  final bool selecionado;

  /// Borda mais visível, para o chip que é uma ação ("salvar") e não um estado.
  final bool tracejado;

  /// Sem o ponto colorido — quando o grupo já mostrou a cor.
  final bool semPonto;

  @override
  Widget build(BuildContext context) {
    final tom = cor ?? AppColors.primary;
    final texto = selecionado ? AppColors.texto : AppColors.textoFraco;

    return Semantics(
      button: true,
      selected: selecionado,
      label: rotulo,
      child: GestureDetector(
        onTap: aoTocar,
        onLongPress: aoSegurar,
        child: AnimatedContainer(
          duration: AppDurations.press,
          curve: Curves.easeOut,
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selecionado ? tom.withValues(alpha: 0.16) : AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selecionado
                  ? tom.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: tracejado ? 0.18 : 0.07),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icone != null) ...[
                Icon(icone, size: 13, color: selecionado ? tom : AppColors.textoApagado),
                const SizedBox(width: 6),
              ] else if (cor != null && !semPonto) ...[
                _Ponto(cor: tom, aceso: selecionado),
                const SizedBox(width: 7),
              ],
              Text(
                rotulo,
                style: TextStyle(
                  color: texto,
                  fontSize: 12.5,
                  fontWeight: selecionado ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// O ponto de cor da fonte. Apagado, ele fica só com a borda: a cor continua
/// lá para a pessoa saber qual fonte é, mas sem disputar com as acesas.
class _Ponto extends StatelessWidget {
  const _Ponto({required this.cor, required this.aceso});

  final Color cor;
  final bool aceso;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppDurations.press,
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: aceso ? cor : Colors.transparent,
        border: Border.all(color: cor.withValues(alpha: aceso ? 1 : 0.55), width: 1.5),
        boxShadow: aceso
            ? [BoxShadow(color: cor.withValues(alpha: 0.5), blurRadius: 6)]
            : null,
      ),
    );
  }
}
