/// Texto de reserva para a versão do app.
///
/// A versão de verdade agora vem do `package_info_plus`, lida da plataforma
/// pelo [AtualizacaoService] — o `SeloVersao` usa aquela e cai para esta só se
/// a leitura falhar. Antes esta constante era a fonte única, e o problema
/// apareceu na prática: ela ficou em `1.2.1+8` enquanto o release já era
/// `1.2.2+9`, e o selo passou a mentir. Mantê-la só como reserva evita isso.
///
/// Ao publicar um release novo, mantenha este número alinhado ao `version:` do
/// pubspec.yaml — ele só aparece se o plugin nativo não responder.
library;

const String kAppVersao = '1.2.3+10';

/// Canal do build. `dev` enquanto o app está em desenvolvimento — é o que
/// justifica o selo de versão à vista. Vira `estável` (ou some) quando for para
/// as mãos de quem só usa.
const String kAppCanal = 'dev';

/// O texto de reserva do selo: só o número.
///
/// O canal não entra no texto de propósito — duas tentativas anteriores de
/// pôr o canal antes do número só atrapalharam. Hoje o selo é uma pílula com
/// um ponto de estado na frente (`seloVersao.dart`), e o canal aparece na
/// ficha que abre ao tocar nela, junto com o build e o patch.
String get kVersaoCurta => kAppVersao;
