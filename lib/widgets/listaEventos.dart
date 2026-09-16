import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme.dart';
import '../models/telemetria.dart';
import 'visorJson.dart';

/// As mensagens de telemetria como chegaram ao banco.
///
/// É a tela que mais salva uma depuração em campo: as outras três interpretam
/// o dado, e quando a interpretação é que está errada, só o valor cru resolve.
/// Tocar numa linha abre o payload no visor (`visorJson.dart`); segurar copia
/// o JSON de uma vez.
///
/// Cada linha leva um friso na cor da fonte — a mesma cor do chip que a
/// filtrou. Rolando depressa, o que se procura é a mudança de cor onde não
/// devia haver uma: dez frisos rosa seguidos e nenhum azul é "o GPS parou de
/// publicar" antes de ler qualquer hora.
class ListaEventos extends StatelessWidget {
  const ListaEventos({super.key, required this.eventos});

  final List<EventoTelemetria> eventos;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.medium,
        AppSpacing.small,
        AppSpacing.medium,
        // Folga no fim para a última linha não encostar no selo de versão.
        AppSpacing.large * 2,
      ),
      itemCount: eventos.length + 1,
      itemBuilder: (context, indice) {
        if (indice == 0) return _Contagem(eventos: eventos);
        return _Linha(evento: eventos[indice - 1]);
      },
    );
  }
}

/// "37 eventos · sistema 20 · gps 17": o que veio, e quanto de cada fonte.
///
/// É a primeira resposta de uma depuração — "chegou alguma coisa do GPS?" —
/// sem precisar rolar a lista contando frisos azuis.
class _Contagem extends StatelessWidget {
  const _Contagem({required this.eventos});

  final List<EventoTelemetria> eventos;

  @override
  Widget build(BuildContext context) {
    final porTipo = <String, int>{};
    for (final evento in eventos) {
      porTipo.update(evento.tipo, (n) => n + 1, ifAbsent: () => 1);
    }
    final tipos = porTipo.keys.toList()..sort((a, b) => porTipo[b]!.compareTo(porTipo[a]!));

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 4,
        children: [
          Text(
            '${eventos.length} ${eventos.length == 1 ? 'evento' : 'eventos'}',
            style: AppText.meta.copyWith(color: AppColors.textoFraco),
          ),
          for (final tipo in tipos)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.fonte(tipo),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text('$tipo ${porTipo[tipo]}', style: AppText.meta),
              ],
            ),
        ],
      ),
    );
  }
}

class _Linha extends StatelessWidget {
  const _Linha({required this.evento});

  final EventoTelemetria evento;

  @override
  Widget build(BuildContext context) {
    final cor = AppColors.fonte(evento.tipo);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => mostrarEvento(context, evento),
          onLongPress: () {
            Clipboard.setData(ClipboardData(text: jsonBonito(evento.dados)));
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(const SnackBar(
                content: Text('JSON copiado'),
                duration: Duration(seconds: 1),
                behavior: SnackBarBehavior.floating,
              ));
          },
          splashColor: cor.withValues(alpha: 0.08),
          highlightColor: cor.withValues(alpha: 0.05),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 3, color: cor.withValues(alpha: 0.9)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              evento.tipo,
                              style: TextStyle(
                                color: cor,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              instanteCompleto(evento.instante),
                              style: AppText.meta.copyWith(
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          resumirEvento(evento),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.texto,
                            fontSize: 13.5,
                            height: 1.35,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
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

/// Uma linha do payload que caiba na largura de um celular.
///
/// Mostrar o JSON inteiro aqui deixaria todas as linhas iguais — `{"lat":
/// -27.77, "lon": -54.24, "fix": tr...` — e a lista perderia a serventia de
/// ser passada com o polegar. Cada tipo tem os dois ou três campos que
/// realmente o distinguem. Visível para o teste.
String resumirEvento(EventoTelemetria evento) {
  final dados = evento.dados;
  switch (evento.tipo) {
    case 'gps':
      final lat = dados['lat'], lon = dados['lon'];
      final sinal = dados['fix'] == true ? '' : ' (sem sinal)';
      return '$lat, $lon · ${dados['velocidade_kmh'] ?? '?'} km/h$sinal';
    case 'bateria':
      return '${dados['percentual'] ?? '?'}% · ${dados['tensao_v'] ?? '?'} V';
    case 'motores':
      final motivo = dados['motivo'];
      final base = '${dados['acao'] ?? '?'} · '
          'E ${dados['esquerda'] ?? '?'} / D ${dados['direita'] ?? '?'}';
      return motivo == null ? base : '$base · $motivo';
    case 'wifi':
      return dados['conectado'] == true
          ? '${dados['ssid'] ?? 'conectado'} · ${dados['ip'] ?? ''}'
          : 'fora do ar';
    case 'sistema':
      // Temperatura, CPU e memória: as três coisas que se olham primeiro no
      // Pi. Antes o `sistema` caía no `default` e a linha era o JSON inteiro
      // — trinta campos espremidos em uma linha, ilegível.
      final partes = <String>[];
      final temp = dados['temperatura_c'];
      if (temp is num) partes.add('${temp.toStringAsFixed(1)} °C');
      final cpu = _pct(dados['cpu']);
      if (cpu != null) partes.add('CPU $cpu%');
      final mem = _pct(dados['memoria']);
      if (mem != null) partes.add('mem $mem%');
      final throttled = dados['throttled'];
      if (throttled is Map && throttled['ok'] == false) partes.add('throttled!');
      return partes.isEmpty ? jsonBonito(dados) : partes.join(' · ');
    default:
      return jsonBonito(dados);
  }
}

/// `uso_pct` de um bloco (`cpu`, `memoria`) como inteiro, ou `null`.
String? _pct(Object? bloco) {
  if (bloco is! Map) return null;
  final valor = bloco['uso_pct'];
  return valor is num ? valor.toStringAsFixed(0) : null;
}
