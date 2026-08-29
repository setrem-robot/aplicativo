/// Versão do app, para mostrar na tela.
///
/// Uma constante Dart, e não `package_info_plus`: ler a versão do pacote em
/// tempo de execução exige um plugin nativo, e plugin nativo é justamente o que
/// o Shorebird **não** consegue entregar por patch. Como um selo de versão num
/// build de desenvolvimento é a coisa que mais muda a cada entrega, ele precisa
/// viajar dentro do patch — então mora aqui, no Dart, e sobe junto com o resto.
///
/// Ao publicar um release novo (subir o `version:` do pubspec.yaml), **mude
/// este número junto**. Num patch, basta mudar aqui.
library;

const String kAppVersao = '1.2.1+8';

/// Canal do build. `dev` enquanto o app está em desenvolvimento — é o que
/// justifica o selo de versão à vista. Vira `estável` (ou some) quando for para
/// as mãos de quem só usa.
const String kAppCanal = 'dev';

/// O que aparece no selo: só o número, e nada mais.
///
/// Sem o canal, sem separador, sem ornamento. Duas tentativas anteriores de
/// enfeitar isto — uma cápsula com borda, depois o canal antes do número — só
/// atrapalharam. É uma informação que se confere de vez em quando, não algo
/// que a tela precise anunciar.
String get kVersaoCurta => kAppVersao;
