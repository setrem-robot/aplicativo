import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../services/telemetry_api.dart';

/// O ciclo "carregando → deu certo → deu errado", uma vez só.
///
/// As quatro abas da telemetria fazem a mesma coisa: pedem algo à API, mostram
/// um giro enquanto esperam, o conteúdo quando chega e um erro legível quando
/// não chega. Escrever isso quatro vezes garantiria que uma delas esquecesse o
/// "tentar de novo" — e a que esquecesse seria descoberta com o robô ligado,
/// numa apresentação.
///
/// O `puxar para atualizar` vem junto: a telemetria não chega sozinha ao app,
/// então a pessoa precisa de um jeito óbvio de pedir de novo.
class Carregando<T> extends StatefulWidget {
  const Carregando({
    super.key,
    required this.buscar,
    required this.construir,
    this.vazio,
  });

  /// O que pedir à API. Chamado no primeiro build e a cada atualização.
  final Future<T> Function() buscar;

  final Widget Function(BuildContext context, T dados) construir;

  /// Mostrado quando a busca deu certo mas não veio nada. Sem isto, "ainda não
  /// há telemetria" e "a consulta falhou" ficariam com a mesma cara — e são
  /// problemas com soluções opostas.
  final Widget Function(BuildContext context)? vazio;

  @override
  State<Carregando<T>> createState() => CarregandoState<T>();
}

class CarregandoState<T> extends State<Carregando<T>> {
  late Future<T> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = widget.buscar();
  }

  /// Refaz a busca. Chamado pelo "puxar para atualizar" e pelo botão de erro.
  void recarregar() {
    setState(() => _futuro = widget.buscar());
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: () async {
        recarregar();
        // O indicador some quando este Future termina; sem esperar o mesmo
        // Future da tela, ele sumiria antes de os dados chegarem.
        await _futuro.catchError((_) => throw _SilenciarNoIndicador());
      },
      child: FutureBuilder<T>(
        future: _futuro,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _Centralizado(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (snapshot.hasError) {
            return _Erro(erro: snapshot.error!, aoTentarDeNovo: recarregar);
          }
          final dados = snapshot.data as T;
          if (widget.vazio != null && _pareceVazio(dados)) {
            return _Centralizado(child: widget.vazio!(context));
          }
          return widget.construir(context, dados);
        },
      ),
    );
  }

  bool _pareceVazio(T dados) => dados is Iterable && dados.isEmpty;
}

/// O `RefreshIndicator` some quando o Future dele termina — inclusive com erro.
/// Este erro existe só para ele terminar sem o Flutter reclamar de exceção não
/// tratada; quem mostra o problema é o `FutureBuilder`, logo abaixo.
class _SilenciarNoIndicador implements Exception {}

class _Centralizado extends StatelessWidget {
  const _Centralizado({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // `ListView` e não `Center`: o "puxar para atualizar" só funciona sobre
    // algo rolável, e sem isto a tela de erro seria a única de onde não daria
    // para tentar de novo com o gesto.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.6,
          child: Center(child: child),
        ),
      ],
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
            const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.white24),
            const SizedBox(height: AppSpacing.medium),
            Text(
              mensagem,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, height: 1.4),
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
          const Icon(Icons.inbox_rounded, size: 48, color: Colors.white24),
          const SizedBox(height: AppSpacing.medium),
          Text(
            mensagem,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          if (detalhe != null) ...[
            const SizedBox(height: AppSpacing.small),
            Text(
              detalhe!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}
