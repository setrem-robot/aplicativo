# Robot Controller

App Android (feito em Flutter) que controla um robô com ESP32 por Bluetooth.
Você conecta no robô já pareado no celular e usa uma cruz direcional na tela
para mandar ele andar.

| | |
|---|---|
| **Plataforma alvo** | Android (o Bluetooth clássico usado aqui não existe no iOS) |
| **Flutter** | 3.47.0 (canal stable) |
| **Comunicação** | Bluetooth Serial (SPP), o mesmo do módulo HC-05/ESP32 |

---

## Como o app funciona, em 30 segundos

```
┌─────────────────┐   você toca no robô   ┌─────────────────┐
│  ConnectScreen  │ ────────────────────► │  ControlScreen  │
│                 │                        │                 │
│ lista os        │ ◄──────────────────── │ cruz direcional │
│ pareados        │   botão desconectar    │ + status        │
└─────────────────┘                        └─────────────────┘
         │                                          │
         └──────────────┬───────────────────────────┘
                        ▼
              ┌───────────────────┐
              │  RobotConnection  │  ← o único que fala com o Bluetooth
              └───────────────────┘
                        │
                        ▼
                   🤖 ESP32
```

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

## Rodando o projeto

### Primeira vez (depois de clonar)

Você precisa do **Flutter 3.47+** e do **Android SDK** instalados. Se ainda
não tem, siga o [guia oficial](https://docs.flutter.dev/get-started/install)
— ele instala os dois.

```bash
git clone <url-do-seu-repositorio>
cd robot_controller

flutter pub get     # baixa as dependências listadas no pubspec.yaml
flutter doctor      # confere se falta alguma coisa no ambiente
```

O `flutter doctor` precisa mostrar ✓ em **Flutter** e em **Android toolchain**.
Os outros itens (Linux desktop, Xcode, Visual Studio) não importam: este app
é para Android.

> Você **não** precisa criar `android/local.properties` na mão. Ele guarda os
> caminhos do SDK da sua máquina, por isso não vai para o Git — o próprio
> `flutter build` gera ele no primeiro uso.

### Gerar um APK para instalar no celular

```bash
flutter build apk --debug
```

O arquivo sai em:

```
build/app/outputs/flutter-apk/app-debug.apk
```

Copie esse arquivo para o celular (cabo USB, Google Drive, WhatsApp para você
mesmo) e abra para instalar. O Android vai pedir para autorizar
"instalar apps de fontes desconhecidas" na primeira vez.

Para a versão final, menor e mais rápida:

```bash
flutter build apk --release
```

> ⚠️ O APK de release hoje é assinado com a **chave de debug** (foi assim que
> o projeto veio). Ele instala e funciona normalmente, mas não serve para
> publicar na Play Store. Veja "Assinatura" mais abaixo.

### Verificar o código antes de commitar

```bash
flutter analyze   # procura erros e código suspeito
flutter test      # roda os testes automatizados
```

Os dois precisam passar limpos antes de você subir alterações.

### Rodar no celular com hot reload (opcional)

Hot reload é quando você salva o arquivo e a mudança aparece na hora no
celular, sem recompilar. Como estamos no WSL, o WSL não enxerga o cabo USB
sozinho — é preciso instalar o [usbipd-win](https://github.com/dorssel/usbipd-win)
no Windows para "passar" o celular para dentro do Linux. Se você não quiser
essa complicação, o caminho do `flutter build apk` acima funciona sempre.

---

## Como fazer as alterações mais comuns

| Quero mudar... | Mexa em... |
|---|---|
| as cores do app | `lib/app/theme.dart` |
| o texto de um botão ou aviso | a tela correspondente em `lib/screens/` |
| adicionar um comando novo (buzina, luz) | `lib/models/robot_command.dart` |
| o formato do que vai pelo Bluetooth | `lib/services/robot_connection.dart`, método `send` |
| o nome do app no celular | `android/app/src/main/AndroidManifest.xml`, atributo `android:label` |
| o ícone do app | `android/app/src/main/res/mipmap-*/` |

---

## Detalhes de configuração

### Permissões

O app pede Bluetooth e Localização. A Localização parece estranha, mas o
Android exige ela para qualquer operação de Bluetooth em versões mais
antigas — sem ela a lista de dispositivos volta **vazia e sem erro nenhum**,
o que é bem difícil de descobrir depurando.

### Identificador do app (`applicationId`)

Está como `com.example.robot_controller`, que é o valor de exemplo que o
Flutter gera. Ele funciona para instalar o APK direto no celular, mas a Play
Store **recusa** qualquer app com `com.example`. Se um dia você for publicar,
troque nos dois lugares:

- `android/app/build.gradle.kts` → `applicationId`
- a pasta `android/app/src/main/kotlin/...` e o `package` do `MainActivity.kt`

### Assinatura de release

Todo APK precisa ser assinado. Sem nenhuma configuração, o projeto assina o
release com a **chave de debug** — que é a mesma em todo computador do mundo.
O APK instala e funciona, mas a Play Store recusa.

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

- `android/local.properties` — tem os caminhos do SDK **da sua máquina**.
  É gerado automaticamente. Foi justamente ele que veio apontando para o
  computador do dono anterior do projeto.
- `build/` e `.dart_tool/` — resultado da compilação, regeráveis.
- `*.jks` e `key.properties` — chaves de assinatura, são segredo.

### Sobre a velocidade

O projeto está numa pasta do Windows (`/mnt/c/...`) acessada pelo Linux. Isso
funciona, mas é lento: um `flutter analyze` leva minutos em vez de segundos.
Se a lentidão incomodar, mova o projeto para dentro do sistema de arquivos do
Linux (por exemplo `~/robot_controller`) — fica muitas vezes mais rápido.
