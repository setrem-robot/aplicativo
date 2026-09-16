import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/filtro.dart';

/// O filtro da tela de dados: quais fontes e grandezas a pessoa quer ver.
///
/// É um `ChangeNotifier` porque **duas abas olham para o mesmo filtro**: tocar
/// "GPS" na aba Agora esconde os outros cartões ali e, ao passar para Eventos,
/// a lista já vem só com GPS. Um estado por aba faria a pessoa montar o mesmo
/// filtro duas vezes — e é montar o filtro que dá trabalho.
///
/// Guarda a si mesmo em `SharedPreferences`, como o `TelemetryApi` faz com o
/// endereço: é conveniência local, sem nada sensível. Quem está depurando o
/// GPS fecha o app, abre de novo e encontra o GPS onde deixou.
///
/// Nunca lança ao carregar: um valor guardado por uma versão antiga do app
/// vira o padrão, não uma tela quebrada.
class FiltroStore extends ChangeNotifier {
  FiltroStore._();

  static final FiltroStore instance = FiltroStore._();

  static const _chaveFontes = 'filtro_fontes';
  static const _chavePresets = 'filtro_presets';
  static const _chaveGrandezas = 'filtro_grandezas';
  static const _chaveJanela = 'filtro_janela';

  /// Quantos presets cabem. Não é limite técnico: acima disso a fileira de
  /// chips vira uma lista que ninguém mais lê, e o filtro perde a graça de
  /// ser um toque.
  static const int maximoPresets = 6;

  Set<Fonte> _fontes = Fonte.todas;
  List<PresetFiltro> _presets = const [];
  Set<Grandeza> _grandezas = {Grandeza.todas.first};
  String _janela = '24 h';
  bool _carregado = false;

  /// As fontes marcadas. Nunca vazia: sem nenhuma fonte a tela não teria o
  /// que mostrar, então desmarcar a última volta para "todas".
  Set<Fonte> get fontes => _fontes;

  /// Se o filtro está deixando tudo passar.
  bool get todasAsFontes => _fontes.length == Fonte.values.length;

  List<PresetFiltro> get presets => _presets;

  /// As grandezas escolhidas para o histórico, na ordem de [Grandeza.todas]
  /// (e não na ordem em que foram tocadas — a ordem dos gráficos deve ser a
  /// mesma da barra, senão a pessoa não acha o que acabou de ligar).
  List<Grandeza> get grandezas =>
      [for (final g in Grandeza.todas) if (_grandezas.contains(g)) g];

  String get janela => _janela;

  bool fonteMarcada(Fonte fonte) => _fontes.contains(fonte);
  bool grandezaMarcada(Grandeza grandeza) => _grandezas.contains(grandeza);

  /// O preset que corresponde exatamente ao filtro atual, se houver — para o
  /// chip dele aparecer aceso e o botão "salvar" não oferecer guardar de novo.
  PresetFiltro? get presetAtivo {
    for (final preset in _presets) {
      if (setEquals(preset.fontes, _fontes)) return preset;
    }
    return null;
  }

  // -- fontes ---------------------------------------------------------------

  void alternarFonte(Fonte fonte) {
    final novas = Set<Fonte>.of(_fontes);
    if (!novas.remove(fonte)) novas.add(fonte);
    _fontes = novas.isEmpty ? Fonte.todas : novas;
    _mudou();
  }

  /// Deixa só esta fonte. É o atalho de quem está depurando uma coisa: um
  /// toque longo no chip, em vez de desmarcar as outras quatro.
  void somenteFonte(Fonte fonte) {
    _fontes = {fonte};
    _mudou();
  }

  void todasFontes() {
    _fontes = Fonte.todas;
    _mudou();
  }

  // -- presets --------------------------------------------------------------

  void aplicarPreset(PresetFiltro preset) {
    _fontes = Set.unmodifiable(preset.fontes);
    _mudou();
  }

  /// Guarda o filtro atual com este nome. Um nome repetido substitui o preset
  /// antigo, em vez de criar um segundo chip igual.
  void salvarPreset(String nome) {
    final limpo = nome.trim();
    if (limpo.isEmpty) return;
    final novos = [for (final p in _presets) if (p.nome != limpo) p];
    novos.add(PresetFiltro(nome: limpo, fontes: Set.unmodifiable(_fontes)));
    _presets = List.unmodifiable(novos.take(maximoPresets));
    _mudou();
  }

  void removerPreset(PresetFiltro preset) {
    _presets = List.unmodifiable([for (final p in _presets) if (p.nome != preset.nome) p]);
    _mudou();
  }

  // -- histórico ------------------------------------------------------------

  void alternarGrandeza(Grandeza grandeza) {
    final novas = Set<Grandeza>.of(_grandezas);
    if (!novas.remove(grandeza)) novas.add(grandeza);
    // Mesma regra das fontes: sem nenhuma, o histórico seria uma aba em branco.
    _grandezas = novas.isEmpty ? {grandeza} : novas;
    _mudou();
  }

  void definirJanela(String janela) {
    _janela = janela;
    _mudou();
  }

  // -- persistência ---------------------------------------------------------

  /// Lê o que está guardado. Idempotente: as abas chamam ao montar, e só a
  /// primeira chamada faz alguma coisa.
  Future<void> carregar() async {
    if (_carregado) return;
    _carregado = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      // Cada chave é lida por conta própria: um preset corrompido não pode
      // levar junto as fontes e as grandezas que estavam íntegras ao lado.
      _fontes = _ou(() => _lerFontes(prefs.getStringList(_chaveFontes)), Fonte.todas);
      _presets = _ou(() => _lerPresets(prefs.getString(_chavePresets)), const []);
      _grandezas = _ou(
        () => _lerGrandezas(prefs.getStringList(_chaveGrandezas)),
        {Grandeza.todas.first},
      );
      _janela = _ou(() => prefs.getString(_chaveJanela) ?? _janela, _janela);
    } catch (erro) {
      debugPrint('filtro: não deu para ler o guardado ($erro); usando o padrão');
    }
    notifyListeners();
  }

  /// O valor lido, ou o padrão se a leitura lançar (JSON inválido, tipo
  /// errado gravado por uma versão antiga do app).
  static T _ou<T>(T Function() ler, T padrao) {
    try {
      return ler();
    } catch (erro) {
      debugPrint('filtro: valor guardado ilegível ($erro); usando o padrão');
      return padrao;
    }
  }

  /// Lê o disco de novo, ignorando a marca de "já carregado". Só para os
  /// testes, que precisam simular várias aberturas do app num processo só.
  @visibleForTesting
  Future<void> recarregarParaTeste() {
    _carregado = false;
    return carregar();
  }

  static Set<Fonte> _lerFontes(List<String>? tipos) {
    if (tipos == null) return Fonte.todas;
    final fontes = {for (final t in tipos) if (Fonte.deTipo(t) != null) Fonte.deTipo(t)!};
    return fontes.isEmpty ? Fonte.todas : Set.unmodifiable(fontes);
  }

  static List<PresetFiltro> _lerPresets(String? bruto) {
    if (bruto == null) return const [];
    final decodificado = jsonDecode(bruto);
    if (decodificado is! List) return const [];
    return List.unmodifiable([
      for (final item in decodificado)
        if (item is Map && PresetFiltro.fromJson(item.cast<String, dynamic>()) != null)
          PresetFiltro.fromJson(item.cast<String, dynamic>())!,
    ]);
  }

  static Set<Grandeza> _lerGrandezas(List<String>? ids) {
    if (ids == null) return {Grandeza.todas.first};
    final grandezas = {for (final id in ids) if (Grandeza.deId(id) != null) Grandeza.deId(id)!};
    return grandezas.isEmpty ? {Grandeza.todas.first} : grandezas;
  }

  void _mudou() {
    notifyListeners();
    // Sem `await`: a tela já mudou, e gravar é detalhe que pode acontecer
    // depois. Uma falha aqui só significa que a próxima abertura volta ao
    // padrão — não vale travar um toque por isso.
    _gravar();
  }

  Future<void> _gravar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_chaveFontes, [for (final f in _fontes) f.tipo]);
      await prefs.setString(_chavePresets, jsonEncode([for (final p in _presets) p.toJson()]));
      await prefs.setStringList(_chaveGrandezas, [for (final g in _grandezas) g.id]);
      await prefs.setString(_chaveJanela, _janela);
    } catch (erro) {
      debugPrint('filtro: não deu para guardar ($erro)');
    }
  }
}
