import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/theme.dart';
import 'screens/connect_screen.dart';
import 'widgets/selo_versao.dart';

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
      // O selo de versão fica sobre tudo, montado uma vez aqui: some no dia
      // em que `kAppCanal` deixar de ser 'dev', sem tocar tela nenhuma.
      builder: (context, child) => SeloVersao(child: child ?? const SizedBox()),
      home: const ConnectScreen(),
    );
  }
}
