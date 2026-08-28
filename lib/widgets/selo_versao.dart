import 'package:flutter/material.dart';

import '../app/versao.dart';

/// A versão do build, à vista mas fora do caminho.
///
/// Fica sobre o app inteiro (montado uma vez no `MaterialApp.builder`), então
/// nenhuma tela precisa saber que ele existe — some no dia em que o build
/// deixar de ser `dev` mexendo num arquivo só.
///
/// **É um carimbo, não um aviso.** A primeira versão disto era uma cápsula com
/// fundo, borda e a cor da marca: três recursos que a interface usa para dizer
/// "olhe aqui", gastos numa informação que ninguém precisa ler duas vezes. Ela
/// competia com o conteúdo e sujava o canto de toda tela. Agora é só texto
/// miúdo e apagado — presente para quem procura, invisível para quem não.
///
/// `IgnorePointer` porque não é botão: capturando toque, ele comeria o clique
/// de qualquer coisa que passasse embaixo no canto da tela.
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
          // Rodapé, e não topo: em cima ele disputa com a barra de título e com
          // os botões de ação de cada tela; embaixo a faixa é sempre folgada.
          bottom: MediaQuery.of(context).padding.bottom + 4,
          right: 10,
          child: IgnorePointer(
            child: Text(
              kVersaoCurta,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                height: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
