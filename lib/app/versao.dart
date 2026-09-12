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

/// O que aparece no selo: só o número, e nada mais.
///
/// Sem o canal, sem separador, sem ornamento. Duas tentativas anteriores de
/// enfeitar isto — uma cápsula com borda, depois o canal antes do número — só
/// atrapalharam. É uma informação que se confere de vez em quando, não algo
/// que a tela precise anunciar.
String get kVersaoCurta => kAppVersao;
