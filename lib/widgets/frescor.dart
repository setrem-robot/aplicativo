import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Quão fresco é um dado — e, a partir daí, como ele se parece na tela.
///
/// Esta é a ideia que organiza o painel inteiro. A regra que já valia em texto
/// ("nenhum número aparece sem a idade dele") vira aqui uma regra visual: um
/// dado que está chegando **respira**, e um dado que parou **congela e recua**.
///
/// O motivo é o mesmo de sempre: um painel que mostra "bateria 83%" com a mesma
/// cara para uma leitura de agora e para uma de anteontem faz alguém confiar num
/// robô desligado há dois dias. Uma etiqueta com a idade resolve isso para quem
/// lê a etiqueta; a cor e o movimento resolvem para quem só bate o olho.
enum Frescor {
  /// Chegando agora. O robô está publicando.
  vivo,

  /// Já tem um tempo, mas ainda descreve o robô de hoje.
  morno,

  /// Velho o bastante para não valer como "agora".
  parado;

  factory Frescor.da(Duration idade) {
    if (idade.inSeconds < 60) return Frescor.vivo;
    if (idade.inMinutes < 10) return Frescor.morno;
    return Frescor.parado;
  }

  Color get cor => switch (this) {
    Frescor.vivo => AppColors.success,
    Frescor.morno => AppColors.atencao,
    Frescor.parado => AppColors.parado,
  };

  /// Quanto o valor perde de presença. Recuar é o ponto: o número velho
  /// continua legível, mas para de disputar a atenção com o que está vivo.
  double get opacidade => switch (this) {
    Frescor.vivo => 1.0,
    Frescor.morno => 0.82,
    Frescor.parado => 0.55,
  };
}

/// O ponto que pulsa enquanto o dado é recente.
///
/// Só o [Frescor.vivo] anima. Um ponto que pulsasse sempre viraria enfeite —
/// e enfeite que se mexe é o tipo de coisa que cansa numa tela aberta por
/// minutos. Aqui o movimento **é** a informação: se está pulsando, está
/// chegando.
class PulsoFrescor extends StatefulWidget {
  const PulsoFrescor({super.key, required this.frescor, this.tamanho = 8});

  final Frescor frescor;
  final double tamanho;

  @override
  State<PulsoFrescor> createState() => _PulsoFrescorState();
}

class _PulsoFrescorState extends State<PulsoFrescor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controle = AnimationController(
    vsync: this,
    // Perto do ritmo de uma respiração calma. Rápido demais lê como alarme.
    duration: const Duration(milliseconds: 1900),
  );

  @override
  void initState() {
    super.initState();
    _sincronizar();
  }

  @override
  void didUpdateWidget(PulsoFrescor anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.frescor != widget.frescor) _sincronizar();
  }

  /// Liga o pulso só quando há o que pulsar — e para o controlador quando não
  /// há, em vez de deixá-lo girando invisível gastando quadro.
  void _sincronizar() {
    if (widget.frescor == Frescor.vivo) {
      _controle.repeat();
    } else {
      _controle.stop();
      _controle.value = 0;
    }
  }

  @override
  void dispose() {
    _controle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cor = widget.frescor.cor;
    final nucleo = Container(
      width: widget.tamanho,
      height: widget.tamanho,
      decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
    );

    if (widget.frescor != Frescor.vivo) {
      return SizedBox(
        width: widget.tamanho * 2.6,
        height: widget.tamanho * 2.6,
        child: Center(child: nucleo),
      );
    }

    return SizedBox(
      width: widget.tamanho * 2.6,
      height: widget.tamanho * 2.6,
      child: AnimatedBuilder(
        animation: _controle,
        builder: (context, child) {
          final t = _controle.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              // A onda que sai do ponto e se apaga no caminho.
              Container(
                width: widget.tamanho * (1 + 1.6 * t),
                height: widget.tamanho * (1 + 1.6 * t),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: cor.withValues(alpha: (1 - t) * 0.5),
                    width: 1.5,
                  ),
                ),
              ),
              child!,
            ],
          );
        },
        child: nucleo,
      ),
    );
  }
}

/// Um número que **viaja** até o valor novo em vez de trocar de um quadro para
/// o outro.
///
/// Não é enfeite: numa tela que atualiza por completo, um número que salta não
/// diz se subiu ou desceu, e dois números trocando ao mesmo tempo não dizem
/// qual dos dois mudou. A transição responde as duas coisas de graça.
class ValorAnimado extends StatelessWidget {
  const ValorAnimado({
    super.key,
    required this.valor,
    required this.estilo,
    this.casas = 0,
  });

  final double valor;
  final TextStyle estilo;
  final int casas;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      // Só `end`: o `TweenAnimationBuilder` guarda o valor anterior e viaja
      // dele até o novo sozinho. Informar `begin` faria toda montagem começar
      // do mesmo lugar — e aí o número contaria do zero a cada troca de aba.
      tween: Tween(end: valor),
      duration: AppDurations.swap,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(v.toStringAsFixed(casas), style: estilo),
    );
  }
}
