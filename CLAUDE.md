# app (Atlas Controller) — contexto para Claude Code

App Flutter (Android/iOS) que controla o robô Atlas por BLE. Para o mapa
completo de arquivos e decisões de design, leia **[`ARQUITETURA.md`](./ARQUITETURA.md)**
primeiro — este arquivo só cobre o que ela não cobre (contexto de ambiente e
do projeto maior).

## Regra de ouro do projeto (de `ARQUITETURA.md`)

> As telas não sabem o que é Bluetooth. O Bluetooth não sabe o que é tela.

Só `lib/services/robot_connection.dart` fala com o rádio. Se for mexer em
como o app se comunica com o robô, é ali — nada mais deveria precisar mudar.

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

## Comandos úteis

```bash
flutter analyze   # deve estar sempre limpo
flutter test      # test/direction_pad_test.dart, test/robot_command_test.dart
flutter run -d linux   # roda aqui mesmo, com Bluetooth real
flutter build apk --debug   # gera APK pra testar em Android físico
```
