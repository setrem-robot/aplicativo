import 'dart:async';

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../services/telemetryApi.dart';

/// O ciclo "carregando → deu certo → deu errado", e depois **ao vivo**.
///
/// As quatro abas da telemetria fazem a mesma coisa: pedem algo à API, mostram
/// um giro enquanto esperam, o conteúdo quando chega e um erro legível quando
/// não chega. Escrever isso quatro vezes garantiria que uma delas esquecesse o
/// "tentar de novo" — e a que esquecesse seria descoberta com o robô ligado,
/// numa apresentação.
///
/// Com [atualizarACada], a busca se repete sozinha enquanto a tela está à
/// vista: o que o robô publica aparece sem fechar e abrir o app. A repetição é
/// **silenciosa** — o conteúdo fica na tela enquanto a próxima leitura vem, e
/// troca quando ela chega. Um giro a cada cinco segundos faria o painel piscar,
/// e uma falha momentânea de rede apagaria dados bons para mostrar um erro que
/// some sozinho na rodada seguinte.
///
/// O `puxar para atualizar` continua, para quem não quer esperar a rodada.
class Carregando<T> extends StatefulWidget {
  const Carregando({
    super.key,
    required this.buscar,
    required this.construir,
    this.vazio,
    this.atualizarACada,
  });

  /// O que pedir à API. Chamado no primeiro build e a cada atualização.
  final Future<T> Function() buscar;

  final Widget Function(BuildContext context, T dados) construir;

  /// Mostrado quando a busca deu certo mas não veio nada. Sem isto, "ainda não
  /// há telemetria" e "a consulta falhou" ficariam com a mesma cara — e são
  /// problemas com soluções opostas.
  final Widget Function(BuildContext context)? vazio;

  /// De quanto em quanto tempo buscar de novo, sozinho. Nulo = só uma vez.
  ///
  /// Pausa com o app em segundo plano ou com outra tela por cima: ninguém está
  /// olhando, e cada busca é tráfego de celular e uma consulta no banco.
  final Duration? atualizarACada;

  @override
  State<Carregando<T>> createState() => CarregandoState<T>();
}

class CarregandoState<T> extends State<Carregando<T>> with WidgetsBindingObserver {
  /// A última leitura boa. Fica na tela até chegar outra.
  T? _dados;
  bool _temDados = false;

  /// A falha da última busca, se a última falhou.
  Object? _erro;

  /// A busca em andamento. Uma rodada do relógio que cai enquanto a anterior
  /// ainda espera a API reaproveita a mesma, em vez de empilhar pedidos numa
  /// rede lenta.
  Future<void>? _emCurso;

  Timer? _relogio;
  bool _emPrimeiroPlano = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _buscar();
    _agendar();
  }

  @override
  void didUpdateWidget(Carregando<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.atualizarACada != widget.atualizarACada) _agendar();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ativo = state == AppLifecycleState.resumed;
    if (ativo == _emPrimeiroPlano) return;
    _emPrimeiroPlano = ativo;
    if (ativo) {
      // Voltou ao app: o que está na tela pode ter minutos. Busca já, sem
      // esperar a próxima rodada.
      if (widget.atualizarACada != null) _buscar();
      _agendar();
    } else {
      _relogio?.cancel();
    }
  }

  @override
  void dispose() {
    _relogio?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Refaz a busca. Chamado pelo "puxar para atualizar" e pelo botão de erro.
  void recarregar() {
    // Do erro sem dados, "tentar de novo" volta ao giro; com dados na tela,
    // eles ficam até a resposta chegar.
    if (!_temDados) setState(() => _erro = null);
    _buscar();
  }

  void _agendar() {
    _relogio?.cancel();
    final periodo = widget.atualizarACada;
    if (periodo == null || !_emPrimeiroPlano) return;
    _relogio = Timer.periodic(periodo, (_) {
      // Outra tela por cima (ajustes, por exemplo): espera voltar.
      if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? true)) return;
      _buscar();
    });
  }

  Future<void> _buscar() {
    return _emCurso ??= _executar().whenComplete(() => _emCurso = null);
  }

  Future<void> _executar() async {
    try {
      final dados = await widget.buscar();
      if (!mounted) return;
      setState(() {
        _dados = dados;
        _temDados = true;
        _erro = null;
      });
    } catch (erro) {
      if (!mounted) return;
      setState(() => _erro = erro);
    }
  }

  /// Uma falha que não passa sozinha (token errado, por exemplo) precisa
  /// aparecer mesmo com dados antigos na tela; as outras, só sem eles.
  bool get _erroBloqueia {
    final erro = _erro;
    if (erro == null) return false;
    if (!_temDados) return true;
    return erro is ErroApi && !erro.podeTentarDeNovo;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      // O indicador some quando este Future termina; é a mesma busca da tela,
      // então ele some quando os dados chegam. `_executar` não lança: quem
      // mostra o problema é o próprio build, logo abaixo.
      onRefresh: _buscar,
      child: _corpo(context),
    );
  }

  Widget _corpo(BuildContext context) {
    if (_erroBloqueia) {
      return _Erro(erro: _erro!, aoTentarDeNovo: recarregar);
    }
    if (!_temDados) {
      return const _Centralizado(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    final dados = _dados as T;
    if (widget.vazio != null && _pareceVazio(dados)) {
      return _Centralizado(child: widget.vazio!(context));
    }
    return widget.construir(context, dados);
  }

  bool _pareceVazio(T dados) => dados is Iterable && dados.isEmpty;
}

class _Centralizado extends StatelessWidget {
  const _Centralizado({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // `ListView` e não `Center`: o "puxar para atualizar" só funciona sobre
    // algo rolável, e sem isto a tela de erro seria a única de onde não daria
    // para tentar de novo com o gesto.
    //
    // A altura vem da caixa em que o widget foi posto, e não da tela: o
    // histórico agora empilha um gráfico por grandeza, cada um num cartão de
    // 300 px, e um "sem dados" centrado em 60% da tela ficaria fora do cartão.
    return LayoutBuilder(
      builder: (context, caixa) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: caixa.maxHeight.isFinite
                ? caixa.maxHeight
                : MediaQuery.sizeOf(context).height * 0.6,
            child: Center(child: child),
          ),
        ],
      ),
    );
  }
}

class _Erro extends StatelessWidget {
  const _Erro({required this.erro, required this.aoTentarDeNovo});

  final Object erro;
  final VoidCallback aoTentarDeNovo;

  @override
  Widget build(BuildContext context) {
    final api = erro is ErroApi ? erro as ErroApi : null;
    final mensagem = api?.mensagem ?? 'algo deu errado ao falar com a API';

    return _Centralizado(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.parado),
            const SizedBox(height: AppSpacing.medium),
            Text(
              mensagem,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textoFraco, height: 1.4),
            ),
            const SizedBox(height: AppSpacing.large),
            // Um erro de token não melhora tentando de novo: o botão certo
            // leva aos ajustes, e é a tela que decide isso.
            if (api?.podeTentarDeNovo ?? true)
              FilledButton.icon(
                onPressed: aoTentarDeNovo,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tentar de novo'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onBrand,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Texto para quando a consulta deu certo e não havia nada.
class SemDados extends StatelessWidget {
  const SemDados({super.key, required this.mensagem, this.detalhe});

  final String mensagem;
  final String? detalhe;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.large),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_rounded, size: 48, color: AppColors.parado),
          const SizedBox(height: AppSpacing.medium),
          Text(
            mensagem,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.texto, fontSize: 16),
          ),
          if (detalhe != null) ...[
            const SizedBox(height: AppSpacing.small),
            Text(
              detalhe!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textoApagado, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}
