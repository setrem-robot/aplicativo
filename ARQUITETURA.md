# Arquitetura do projeto

Este documento é para quem abriu o projeto pela primeira vez e quer saber
**onde mexer**. Leia de cima para baixo uma vez; depois use como consulta.

---

## 1. O mapa dos arquivos

Só a pasta `lib/` contém código escrito por humanos. Todo o resto
(`android/`, `ios/`, `web/`, `linux/`, `macos/`, `windows/`, `build/`) é
gerado pelo Flutter — você quase nunca precisa abrir.

```
lib/
├── main.dart                    ① liga o app
│
├── app/
│   └── theme.dart               ② cores e espaçamentos (a "identidade visual")
│
├── models/
│   └── robot_command.dart       ③ os comandos que o robô entende
│
├── services/
│   └── robot_connection.dart    ④ o Bluetooth — o cérebro do app
│
├── screens/
│   ├── connect_screen.dart      ⑤ tela 1: escolher o robô
│   └── control_screen.dart      ⑥ tela 2: dirigir o robô
│
└── widgets/
    ├── app_card.dart            ⑦ peças visuais reaproveitadas
    ├── device_tile.dart
    └── direction_pad.dart
```

### A regra que organiza tudo

> **As telas não sabem o que é Bluetooth. O Bluetooth não sabe o que é tela.**

Quem conversa com o robô é o `robot_connection.dart`, e só ele. As telas
pedem coisas para ele ("conecte neste aparelho", "mande andar pra frente") e
mostram o que ele responde.

Por que isso importa na prática: se um dia você trocar o Bluetooth clássico
por Wi-Fi ou BLE, **reescreve um arquivo só** e as duas telas continuam
funcionando sem nenhuma alteração.

---

## 2. Cada peça, em detalhe

### ① `main.dart` — a chave de ignição

O menor arquivo do projeto, de propósito. Ele trava o app em modo retrato,
aplica o tema e abre a primeira tela. Não coloque lógica aqui.

### ② `app/theme.dart` — as cores

Antes o app tinha `Color(0xFF00E5FF)` escrito à mão em umas 30 linhas
diferentes. Se você quisesse trocar o ciano por verde, teria que caçar todas
elas — e esquecer uma era garantido.

Agora existe `AppColors.primary`. Trocar a cor do app inteiro é mudar
**uma linha**.

```dart
// em vez de:
color: const Color(0xFF00E5FF)
// escreva:
color: AppColors.primary
```

Também tem `AppSpacing` (as distâncias padrão) e `AppTheme.dark` (o tema que
o `main.dart` aplica).

### ③ `models/robot_command.dart` — os comandos

Um `enum`: uma lista fechada de valores possíveis. Cada comando carrega três
informações juntas — a letra que vai pelo Bluetooth, o texto que aparece na
tela e o ícone do botão.

```dart
forward('F', 'FRENTE', Icons.keyboard_arrow_up_rounded),
```

Antes essas três coisas viviam separadas e espalhadas. Se você digitasse
`'f'` minúsculo em algum lugar, o app compilava normalmente e o robô só
ignorava o comando — você descobriria com o robô na mão. Agora
`RobotCommand.forward` ou existe, ou o projeto nem compila.

**Para adicionar um comando novo** (uma buzina, por exemplo): acrescente uma
linha no enum. Ele aparece automaticamente na legenda do rodapé da tela de
controle, porque aquela legenda é montada a partir do próprio enum.

### ④ `services/robot_connection.dart` — o Bluetooth

O arquivo mais importante. Responsabilidades:

- listar os aparelhos pareados;
- conectar e desconectar;
- enviar comandos no formato `{"cmd":"F"}`;
- **perceber quando a conexão cai sozinha.**

Esse último item é a correção mais relevante que foi feita no projeto. Antes,
a tela de controle guardava `bool _isConnected = true` e só reavaliava isso
quando você apertava um botão. Resultado: se o robô desligasse, o app
continuava mostrando "Conectado" em verde e os botões pareciam funcionar,
mas nada chegava no robô.

Agora o serviço fica escutando o canal de entrada do Bluetooth. Quando esse
canal fecha, ele muda o estado para desconectado e **avisa as telas**.

#### Como o aviso chega até a tela

`RobotConnection` é um `ChangeNotifier` — o mecanismo mais simples que o
Flutter tem para isso, e vem embutido (não precisamos instalar Provider,
Riverpod, Bloc nem nada). Ele funciona assim:

```
RobotConnection percebe algo   →   notifyListeners()   →   a tela se redesenha
```

Do lado da tela, quem escuta é o `ListenableBuilder`:

```dart
ListenableBuilder(
  listenable: RobotConnection.instance,
  builder: (context, _) => /* isto é reconstruído a cada aviso */,
)
```

Existe **um único** `RobotConnection` no app inteiro
(`RobotConnection.instance`), porque só há um rádio Bluetooth e um robô.

### ⑤ `screens/connect_screen.dart` — a primeira tela

Pede as permissões do Android, verifica se o Bluetooth está ligado, lista os
aparelhos pareados e conecta no que você tocar.

Este app **não faz busca por aparelhos novos** — o ESP32 precisa ter sido
pareado antes em Configurações → Bluetooth do Android. É por isso que existe
aquela faixa azul de aviso no rodapé da tela.

### ⑥ `screens/control_screen.dart` — a segunda tela

A cruz direcional, o status e o botão de desconectar. A tela inteira está
dentro de um `ListenableBuilder`, então ela acompanha o estado real da
conexão. Quando a conexão cai, os botões ficam apagados e o status vira
"CONEXÃO PERDIDA" em vermelho, em vez de mentir.

Repare que a tela foi dividida em widgets privados pequenos (`_TopBar`,
`_StatusCard`, `_CommandLegend`). O `_` no início do nome significa
"só existe dentro deste arquivo". Isso mantém o método `build` curto o
suficiente para caber na cabeça.

### ⑦ `widgets/` — as peças reaproveitadas

Widgets que aparecem em mais de um lugar, ou que são grandes demais para
ficar dentro de uma tela:

- **`AppCard`** — o cartão escuro de cantos arredondados. Ele estava copiado
  e colado em seis lugares; agora existe uma vez.
- **`IconBadge`** — o quadradinho colorido com ícone dentro.
- **`DeviceTile`** — uma linha da lista de aparelhos.
- **`DirectionPad`** — a cruz direcional inteira.

O `DirectionPad` merece atenção porque ilustra bem a regra da seção 1: ele
**não conhece o Bluetooth**. Ele só avisa "apertaram FRENTE" / "soltaram o
botão", e quem decide o que fazer é a tela de controle. É justamente por
isso que dá para testá-lo sem celular e sem robô nenhum — veja
`test/direction_pad_test.dart`.

---

## 3. Os testes

```bash
flutter test
```

| Arquivo | O que garante |
|---|---|
| `test/robot_command_test.dart` | nenhum comando repete a letra de outro |
| `test/direction_pad_test.dart` | apertar move, soltar para, desconectado não responde |

São poucos e rápidos, e cobrem justamente as regras que, se quebrarem, fazem
o robô se comportar mal de um jeito difícil de perceber olhando a tela.

O teste que veio no projeto (`test/widget_test.dart`) era o exemplo padrão
que o Flutter cria junto com qualquer projeto novo — testava um contador que
nunca existiu neste app e nem compilava. Foi removido.

---

## 4. Por que a arquitetura parou aqui

O app tem cerca de 700 linhas. Existe uma tentação forte de aplicar as
arquiteturas que aparecem nos tutoriais — Clean Architecture, repositórios,
injeção de dependência, Bloc. Para este tamanho, isso adicionaria umas 15
pastas e mais código de encanamento do que de app.

O que foi feito é o meio-termo que resolve os problemas reais que o código
tinha (cores duplicadas, strings mágicas, estado de conexão mentiroso) sem
criar camadas que você teria que aprender antes de conseguir mudar a cor de
um botão.

**Quando valeria a pena crescer:** se aparecerem várias telas novas, ou mais
de um tipo de conexão (Wi-Fi + Bluetooth), ou se o app passar a guardar dados
(histórico de trajetos, perfis de robô). Aí sim entra um gerenciador de
estado de verdade e uma camada de dados separada. Antes disso, não.

---

## 5. Estado do projeto quando foi herdado

Coisas que estavam quebradas e foram corrigidas, para referência:

| Problema | Situação |
|---|---|
| `android/local.properties` apontava para o SDK do dono anterior | corrigido (e o arquivo não vai para o Git) |
| Gradle configurado para usar 8 GB de RAM numa máquina com 7 GB | reduzido para 2 GB |
| Estado de conexão nunca detectava queda | corrigido no `RobotConnection` |
| Teste padrão do Flutter que não compilava | substituído por testes reais |
| Cores hexadecimais repetidas em ~30 lugares | centralizadas em `AppColors` |
| Comandos do robô como strings soltas | viraram o enum `RobotCommand` |
| README genérico ("A new Flutter project") | reescrito |

Pendências conhecidas, para decidir depois:

- `applicationId` ainda é `com.example.robot_controller` — impede publicar na
  Play Store, mas não atrapalha instalar o APK direto.
- O APK de release é assinado com a chave de debug.
- `flutter_bluetooth_serial` está sem manutenção desde 2021. Funciona, mas se
  um dia parar de compilar numa versão futura do Android, a saída é migrar
  para um fork mantido ou para BLE (o que exigiria mudar o firmware do ESP32
  também).
