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
│   ├── robot_command.dart       ③ os comandos que o robô entende
│   ├── telemetria.dart          ⑧ o que a API devolve, em objetos
│   └── rota_segura.dart         ⑭ a rota segura: waypoints + cerca
│
├── services/
│   ├── robot_connection.dart    ④ o Bluetooth — o cérebro do app
│   ├── telemetry_api.dart       ⑨ o HTTP — a outra metade dos dados
│   └── rota_store.dart          ⑭ guarda a rota entre aberturas
│
├── screens/
│   ├── connect_screen.dart      ⑤ tela 1: escolher o robô
│   ├── control_screen.dart      ⑥ tela 2: dirigir o robô
│   ├── telemetria_screen.dart   ⑩ tela 3: o que o robô fez (quatro abas)
│   ├── ajustes_api_screen.dart  ⑪ onde ficam os dados
│   └── rota_segura_screen.dart  ⑭ desenhar a rota sobre o mapa
│
└── widgets/
    ├── camada_osm.dart          ⑭ o mapa OSM (tiles + atribuição)
    ├── app_card.dart            ⑦ peças visuais reaproveitadas
    ├── device_tile.dart
    ├── direction_pad.dart
    ├── carregando.dart          ⑫ o ciclo "carregando → deu certo → deu errado"
    ├── painel_estado.dart       ⑬ as quatro abas da telemetria
    ├── mapa_trajeto.dart
    ├── grafico_serie.dart
    └── lista_eventos.dart
```

### A regra que organiza tudo

> **As telas não sabem de onde vêm os dados. Quem busca os dados não sabe o
> que é tela.**

Isso já valia para o Bluetooth e agora vale igual para o HTTP. Há **dois**
serviços, e nenhuma tela fala direto com rádio ou com rede:

| Serviço | De onde vêm os dados | Quando funciona |
|---|---|---|
| `robot_connection.dart` | o rádio BLE do robô | perto do robô, com ele ligado |
| `telemetry_api.dart` | a API na VM do LARCC | de qualquer lugar, robô ligado ou não |

Essa segunda linha é o ponto: o histórico **não depende do robô**. É por isso
que a tela de dados é alcançada da tela de conexão, e não da de controle —
quem abre o app para ver onde o robô andou ontem não deveria precisar parear
nada antes.

Por que isso importa na prática: se um dia você trocar o Bluetooth clássico
por Wi-Fi ou BLE, **reescreve um arquivo só** e as telas continuam
funcionando sem nenhuma alteração. O mesmo vale para trocar a API.

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

E isso não é hipótese: o app nasceu ciano e hoje é verde, na paleta oficial
da Setrem (`#00BF6F`, Pantone 7480 C). A troca custou quatro constantes neste
arquivo. Nenhuma tela precisou ser tocada — só o selo "ROBO" da tela de
controle, porque o texto branco dele sumia em cima do degradê claro.

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

### ⑧⑨ `telemetria.dart` e `telemetry_api.dart` — os dados da nuvem

O robô grava o que faz num TimescaleDB numa VM do LARCC. O app lê de lá por uma
API HTTP — e é isso que permite ver o trajeto de ontem sentado em casa, com o
robô desligado.

`telemetry_api.dart` é o **único** arquivo do app que sabe o que é HTTP. Ele
guarda o endereço e o token, monta as requisições e traduz falha de rede em
frase que uma pessoa entende: `SocketException: Failed host lookup` vira "não
consegui alcançar a API — confira o endereço e a internet".

Repare que ele **não** é um `ChangeNotifier`, ao contrário do
`RobotConnection`. A diferença é real: a conexão Bluetooth cai sozinha e
precisa avisar as telas, enquanto a telemetria só chega quando alguém pede.
Um `ChangeNotifier` aqui daria a impressão errada de que os dados se atualizam
por conta própria.

`telemetria.dart` converte o JSON em objetos, e todos os `fromJson` são
**tolerantes**: campo ausente ou com tipo errado vira `null`, nunca exceção. O
payload da telemetria é livre — cada grupo do projeto publica o que decidir — e
um app que quebra a tela porque o GPS parou de mandar `satelites` seria pior
que um que mostra um traço.

### ⑩ `telemetria_screen.dart` — quatro perguntas diferentes

| Aba | Responde |
|---|---|
| **Agora** | o robô está bem? bateria, posição, motores, rede — cada um com a idade do dado |
| **Trajeto** | por onde ele andou? mapa com a linha do percurso |
| **Histórico** | como isso mudou? gráfico de bateria, tensão, velocidade ou satélites |
| **Eventos** | o que exatamente chegou? as mensagens cruas, com o JSON completo |

A aba de eventos é a mais feia e a que mais salva uma depuração em campo: as
outras três interpretam o dado, e quando é a interpretação que está errada, só
o valor cru resolve.

**Nenhum número aparece sem a idade dele.** Um painel que mostra "bateria 83%"
com a mesma cara para um dado de agora e para um de anteontem é pior que um
painel vazio — ele faz alguém confiar num robô que está desligado há dois dias.
E a idade vem calculada da API, não do relógio do celular, que pode estar
errado.

### ⑫ `carregando.dart` — o ciclo repetido quatro vezes

As quatro abas fazem a mesma coisa: pedem algo, mostram um giro, mostram o
conteúdo ou o erro, e deixam tentar de novo. Escrever isso quatro vezes
garantiria que uma delas esquecesse o "tentar de novo" — e a que esquecesse
seria descoberta com o robô ligado, numa apresentação.

Ele também separa **"deu erro"** de **"deu certo e não havia nada"**. São
problemas com soluções opostas, e com a mesma cara na tela ninguém sabe se
procura o defeito na API ou espera o robô ser ligado.

### ⑭ A rota segura — planejar por onde o robô pode andar

Uma rota é uma lista de waypoints presa dentro de uma **cerca**: um círculo em
volta do ponto de partida. O primeiro toque no mapa fixa a partida (o centro da
cerca) e os pontos seguintes só entram se couberem dentro do raio. É daí que vem
o "segura": não dá para, sem querer, desenhar uma rota que leva o robô para fora
da área combinada — a validação está em `rota_segura.dart`, testada sem mapa e
sem robô.

Ela segue a mesma regra de ouro das outras duas fontes de dados. A **tela**
(`rota_segura_screen.dart`) só desenha e decide o que é um ponto válido; quem
**envia** é o `RobotConnection.enviarRota` (o único que fala com o rádio), e quem
**guarda** entre aberturas é o `RotaStore` (SharedPreferences, como o endereço da
API). O envio é **fatiado**: cada linha BLE não pode passar de 512 bytes (limite
do firmware do ESP32), então a rota vira uma sequência `inicio` → um `ponto` por
waypoint → `fim`, cada linha bem abaixo do teto. O contrato completo está em
`../orquestrador/docs/contrato-mqtt.md`.

O mapa da OSM (os tiles e a atribuição que a licença exige) saiu para
`widgets/camada_osm.dart`, porque agora duas telas o usam — o trajeto da
telemetria e esta. Era exatamente a duplicação que a seção ② descreve, só que de
um mapa em vez de uma cor.

**O que este MVP não faz:** o robô ainda é dirigido no braço; a rota é um guia
planejado, não um piloto automático. Um serviço no Raspberry Pi que *siga* a rota
(malha fechada de GPS) é o próximo passo, e mora do lado do `orquestrador` porque
precisa manter os motores vivos localmente (o vigia de 1 s pararia qualquer
navegação comandada de longe pela rede).

---

## 3. Os testes

```bash
flutter test
```

| Arquivo | O que garante |
|---|---|
| `test/robot_command_test.dart` | nenhum comando repete a letra de outro |
| `test/direction_pad_test.dart` | apertar move, soltar para, desconectado não responde |
| `test/telemetria_test.dart` | payload torto não derruba a tela, e a idade vem da API |
| `test/rota_segura_test.dart` | ponto fora da cerca é recusado, e a rota fatiada cabe no limite BLE |

São poucos e rápidos, e cobrem justamente as regras que, se quebrarem, fazem
o robô se comportar mal de um jeito difícil de perceber olhando a tela.

O teste que veio no projeto (`test/widget_test.dart`) era o exemplo padrão
que o Flutter cria junto com qualquer projeto novo — testava um contador que
nunca existiu neste app e nem compilava. Foi removido.

---

## 4. Por que a arquitetura parou aqui

O app tem cerca de 3400 linhas. Existe uma tentação forte de aplicar as
arquiteturas que aparecem nos tutoriais — Clean Architecture, repositórios,
injeção de dependência, Bloc. Para este tamanho, isso adicionaria umas 15
pastas e mais código de encanamento do que de app.

O que foi feito é o meio-termo que resolve os problemas reais que o código
tinha (cores duplicadas, strings mágicas, estado de conexão mentiroso) sem
criar camadas que você teria que aprender antes de conseguir mudar a cor de
um botão.

**A telemetria testou essa aposta, e ela se sustentou.** Chegaram quatro telas
novas, uma segunda fonte de dados e um cache em disco — exatamente a lista do
"quando valeria a pena crescer" que estava escrita aqui. Ainda assim, o que foi
preciso foi um serviço a mais no mesmo formato do que já existia, e nenhum
gerenciador de estado: as telas continuam sendo `StatefulWidget` com
`setState`, e o `FutureBuilder` de `carregando.dart` cobre o resto.

O motivo é que **nenhum estado é compartilhado entre telas**. Cada aba pergunta
o que precisa e mostra; não há um "estado global do app" que duas telas
precisem enxergar igual. Provider ou Bloc resolvem esse problema — e é ele que
o app não tem.

**Quando valeria a pena crescer, agora:** se as telas passarem a depender umas
do estado das outras, se a telemetria precisar ser guardada offline para ser
lida sem rede, ou se aparecer atualização em tempo real (WebSocket) que várias
telas escutem ao mesmo tempo. Antes disso, não.

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

- ~~`applicationId` ainda é `com.example.robot_controller`~~ — resolvido: agora
  é `com.setrem.robot_controller`.
- ~~O APK de release é assinado com a chave de debug.~~ — resolvido: existe uma
  chave própria em `android/robot-release.jks`, espelhada no CI.
- ~~`flutter_bluetooth_serial` está sem manutenção desde 2021...~~ — resolvido:
  o projeto migrou de Bluetooth Classic (SPP) para BLE, usando
  `flutter_blue_plus`. Isso também foi o que permitiu suporte a iOS (o
  Bluetooth Classic nunca existiu lá). O firmware do ESP32 foi migrado junto
  — veja `esp32_ble_bridge.ino` no repositório `orquestrador`.
