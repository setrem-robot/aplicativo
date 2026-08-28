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

const String kAppVersao = '1.1.4+6';

/// Canal do build. `dev` enquanto o app está em desenvolvimento — é o que
/// justifica o selo de versão à vista. Vira `estável` (ou some) quando for para
/// as mãos de quem só usa.
const String kAppCanal = 'dev';

/// O rótulo montado, como aparece no selo: `dev · 1.1.4`.
///
/// Sem o `+build` de propósito: o número depois do `+` só interessa para
/// instalar por cima na loja, e polui um selo que é para ser lido de relance.
String get kVersaoCurta {
  final semBuild = kAppVersao.split('+').first;
  return '$kAppCanal · $semBuild';
}
