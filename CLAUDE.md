# app (Atlas Controller) — contexto para Claude Code

App Flutter (Android/iOS) que controla o robô Atlas por BLE. Para o mapa
completo de arquivos e decisões de design, leia **[`ARQUITETURA.md`](./ARQUITETURA.md)**
primeiro — este arquivo só cobre o que ela não cobre (contexto de ambiente e
do projeto maior).

Para o que atravessa a borda do app — os UUIDs do BLE, o formato das mensagens,
o contrato da API —, o mapa é
[`../orquestrador/MAPA-COMUNICACAO.md`](../orquestrador/MAPA-COMUNICACAO.md).

**O robô não anda hoje, e não é culpa do app.** Conferido por SSH no Pi de
produção: os serviços do `orquestrador` (o roteador e o `motores`) **não estão
instalados**. O comando sai daqui, atravessa o BLE, chega em
`robo/comando/entrada` — e para ali, porque ninguém assina esse tópico. O app
mostra "conectado" e está certo: ele fez a parte dele. Ver a §0 do mapa antes de
procurar defeito em `robot_connection.dart`.

## Regra de ouro do projeto (de `ARQUITETURA.md`)

> As telas não sabem de onde vêm os dados. Quem busca os dados não sabe o que
> é tela.

São **dois** serviços, e nenhuma tela fala direto com rádio nem com rede:

- `lib/services/robot_connection.dart` — o BLE. Mexeu em como o app conversa
  com o robô? É ali, e nada mais deveria mudar.
- `lib/services/telemetry_api.dart` — o HTTP da telemetria. É o único arquivo
  do app que sabe o que é uma requisição.

A diferença entre os dois não é só de transporte: o BLE só funciona perto do
robô ligado, e a API funciona de qualquer lugar, com ele desligado. É por isso
que a tela de dados sai da tela de *conexão*, e não da de controle.

## BLE, não Bluetooth Classic

Migração feita nos commits `troca flutter_bluetooth_serial_plus...` até
`atualiza documentacao para refletir a migracao para BLE`. Pontos que não
estão em `ARQUITETURA.md` porque são mais sobre infraestrutura que sobre
arquitetura do app:

- Pacote: `flutter_blue_plus`. `device.connect()` exige um parâmetro
  `license:` (`License.nonprofit` ou `License.commercial`) — este projeto
  usa `License.nonprofit` (uso educacional/sem fins lucrativos, PIE da
  Setrem). Não remova esse argumento nem troque para `commercial` sem
  entender a licença do pacote.
- UUIDs do serviço BLE (padrão Nordic UART Service) estão em
  `RobotBleIds` (`lib/services/robot_connection.dart`) e **precisam bater**
  com os mesmos UUIDs em
  `../orquestrador/esp32/esp32_ble_bridge/esp32_ble_bridge.ino`. Mudou um
  lado, muda o outro.
- BLE não usa pareamento prévio do sistema (diferente do Classic): a tela de
  conexão escaneia (`RobotConnection.scan()`), não lista pareados.

## Ambiente desta máquina (ver `../CLAUDE.md` para o resto)

- Sem macOS/Xcode aqui — build para iPhone físico não é possível nesta
  máquina.
- Este notebook tem Bluetooth real (BlueZ). `flutter run -d linux` conecta
  de verdade no ESP32 via `flutter_blue_plus_linux` — útil para testar a
  lógica de conexão sem celular.
- `permission_handler` não tem implementação para desktop (Linux/macOS/
  Windows). `connect_screen.dart::_setUpAndScan` já guarda isso com um
  check de `defaultTargetPlatform` — não peça permissões fora de
  Android/iOS, vai lançar `MissingPluginException`.

## Telemetria: o app lê um banco na nuvem

O robô grava o que faz num TimescaleDB numa VM do LARCC; o app lê por uma API
HTTP (FastAPI), publicada num domínio pelo Cloudflare Tunnel. O contrato está
em `../orquestrador/docs/setup-cloud.md`, e a API em `../orquestrador/cloud/api/`.

- **Endereço e token** ficam em `SharedPreferences`, editáveis em
  `ajustes_api_screen.dart`. Para um APK já configurado, use
  `--dart-define=ATLAS_API_URL=...` e `--dart-define=ATLAS_API_TOKEN=...`.
- **`SharedPreferences` não é cofre.** O token é legível num aparelho com root
  ou num backup. É aceitável porque ele só dá leitura da telemetria de um robô
  escolar; se um dia der acesso a mais que isso, o lugar passa a ser
  `flutter_secure_storage`.
- **Mapa**: `flutter_map` + OpenStreetMap, sem chave de API e sem conta de
  faturamento. A atribuição no rodapé do mapa é exigida pela licença (ODbL) —
  não remova.
- **Sem dados para testar?** `python3 cloud/scripts/semear-demonstracao.py`
  no repositório do orquestrador enche o banco com um trajeto plausível.

## `kotlin.incremental=false` no `android/gradle.properties`

Sem essa linha o build morre em `:shared_preferences_android:compileDebugKotlin`
com *"Could not close incremental caches"* — o compilador não consegue fechar os
arquivos de cache que ele mesmo abriu, o que acontece com o projeto num drive
montado (`D:\` visto do WSL) ou com antivírus segurando os arquivos.
Reproduzível depois de um `flutter clean` completo. O custo é build seguinte
mais lento; o APK gerado é o mesmo.

## Comandos úteis

```bash
flutter analyze   # deve estar sempre limpo
flutter test      # test/direction_pad_test.dart, test/robot_command_test.dart
flutter run -d linux   # roda aqui mesmo, com Bluetooth real
flutter build apk --debug   # gera APK pra testar em Android físico

# APK já apontando para a API, sem precisar configurar na tela:
flutter build apk --release \
  --dart-define=ATLAS_API_URL=https://api.seudominio.com.br \
  --dart-define=ATLAS_API_TOKEN=o-token-do-.env-da-VM
```
