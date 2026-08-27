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
class GraficoSerie extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final amostras = [
      for (final ponto in pontos)
        FlSpot(ponto.instante.millisecondsSinceEpoch.toDouble(), ponto.valor),
    ];

    final valores = pontos.map((p) => p.valor);
    final menor = minimoY ?? (valores.reduce(_menor) - _folga(valores));
    final maior = maximoY ?? (valores.reduce(_maior) + _folga(valores));

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.small,
        AppSpacing.large,
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
              color: AppColors.primary,
              barWidth: 2.5,
              // Curva suave, e não reta entre pontos: os valores já são médias
              // de uma faixa de tempo, então a linha entre duas médias é uma
              // interpolação de qualquer jeito — e a curva mente menos sobre
              // haver um degrau exatamente ali.
              isCurved: true,
              curveSmoothness: 0.2,
              preventCurveOverShooting: true,
              // Um ponto por amostra ficaria ilegível com 24 horas de dados; a
              // linha já mostra a forma, que é o que importa.
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.25),
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
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                // Quatro marcas no eixo: mais que isso e os rótulos de hora
                // encostam uns nos outros numa tela de celular.
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
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.surface,
              getTooltipItems: (pontosTocados) => [
                for (final tocado in pontosTocados)
                  LineTooltipItem(
                    '${tocado.y.toStringAsFixed(1)} $unidade\n',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    children: [
                      TextSpan(
                        text: _hora(
                          DateTime.fromMillisecondsSinceEpoch(tocado.x.toInt()),
                        ),
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
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
