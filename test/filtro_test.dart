import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robot_controller/models/filtro.dart';
import 'package:robot_controller/services/filtroStore.dart';
import 'package:robot_controller/widgets/barraFiltro.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// O filtro é guardado entre aberturas do app, e um filtro guardado por uma
/// versão antiga não pode derrubar a barra da versão nova. Estes testes cobrem
/// os dois lados: o que se guarda volta igual, e o que não dá para ler vira o
/// padrão — nunca uma exceção.
void main() {
  group('Fonte', () {
    test('acha a fonte pelo tipo do JSON', () {
      expect(Fonte.deTipo('gps'), Fonte.gps);
      expect(Fonte.deTipo('sistema'), Fonte.sistema);
    });

    test('tipo desconhecido (ou nulo) vira null, não exceção', () {
      // O payload é livre: um grupo pode publicar um tipo novo amanhã.
      expect(Fonte.deTipo('lidar'), isNull);
      expect(Fonte.deTipo(null), isNull);
    });
  });

  group('Grandeza', () {
    test('cada grandeza tem um id estável, único e recuperável', () {
      final ids = Grandeza.todas.map((g) => g.id).toSet();
      expect(ids.length, Grandeza.todas.length);
      for (final grandeza in Grandeza.todas) {
        expect(Grandeza.deId(grandeza.id), same(grandeza));
      }
    });

    test('id que deixou de existir vira null', () {
      expect(Grandeza.deId('sistema.campo_que_sumiu'), isNull);
    });
  });

  group('PresetFiltro', () {
    test('vai e volta do JSON', () {
      const preset = PresetFiltro(nome: 'Pi + GPS', fontes: {Fonte.sistema, Fonte.gps});
      final lido = PresetFiltro.fromJson(preset.toJson());
      expect(lido?.nome, 'Pi + GPS');
      expect(lido?.fontes, {Fonte.sistema, Fonte.gps});
    });

    test('ignora fontes que o app não conhece mais, mas mantém as outras', () {
      final lido = PresetFiltro.fromJson({
        'nome': 'antigo',
        'fontes': ['gps', 'lidar'],
      });
      expect(lido?.fontes, {Fonte.gps});
    });

    test('sem nome, sem lista ou só com fontes desconhecidas, é descartado', () {
      expect(PresetFiltro.fromJson({'fontes': ['gps']}), isNull);
      expect(PresetFiltro.fromJson({'nome': 'x'}), isNull);
      expect(PresetFiltro.fromJson({'nome': 'x', 'fontes': ['lidar']}), isNull);
    });
  });

  group('FiltroStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('nasce com todas as fontes e uma grandeza', () async {
      final filtro = FiltroStore.instance;
      await filtro.carregar();
      expect(filtro.todasAsFontes, isTrue);
      expect(filtro.grandezas, [Grandeza.todas.first]);
    });

    test('os chips somam, e desmarcar a última volta para todas', () async {
      final filtro = FiltroStore.instance;
      await filtro.carregar();

      filtro.somenteFonte(Fonte.gps);
      expect(filtro.fontes, {Fonte.gps});

      filtro.alternarFonte(Fonte.sistema);
      expect(filtro.fontes, {Fonte.gps, Fonte.sistema});

      filtro.alternarFonte(Fonte.gps);
      filtro.alternarFonte(Fonte.sistema);
      // Sem nenhuma fonte a tela não teria o que mostrar.
      expect(filtro.todasAsFontes, isTrue);
    });

    test('um preset com o mesmo nome substitui o anterior', () async {
      final filtro = FiltroStore.instance;
      await filtro.carregar();

      filtro.somenteFonte(Fonte.gps);
      filtro.salvarPreset('meu');
      filtro.alternarFonte(Fonte.wifi);
      filtro.salvarPreset('meu');

      expect(filtro.presets.length, 1);
      expect(filtro.presets.single.fontes, {Fonte.gps, Fonte.wifi});
      expect(filtro.presetAtivo, same(filtro.presets.single));

      filtro.removerPreset(filtro.presets.single);
      expect(filtro.presets, isEmpty);
      filtro.todasFontes();
    });

    test('o que foi guardado volta na próxima leitura', () async {
      SharedPreferences.setMockInitialValues({
        'filtro_fontes': ['gps', 'bateria'],
        'filtro_grandezas': ['gps.velocidade_kmh', 'sistema.temperatura_c'],
        'filtro_janela': '7 d',
        'filtro_presets': '[{"nome":"energia","fontes":["bateria"]}]',
      });
      final filtro = FiltroStore.instance;
      // O singleton já carregou noutro teste; força uma leitura nova
      // aplicando os valores como se viessem do disco.
      final lido = _lerDeNovo(filtro);
      await lido;

      expect(filtro.fontes, {Fonte.gps, Fonte.bateria});
      // Na ordem da lista de grandezas, não na ordem em que foram guardadas.
      expect(filtro.grandezas.map((g) => g.rotulo), ['Temperatura', 'Velocidade']);
      expect(filtro.janela, '7 d');
      expect(filtro.presets.single.nome, 'energia');
    });

    test('valor guardado que não faz mais sentido vira o padrão', () async {
      SharedPreferences.setMockInitialValues({
        'filtro_fontes': ['lidar'],
        'filtro_grandezas': ['sistema.campo_que_sumiu'],
        'filtro_presets': 'isto não é JSON',
      });
      final filtro = FiltroStore.instance;
      await _lerDeNovo(filtro);

      expect(filtro.todasAsFontes, isTrue);
      expect(filtro.grandezas, [Grandeza.todas.first]);
      expect(filtro.presets, isEmpty);
    });
  });

  group('BarraFontes', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('tocar soma; segurar deixa só um', (tester) async {
      final filtro = FiltroStore.instance;
      await filtro.carregar();
      filtro.todasFontes();

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: BarraFontes(filtro: filtro))),
      );

      await tester.longPress(find.text('GPS'));
      await tester.pumpAndSettle();
      expect(filtro.fontes, {Fonte.gps});

      await tester.tap(find.text('Raspberry Pi'));
      await tester.pumpAndSettle();
      expect(filtro.fontes, {Fonte.gps, Fonte.sistema});

      // Com um filtro que não é "todas" e sem preset igual, a barra oferece
      // guardar; com "todas", não há o que guardar e o convite some.
      expect(find.text('salvar este filtro'), findsOneWidget);
      await tester.tap(find.text('todas'));
      await tester.pumpAndSettle();
      expect(find.text('salvar este filtro'), findsNothing);
    });
  });
}

/// O `FiltroStore` é um singleton que só lê o disco uma vez. Para testar a
/// leitura com valores diferentes, a saída é passar pelo mesmo caminho que o
/// app usa — `carregar()` — depois de zerar a marca de "já carregado", o que
/// aqui é feito recriando os valores falsos e chamando de novo pela porta
/// pública que existe para isso.
Future<void> _lerDeNovo(FiltroStore filtro) => filtro.recarregarParaTeste();
