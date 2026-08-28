import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/telemetria.dart';

/// Um campo da telemetria ao longo do tempo.
///
/// O eixo X é o instante em milissegundos desde a época, porque é isso que o
/// `fl_chart` sabe desenhar — mas ninguém lê milissegundos, então os rótulos
/// são convertidos de volta para hora. Foi por causa disso que os pontos
/// precisam vir ordenados da API: um eixo de tempo fora de ordem desenha a
/// linha indo e voltando, e parece dado corrompido quando é só ordenação.
///
/// É `Stateful` por causa do toque: arrastar o dedo na linha atualiza a
/// **leitura no topo** — o valor e a hora do ponto embaixo do dedo. Antes o
/// toque só mostrava um balão flutuante com um ponto grosso, que tapava a
/// própria linha e saía da tela nas bordas; a leitura fixa no topo não tem
/// nenhum dos dois problemas, e deixa comparar dois instantes sem tirar o dedo.
class GraficoSerie extends StatefulWidget {
  const GraficoSerie({
    super.key,
    required this.pontos,
    required this.unidade,
    this.minimoY,
    this.maximoY,
  });

  final List<PontoSerie> pontos;
  final String unidade;

  /// Fixar a escala é o que torna dois gráficos comparáveis.
  ///
  /// Bateria vai de 0 a 100 sempre. Sem isso, uma variação de 82% a 84% ocupa
  /// a altura inteira e parece um tombo — o gráfico estaria certo e a leitura,
  /// errada.
  final double? minimoY;
  final double? maximoY;

  @override
  State<GraficoSerie> createState() => _GraficoSerieState();
}

class _GraficoSerieState extends State<GraficoSerie> {
  /// Índice do ponto embaixo do dedo, ou `null` quando ninguém está tocando.
  int? _tocado;

  @override
  Widget build(BuildContext context) {
    final pontos = widget.pontos;
    final amostras = [
      for (final ponto in pontos)
        FlSpot(ponto.instante.millisecondsSinceEpoch.toDouble(), ponto.valor),
    ];

    final valores = pontos.map((p) => p.valor);
    final menor = widget.minimoY ?? (valores.reduce(_menor) - _folga(valores));
    final maior = widget.maximoY ?? (valores.reduce(_maior) + _folga(valores));

    return Column(
      children: [
        _Leitura(
          ponto: _tocado != null ? pontos[_tocado!] : pontos.last,
          unidade: widget.unidade,
          acompanhando: _tocado != null,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.small,
              AppSpacing.small,
              AppSpacing.large,
              AppSpacing.small,
            ),
            child: LineChart(
              LineChartData(
                minY: menor,
                maxY: maior,
                lineBarsData: [
                  LineChartBarData(
                    spots: amostras,
                    gradient: const LinearGradient(
                      colors: [AppColors.secondary, AppColors.primary],
                    ),
                    barWidth: 2.5,
                    // Curva suave, e não reta entre pontos: os valores já são
                    // médias de uma faixa de tempo, então a linha entre duas
                    // médias é uma interpolação de qualquer jeito — e a curva
                    // mente menos sobre haver um degrau exatamente ali.
                    isCurved: true,
                    curveSmoothness: 0.2,
                    preventCurveOverShooting: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.primary.withValues(alpha: 0.22),
                          AppColors.primary.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ],
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      const FlLine(color: Colors.white10, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      getTitlesWidget: (valor, meta) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(
                          valor.toStringAsFixed(0),
                          style: const TextStyle(color: Colors.white38, fontSize: 10),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      // Quatro marcas no eixo: mais que isso e os rótulos de
                      // hora encostam uns nos outros numa tela de celular.
                      interval: _intervaloDoEixo(amostras),
                      getTitlesWidget: (valor, meta) => Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _hora(DateTime.fromMillisecondsSinceEpoch(valor.toInt())),
                          style: const TextStyle(color: Colors.white38, fontSize: 10),
                        ),
                      ),
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  // O balão flutuante sai de cena: quem mostra o valor agora é a
                  // leitura no topo. Deixá-lo ligado seria a mesma informação em
                  // dois lugares, um deles tapando a linha.
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (tocados) =>
                        List<LineTooltipItem?>.filled(tocados.length, null),
                    getTooltipColor: (_) => Colors.transparent,
                  ),
                  // A linha vertical fina + um ponto pequeno: o suficiente para
                  // marcar onde o dedo está, sem o disco grosso do padrão.
                  getTouchedSpotIndicator: (barData, indices) => [
                    for (final _ in indices)
                      TouchedSpotIndicatorData(
                        const FlLine(color: Colors.white30, strokeWidth: 1),
                        FlDotData(
                          getDotPainter: (spot, __, ___, ____) =>
                              FlDotCirclePainter(
                            radius: 4,
                            color: AppColors.secondary,
                            strokeColor: AppColors.background,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                  ],
                  touchCallback: (evento, resposta) {
                    final tocado = resposta?.lineBarSpots?.first.spotIndex;
                    // Ao soltar, a leitura volta para o último ponto — o estado
                    // de repouso é "o valor mais recente", não o último tocado.
                    final solto = !evento.isInterestedForInteractions;
                    setState(() => _tocado = solto ? null : tocado);
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A leitura no topo: o valor grande e a hora. Muda de rótulo conforme o dedo
/// arrasta; em repouso, mostra o ponto mais recente.
class _Leitura extends StatelessWidget {
  const _Leitura({
    required this.ponto,
    required this.unidade,
    required this.acompanhando,
  });

  final PontoSerie ponto;
  final String unidade;
  final bool acompanhando;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.large,
        AppSpacing.medium,
        AppSpacing.large,
        AppSpacing.small,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            ponto.valor.toStringAsFixed(1),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w700,
              height: 1,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              unidade,
              style: const TextStyle(color: Colors.white54, fontSize: 16),
            ),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                acompanhando ? 'no ponto tocado' : 'mais recente',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              const SizedBox(height: 2),
              Text(
                _hora(ponto.instante),
                style: TextStyle(
                  color: acompanhando ? AppColors.secondary : Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

double _menor(double a, double b) => a < b ? a : b;
double _maior(double a, double b) => a > b ? a : b;

/// Margem acima e abaixo da linha, para ela não encostar na borda.
///
/// Proporcional à variação, com um mínimo: uma série constante teria folga
/// zero e a linha ficaria colada no meio, sem escala visível.
double _folga(Iterable<double> valores) {
  final amplitude = valores.reduce(_maior) - valores.reduce(_menor);
  return amplitude < 1 ? 1 : amplitude * 0.15;
}

double? _intervaloDoEixo(List<FlSpot> amostras) {
  if (amostras.length < 2) return null;
  final duracao = amostras.last.x - amostras.first.x;
  return duracao <= 0 ? null : duracao / 4;
}

String _hora(DateTime momento) =>
    '${momento.hour.toString().padLeft(2, '0')}:${momento.minute.toString().padLeft(2, '0')}';
