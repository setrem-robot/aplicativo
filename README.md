# Atlas Controller

App Android/iOS (feito em Flutter) que controla um robô com ESP32 por
Bluetooth Low Energy (BLE). Você escaneia e conecta no robô direto (sem
pareamento prévio) e usa uma cruz direcional na tela para mandar ele andar.

| | |
|---|---|
| **Plataforma alvo** | Android e iOS |
| **Flutter** | 3.47.0 (canal stable) |
| **Comunicação** | BLE (GATT), serviço no padrão Nordic UART Service (NUS) |

> Até uma versão anterior deste app, a comunicação era por Bluetooth Classic
> (SPP) — o que só funcionava no Android. A migração para BLE foi feita
> justamente para permitir rodar no iOS; veja `robot_connection.dart` e o
> firmware em `esp32_ble_bridge.ino` no repositório `orquestrador`.

---

## Índice

- [Como o app funciona, em 30 segundos](#como-o-app-funciona-em-30-segundos)
- [Os dados do robô](#os-dados-do-robô)
- [Rodando o projeto](#rodando-o-projeto)
  - [Primeira vez (depois de clonar)](#primeira-vez-depois-de-clonar)
  - [Testar no Linux (desktop, com Bluetooth real)](#testar-no-linux-desktop-com-bluetooth-real)
  - [Testar no Android (físico ou emulador)](#testar-no-android-físico-ou-emulador)
  - [Testar no iPhone](#testar-no-iphone)
  - [Verificar o código antes de commitar](#verificar-o-código-antes-de-commitar)
- [Como fazer as alterações mais comuns](#como-fazer-as-alterações-mais-comuns)
- [Detalhes de configuração](#detalhes-de-configuração)
  - [Permissões](#permissões)
  - [Identificador do app (`applicationId`)](#identificador-do-app-applicationid)
  - [Assinatura de release](#assinatura-de-release)
  - [Arquivos que não vão para o Git](#arquivos-que-não-vão-para-o-git)

---

## Como o app funciona, em 30 segundos

```
┌─────────────────┐   você toca no robô   ┌─────────────────┐
│  ConnectScreen  │ ────────────────────► │  ControlScreen  │
│                 │                        │                 │
│ escaneia e      │ ◄──────────────────── │ cruz direcional │
│ lista por perto │   botão desconectar    │ + status        │
└────────┬────────┘                        └────────┬────────┘
         │                                          │
         │ "Dados do robô"                          │
         ▼                                          ▼
┌──────────────────┐                      ┌───────────────────┐
│ TelemetriaScreen │                      │  RobotConnection  │
│ agora · trajeto  │                      │  o único que fala │
│ histórico · logs │                      │  com o Bluetooth  │
└────────┬─────────┘                      └─────────┬─────────┘
         │                                          │
         ▼                                          ▼
┌──────────────────┐                            🤖 o robô
│   TelemetryApi   │  ← o único que fala HTTP
└────────┬─────────┘
         ▼
  ☁️ TimescaleDB (VM do LARCC)
```

**Dois caminhos, e eles são independentes.** O Bluetooth manda comandos e só
funciona perto do robô ligado. A API lê o histórico e funciona de qualquer
lugar — inclusive com o robô desligado. É por isso que a tela de dados sai da
tela de conexão, e não da de controle: ver onde o robô andou ontem não deveria
exigir parear nada.

Cada toque num botão envia uma linha de texto pelo Bluetooth:

```json
{"cmd":"F"}
```

As letras são `F` (frente), `B` (ré), `L` (esquerda), `R` (direita) e
`S` (parar). **O firmware do ESP32 precisa entender exatamente esse formato.**
Se você mudar o formato aqui, tem que mudar lá também.

O robô anda **enquanto o dedo está pressionando** o botão. Ao soltar, o app
manda `S` automaticamente — inclusive se o dedo escorregar para fora do botão.

Para o mapa detalhado dos arquivos, veja **[ARQUITETURA.md](ARQUITETURA.md)**.

---

## Os dados do robô

A tela **Dados do robô** (na tela de conexão) mostra o que o robô gravou no
banco da nuvem, em quatro abas:

| Aba | Responde |
|---|---|
| **Agora** | bateria, posição, motores e rede — cada um com a idade do dado |
| **Trajeto** | por onde ele andou, no mapa |
| **Histórico** | como bateria, tensão, velocidade ou satélites mudaram |
| **Eventos** | as mensagens cruas, com o JSON completo |

### Configurar

Na primeira vez o app pede o endereço e o token. Os dois vêm de quem instalou a
nuvem — o endereço é o domínio publicado pelo túnel da Cloudflare, e o token é o
`API_TOKEN` do `.env` da VM. Veja `docs/setup-cloud.md` no repositório do
orquestrador.

Para entregar um APK que já vem configurado:

```bash
flutter build apk --release \
  --dart-define=ATLAS_API_URL=https://api.seudominio.com.br \
  --dart-define=ATLAS_API_TOKEN=o-token-do-.env-da-VM
```

### Ainda não há dados?

O GPS ainda não está montado e ninguém publica bateria — as telas ficariam
vazias, e tela vazia não distingue "o app está errado" de "não há o que
mostrar". Na VM:

```bash
python3 cloud/scripts/semear-demonstracao.py --horas 6
```

Isso gera um trajeto plausível em volta do campus, bateria descarregando e
comandos de motor. Para remover: `--limpar`.

---

## Rodando o projeto

### Primeira vez (depois de clonar)

Você precisa do **Flutter 3.47+**. Se ainda não tem, siga o
[guia oficial](https://docs.flutter.dev/get-started/install).

```bash
git clone <url-do-seu-repositorio>
cd app

flutter pub get     # baixa as dependências listadas no pubspec.yaml
flutter doctor      # confere o que falta no ambiente, por plataforma alvo
```

> Você **não** precisa criar `android/local.properties` na mão. Ele guarda os
> caminhos do SDK da sua máquina, por isso não vai para o Git — o próprio
> `flutter build` gera ele no primeiro uso.

### Testar no Linux (desktop, com Bluetooth real)

Se sua máquina Linux tem um adaptador Bluetooth (`rfkill list bluetooth`
mostra `hci0` e o serviço `bluetooth` está ativo), o `flutter_blue_plus`
fala BLE de verdade por esse rádio via BlueZ — não é só uma prévia visual:

```bash
flutter run -d linux
```

Isso conecta de fato no ESP32 físico, sem precisar de celular nenhum. É o
jeito mais rápido de testar a lógica de conexão durante o desenvolvimento.
Único cuidado: `permission_handler` não tem implementação para desktop —
`connect_screen.dart` já pula o pedido de permissão fora de Android/iOS de
propósito, não "conserte" isso adicionando a chamada de volta.

### Testar no Android (físico ou emulador)

Precisa do Android SDK (via Android Studio). Com um celular Android
conectado (ou emulador rodando):

```bash
flutter run                      # hot reload direto no aparelho
flutter build apk --debug        # ou gera um APK para instalar manualmente
```

O APK sai em `build/app/outputs/flutter-apk/app-debug.apk`. Copie para o
celular (cabo, Google Drive, etc.) e abra para instalar — o Android vai
pedir para autorizar "instalar apps de fontes desconhecidas" na primeira vez.

Para a versão final, menor e mais rápida: `flutter build apk --release`.

> ⚠️ O APK de release hoje é assinado com a **chave de debug** (foi assim que
> o projeto veio). Ele instala e funciona normalmente, mas não serve para
> publicar na Play Store. Veja [Assinatura de release](#assinatura-de-release).

### Testar no iPhone

**Não é possível compilar para iOS sem macOS.** O Xcode — obrigatório para
compilar, assinar e instalar em um iPhone — só roda em macOS; não existe
workaround via Linux/Windows para essa etapa específica. Com acesso a um
Mac (próprio, emprestado, ou um serviço de CI como Codemagic/GitHub Actions
com runner `macos`):

```bash
open ios/Runner.xcworkspace   # no Mac, dentro da pasta do projeto
```

No Xcode: selecione seu iPhone como destino, configure o signing com sua
Apple ID (aba "Signing & Capabilities" do target `Runner`) e rode. A
característica BLE já pede a permissão certa no iOS
(`NSBluetoothAlwaysUsageDescription` em `ios/Runner/Info.plist`).

### Verificar o código antes de commitar

```bash
flutter analyze   # procura erros e código suspeito
flutter test      # roda os testes automatizados (test/*.dart)
```

Os dois precisam passar limpos antes de você subir alterações.

---

## Como fazer as alterações mais comuns

| Quero mudar... | Mexa em... |
|---|---|
| as cores do app | `lib/app/theme.dart` |
| o texto de um botão ou aviso | a tela correspondente em `lib/screens/` |
| adicionar um comando novo (buzina, luz) | `lib/models/robot_command.dart` |
| o formato do que vai pelo Bluetooth | `lib/services/robot_connection.dart`, método `send` |
| os UUIDs do serviço BLE | `RobotBleIds` em `robot_connection.dart` **e** `esp32_ble_bridge.ino` (os dois lados) |
| o nome do app no celular | `android/app/src/main/AndroidManifest.xml`, atributo `android:label` |
| o ícone do app | `android/app/src/main/res/mipmap-*/` |

---

## Detalhes de configuração

### Permissões

**Android**: Bluetooth e Localização — a Localização parece estranha, mas o
Android exige ela para operações de Bluetooth em versões mais antigas; sem
ela a lista de dispositivos volta **vazia e sem erro nenhum**, difícil de
depurar. **iOS**: `NSBluetoothAlwaysUsageDescription` no `Info.plist` — sem
ela o app crasha ao tentar usar Bluetooth.

### Identificador do app (`applicationId`)

Está como `com.example.robot_controller`, o valor de exemplo que o Flutter
gera. Funciona para instalar o APK direto no celular, mas a Play Store
**recusa** qualquer app com `com.example`. Se um dia for publicar, troque
nos dois lugares:

- `android/app/build.gradle.kts` → `applicationId`
- a pasta `android/app/src/main/kotlin/...` e o `package` do `MainActivity.kt`

### Assinatura de release

Todo APK precisa ser assinado. Sem nenhuma configuração, o projeto assina o
release com a **chave de debug** — a mesma em todo computador do mundo. O
APK instala e funciona, mas a Play Store recusa.

Para usar uma chave sua, o `build.gradle.kts` já está preparado: basta criar
os dois arquivos abaixo e o build passa a usá-los sozinho.

1. Gere o keystore (guarde bem a senha, ela não tem como ser recuperada):

   ```bash
   keytool -genkey -v -keystore ~/robot-controller.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias robot
   ```

2. Crie `android/key.properties` a partir do modelo versionado:

   ```bash
   cp android/key.properties.example android/key.properties
   # abra e preencha as senhas e o caminho do .jks
   ```

3. `flutter build apk --release` — pronto, sai assinado com a sua chave.

> 🔒 **Nunca** suba `key.properties` nem o `.jks` para o GitHub. Os dois já
> estão no `.gitignore`. Se a chave vazar, outra pessoa consegue publicar
> atualizações falsas em nome do seu app — e trocar a chave depois de
> publicado é um processo doloroso.

### Arquivos que não vão para o Git

- `android/local.properties` — caminhos do SDK **da sua máquina**, gerado
  automaticamente.
- `build/` e `.dart_tool/` — resultado da compilação, regeráveis.
- `*.jks` e `key.properties` — chaves de assinatura, são segredo.
