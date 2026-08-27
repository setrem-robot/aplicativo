import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../services/telemetry_api.dart';
import '../widgets/app_card.dart';

/// Onde fica a API, e o token para falar com ela.
///
/// A tela testa antes de salvar. Descobrir um endereço errado só depois, como
/// uma lista vazia no mapa, é o tipo de silêncio que faz alguém procurar o
/// problema no robô — que estará funcionando.
class AjustesApiScreen extends StatefulWidget {
  const AjustesApiScreen({super.key});

  @override
  State<AjustesApiScreen> createState() => _AjustesApiScreenState();
}

class _AjustesApiScreenState extends State<AjustesApiScreen> {
  final _url = TextEditingController();
  final _token = TextEditingController();

  bool _testando = false;
  bool _mostrarToken = false;
  String? _resultado;
  bool _deuCerto = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final api = TelemetryApi.instance;
    await api.carregar();
    if (!mounted) return;
    setState(() => _url.text = api.url);
    // O token não é preenchido de volta de propósito: mostrá-lo na tela seria
    // deixá-lo à vista de quem estiver por perto, sem necessidade nenhuma.
    // Campo vazio ao salvar significa "mantenha o que já está gravado".
  }

  @override
  void dispose() {
    _url.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _salvarETestar() async {
    setState(() {
      _testando = true;
      _resultado = null;
    });

    final api = TelemetryApi.instance;
    // Campo de token vazio mantém o que já estava gravado (ver `salvar`).
    await api.salvar(url: _url.text, token: _token.text);

    String mensagem;
    bool ok;
    try {
      mensagem = await api.testar();
      ok = true;
    } on ErroApi catch (erro) {
      mensagem = erro.mensagem;
      ok = false;
    }

    if (!mounted) return;
    setState(() {
      _testando = false;
      _resultado = mensagem;
      _deuCerto = ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conexão com os dados'),
        backgroundColor: AppColors.background,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.medium),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'O robô grava o que faz num banco na nuvem. Este é o endereço '
                  'de onde o app lê esse histórico — ele não tem nada a ver com '
                  'o Bluetooth: funciona longe do robô, e continua funcionando '
                  'com ele desligado.',
                  style: TextStyle(color: Colors.white70, height: 1.4),
                ),
                const SizedBox(height: AppSpacing.large),
                TextField(
                  controller: _url,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  style: const TextStyle(color: Colors.white),
                  decoration: _campo(
                    rotulo: 'Endereço da API',
                    dica: 'https://atlas.seudominio.com.br',
                    icone: Icons.link_rounded,
                  ),
                ),
                const SizedBox(height: AppSpacing.medium),
                TextField(
                  controller: _token,
                  obscureText: !_mostrarToken,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: const TextStyle(color: Colors.white),
                  decoration: _campo(
                    rotulo: 'Token',
                    dica: 'deixe vazio para manter o atual',
                    icone: Icons.key_rounded,
                    sufixo: IconButton(
                      icon: Icon(
                        _mostrarToken
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: Colors.white38,
                      ),
                      onPressed: () => setState(() => _mostrarToken = !_mostrarToken),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.large),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _testando ? null : _salvarETestar,
                    icon: _testando
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(_testando ? 'Testando…' : 'Salvar e testar'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onBrand,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                if (_resultado != null) ...[
                  const SizedBox(height: AppSpacing.medium),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _deuCerto ? Icons.check_circle_rounded : Icons.error_rounded,
                        color: _deuCerto ? AppColors.success : Colors.redAccent,
                        size: 18,
                      ),
                      const SizedBox(width: AppSpacing.small),
                      Expanded(
                        child: Text(
                          _resultado!,
                          style: TextStyle(
                            color: _deuCerto ? AppColors.success : Colors.redAccent,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.medium),
          const AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: Colors.white38, size: 18),
                    SizedBox(width: AppSpacing.small),
                    Text('Onde conseguir isto', style: TextStyle(color: Colors.white70)),
                  ],
                ),
                SizedBox(height: AppSpacing.small),
                Text(
                  'O endereço é o domínio publicado pelo túnel da Cloudflare, e o '
                  'token é o API_TOKEN do arquivo .env da VM. Quem instalou a '
                  'nuvem tem os dois — veja docs/setup-cloud.md no repositório '
                  'do orquestrador.',
                  style: TextStyle(color: Colors.white38, height: 1.4, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _campo({
    required String rotulo,
    required String dica,
    required IconData icone,
    Widget? sufixo,
  }) {
    return InputDecoration(
      labelText: rotulo,
      hintText: dica,
      prefixIcon: Icon(icone, color: Colors.white38),
      suffixIcon: sufixo,
      labelStyle: const TextStyle(color: Colors.white54),
      hintStyle: const TextStyle(color: Colors.white24),
      filled: true,
      fillColor: AppColors.background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        borderSide: BorderSide.none,
      ),
    );
  }
}
