import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/theme.dart';
import 'screens/connectScreen.dart';
import 'widgets/seloVersao.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Sem o `await`, o app podia abrir deitado um instante antes de girar.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(const RobotControllerApp());
}

class RobotControllerApp extends StatelessWidget {
  const RobotControllerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Atlas Controller v2',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      // O selo precisa da chave para abrir a ficha do build: ele fica ao lado
      // do Navigator, não dentro, e sem a chave não teria por onde abrir nada.
      navigatorKey: SeloVersao.navegador,
      // O selo de versão fica sobre tudo, montado uma vez aqui: some no dia
      // em que `kAppCanal` deixar de ser 'dev', sem tocar tela nenhuma.
      builder: (context, child) => SeloVersao(child: child ?? const SizedBox()),
      home: const ConnectScreen(),
    );
  }
}
