# Atlas Controller

App Android/iOS (feito em Flutter) que faz duas coisas com a **Atlas**, o robô
do curso de Engenharia de Computação da SETREM:

- **Dirigir**, por Bluetooth Low Energy — você escaneia, conecta direto (sem
  pareamento prévio) e usa uma cruz direcional na tela.
- **Ver os dados**, por HTTPS — bateria, posição no mapa, gráficos de histórico
  e os eventos crus, lidos da API de telemetria.

Os dois caminhos são independentes de propósito: dá para ver a telemetria de
casa, longe do robô, e dá para dirigir sem internet nenhuma.

| | |
|---|---|
| **Plataforma alvo** | Android e iOS |
| **Flutter** | 3.47.0 (canal stable) |
| **Dirigir** | BLE (GATT), serviço no padrão Nordic UART Service (NUS) |
| **Ver os dados** | HTTPS, com token `Bearer` |

**Chegou agora?** A Atlas é maior que este repositório. São três:

| Repositório | O que é | O que faz |
|---|---|---|
| [**aplicativo**](https://github.com/setrem-robot/aplicativo) *(este)* | o controle | dirigir o robô e ver os dados |
| [**orquestrador**](https://github.com/setrem-robot/orquestrador) | o corpo | motores, GPS, Wi-Fi, telemetria e a nuvem |
| [**atlas_ai_v2**](https://github.com/setrem-robot/atlas_ai_v2) | a cara | face animada, voz, IA e a ponte Bluetooth |

> **Do outro lado do BLE não há mais um ESP32.** Quem anuncia o serviço hoje é o
> próprio Raspberry Pi, em `src/roboteye/ble/` no repositório da cara — o Pi 5
> tem Bluetooth próprio, e a placa extra deixou de fazer sentido. Para o app não
> mudou nada: os UUIDs e o formato da mensagem (`{"cmd":"F"}\n`) são os mesmos,
> e o firmware do ESP32 continua funcionando como reserva.
>
> Antes disso a comunicação era Bluetooth Classic (SPP), que só existe no
> Android. A migração para BLE foi o que permitiu rodar no iOS.

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
- [Atualização automática (Shorebird)](#atualização-automática-shorebird)
  - [O ciclo normal do dia a dia](#o-ciclo-normal-do-dia-a-dia)
  - [Quando um patch não dá conta](#quando-um-patch-não-dá-conta)
  - [Publicar manualmente, da sua máquina](#publicar-manualmente-da-sua-máquina)
  - [E o iOS?](#e-o-ios)
  - [Segredos que o CI usa](#segredos-que-o-ci-usa)
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
  --dart-define=ATLAS_API_URL=https://atlas.kerlonr.com.br \
  --dart-define=ATLAS_API_TOKEN=o-token-do-.env-da-VM
```

> ⚠️ **Instalar por cima não aplica esses valores.** O que a build embute é
> só o *padrão de quando não há nada gravado*, e o que a pessoa salvou na tela
> de ajustes fica no aparelho e sobrevive à atualização. Quem já usou o app com
> um endereço antigo continua com ele, e o sintoma é o app novo falhando
> exatamente como o velho — o que faz procurar erro na build, que está certa.
>
> Para o APK configurado valer: **desinstalar antes de instalar**. Ou corrigir
> à mão nos ajustes, que dá no mesmo mas exige digitar o token.

### O que **não** cabe num patch do Shorebird

O Shorebird entrega código Dart pelo ar, mas **não** entrega mudança de asset
nem de código nativo. Três coisas quebram um patch, e a primeira é a que menos
se espera:

| Mudança | Por quê |
|---|---|
| **Usar um ícone novo do `Icons.`** | O Flutter embute só os ícones usados (*tree-shaking* da MaterialIcons). Trocar ou acrescentar um muda o arquivo da fonte, e o patch falha com `UnpatchableChangeException`. |
| Adicionar/trocar fonte, imagem ou qualquer arquivo em `assets/` | Mesma razão. |
| Adicionar dependência com código nativo (um plugin) | Patch não carrega `.so` novo. |

Quando alguma dessas for necessária, o caminho é **subir a `version:` do
pubspec** e cortar um release novo — que exige reinstalar o app. Por isso vale
decidir de uma vez o conjunto de ícones de uma tela, em vez de trocá-los aos
poucos.

E, ao subir a versão, **mude junto a constante em `lib/app/versao.dart`**: ela
existe porque ler a versão em tempo de execução exigiria um plugin nativo, que
é justamente o que não viaja no patch.

### O ícone do app

São **os olhos da Atlas** — a mesma caixa arredondada que o rosto desenha no
robô (`corner_radius = 0.30`, no RobotEye), com o olho direito um pouco mais
baixo, porque sem assimetria "a face parece duas formas idênticas coladas".

Os arquivos não são editados à mão: saem de um gerador, para que mudar a cor ou
a proporção não vire quinze PNGs recortados um a um.

```bash
# precisa de Pillow; num container, para não instalar nada na máquina:
docker run --rm -v "$PWD/tool":/w -w /w python:3.12-slim sh -c \
  "pip install -q Pillow && python gerar_icones.py /w/saida && python gerar_icones_ios.py /w/saida/ios"
```

O gerador escreve também um `conferencia.png`: os tamanhos reais lado a lado e o
adaptativo já recortado em círculo e em squircle. **Olhe esse arquivo antes de
copiar** — é ele que pega o ícone que some no tamanho de 48 px, que é onde ele
mais aparece.

Depois, copie para `android/app/src/main/res/mipmap-*/` e para
`ios/Runner/Assets.xcassets/AppIcon.appiconset/`.

> ⚠️ **Trocar o ícone exige um release novo.** Ele é recurso do Android dentro do
> APK, não código Dart — nenhum patch do Shorebird o entrega. Suba a `version:`
> e avise quem tem o app que precisa reinstalar.

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

> Este APK sai assinado com a chave do projeto (`android/robot-release.jks`) e
> **sem o Shorebird dentro** — ou seja, ele não recebe atualização automática.
> Para gerar o APK que se atualiza sozinho, use `shorebird release` conforme a
> seção "Atualização automática" abaixo.

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

## Atualização automática (Shorebird)

O app se atualiza sozinho. Quem tem o APK instalado **não precisa reinstalar
nada** a cada mudança: o [Shorebird](https://shorebird.dev) entrega o código
Dart novo pela internet, o app baixa em segundo plano e aplica no próximo
abrir.

### O ciclo normal do dia a dia

Você mexe no código Dart, commita, dá `git push` na `main`. Só isso. O
workflow `.github/workflows/deploy.yml` publica um **patch** e os celulares
pegam a atualização sozinhos.

### Quando um patch não dá conta

Patch só troca código Dart. Ele **não** consegue trocar:

- código Kotlin ou o `AndroidManifest.xml`
- dependência nova no `pubspec.yaml` que tenha parte nativa
- versão do Flutter
- ícone e outros recursos Android

Nesses casos, bumpe a `version:` do `pubspec.yaml` (`1.0.0+1` → `1.0.1+2`,
lembrando que o número depois do `+` **precisa** subir) e dê push. O workflow
detecta a versão nova, compila um **APK novo assinado** e publica numa
[GitHub Release](../../releases). Esse APK precisa ser instalado à mão — é a
única hora em que isso acontece.

Se você mexer em código nativo e **esquecer** de bumpar a versão, o passo de
patch falha de propósito, com a mensagem do Shorebird dizendo que detectou
diferença nativa. É o comportamento desejado: melhor o CI falhar do que os
celulares receberem um patch que trava o app.

### Publicar manualmente, da sua máquina

```bash
export PATH="$HOME/.shorebird/bin:$PATH"

shorebird patch --platforms=android --release-version=1.0.1+2   # atualização OTA
shorebird release --platforms=android --artifact=apk            # APK novo
```

### E o iOS?

A esteira cobre **só o Android**. O Shorebird suporta iOS, mas compilar para
iOS exige um runner `macos` no GitHub Actions (mais caro que o `ubuntu`) e uma
conta paga no Apple Developer Program para assinar. Enquanto o iOS for
instalado à mão pelo Xcode, ele não recebe as atualizações automáticas — cada
mudança exige recompilar e reinstalar pelo Mac.

### Segredos que o CI usa

Ficam em **Settings → Secrets and variables → Actions** do repositório:

| Segredo | O que é |
|---|---|
| `SHOREBIRD_TOKEN` | API key criada em [console.shorebird.dev](https://console.shorebird.dev) |
| `ANDROID_KEYSTORE_BASE64` | o `android/robot-release.jks` em base64 |
| `ANDROID_KEYSTORE_PASSWORD` | a senha do keystore |
| `ANDROID_KEY_ALIAS` | o alias da chave (`robot`) |

O keystore **não está no Git** (é segredo). Guarde uma cópia dele fora do
projeto: perdê-lo significa não conseguir mais atualizar o app instalado nos
celulares — só reinstalando do zero.

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

É `com.setrem.robot_controller`. Era `com.example.robot_controller` (o valor de
exemplo que o Flutter gera, que a Play Store recusa) e foi trocado antes de o
app começar a ser distribuído — de propósito, porque **trocar depois é caro**:
para o Android, um `applicationId` diferente é outro app, então a atualização
não instala por cima e todo mundo precisa desinstalar antes.

Se algum dia precisar mudar de novo, são dois lugares:

- `android/app/build.gradle.kts` → `applicationId` e `namespace`
- a pasta `android/app/src/main/kotlin/...` e o `package` do `MainActivity.kt`

### Assinatura de release

Todo APK precisa ser assinado. Sem nenhuma configuração, o projeto assina o
release com a **chave de debug** — que é gerada por máquina. O APK instala e
funciona, mas dois APKs assinados por chaves diferentes não se atualizam: o
Android trata a troca de assinatura como app estranho e recusa a instalação
por cima. Por isso o projeto tem uma chave própria (`android/robot-release.jks`),
usada tanto aqui quanto pelo CI.

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
