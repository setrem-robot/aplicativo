import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/rota_segura.dart';

/// Guarda a última rota planejada entre aberturas do app.
///
/// Mesma escolha do endereço da API (`ajustes_api_screen.dart`):
/// `SharedPreferences`, porque é só uma conveniência local — a rota não é dado
/// sensível e não precisa sair do aparelho. Quem lê e grava aqui não sabe o que
/// é tela, a mesma regra que vale para o Bluetooth e para o HTTP.
class RotaStore {
  RotaStore._();

  static const _chave = 'rota_segura';

  static Future<void> salvar(RotaSegura rota) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chave, jsonEncode(rota.toJson()));
  }

  /// Devolve `null` se não houver rota guardada ou se o que estava lá não puder
  /// mais ser lido (formato antigo, dado corrompido) — nunca lança.
  static Future<RotaSegura?> carregar() async {
    final prefs = await SharedPreferences.getInstance();
    final bruto = prefs.getString(_chave);
    if (bruto == null) return null;
    try {
      return RotaSegura.fromJson(jsonDecode(bruto) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> limpar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chave);
  }
}
