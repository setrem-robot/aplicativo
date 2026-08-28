import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme.dart';
import '../models/telemetria.dart';

/// As mensagens de telemetria como chegaram ao banco.
///
/// É a tela mais feia das quatro e a que mais salva uma depuração em campo: as
/// outras três interpretam o dado, e quando a interpretação é que está errada,
/// só o valor cru resolve. Tocar numa linha abre o JSON inteiro; segurar copia.
class ListaEventos extends StatelessWidget {
  const ListaEventos({super.key, required this.eventos});

  final List<EventoTelemetria> eventos;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.small),
      itemCount: eventos.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white10),
      itemBuilder: (context, indice) => _Linha(evento: eventos[indice]),
    );
  }
}

class _Linha extends StatelessWidget {
  const _Linha({required this.evento});

  final EventoTelemetria evento;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: _Etiqueta(tipo: evento.tipo),
      title: Text(
        _resumir(evento),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.texto, fontSize: 13),
      ),
      subtitle: Text(
        _instanteCompleto(evento.instante),
        style: const TextStyle(color: AppColors.textoApagado, fontSize: 11),
      ),
      onTap: () => _mostrarCru(context, evento),
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: _json(evento)));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('JSON copiado'), duration: Duration(seconds: 1)),
        );
      },
    );
  }
}

/// Uma linha do payload que caiba na largura de um celular.
///
/// Mostrar o JSON inteiro aqui deixaria todas as linhas iguais — `{"lat":
/// -27.77, "lon": -54.24, "fix": tr...` — e a lista perderia a serventia de
/// ser passada com o polegar. Cada tipo tem os dois ou três campos que
/// realmente o distinguem.
String _resumir(EventoTelemetria evento) {
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
    default:
      return _json(evento);
  }
}

String _json(EventoTelemetria evento) =>
    const JsonEncoder.withIndent('  ').convert(evento.dados);

String _instanteCompleto(DateTime momento) {
  String doisDigitos(int n) => n.toString().padLeft(2, '0');
  return '${doisDigitos(momento.day)}/${doisDigitos(momento.month)} '
      '${doisDigitos(momento.hour)}:${doisDigitos(momento.minute)}:'
      '${doisDigitos(momento.second)}';
}

void _mostrarCru(BuildContext context, EventoTelemetria evento) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.large,
        0,
        AppSpacing.large,
        AppSpacing.large,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            evento.topico,
            style: const TextStyle(color: AppColors.primary, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.small),
          Text(
            _instanteCompleto(evento.instante),
            style: const TextStyle(color: AppColors.textoApagado, fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.medium),
          // Rolável: um payload longo não pode empurrar o botão de copiar para
          // fora da tela.
          Flexible(
            child: SingleChildScrollView(
              child: SelectableText(
                _json(evento),
                style: const TextStyle(
                  color: AppColors.texto,
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta({required this.tipo});

  final String tipo;

  /// Uma cor por tipo, para a lista ser lida de relance. Não é decoração:
  /// rolando depressa, o que se procura é a mudança de cor onde não devia
  /// haver uma.
  static const _cores = <String, Color>{
    'gps': Color(0xFF4FC3F7),
    'bateria': Color(0xFF81C784),
    'motores': Color(0xFFFFB74D),
    'wifi': Color(0xFFBA68C8),
  };

  @override
  Widget build(BuildContext context) {
    final cor = _cores[tipo] ?? AppColors.textoApagado;
    return Container(
      width: 62,
      padding: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        tipo,
        textAlign: TextAlign.center,
        style: TextStyle(color: cor, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}
