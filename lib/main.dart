import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/theme.dart';
import 'screens/connect_screen.dart';

/// PONTO DE ENTRADA DO APP.
///
/// Este arquivo e de proposito o menor de todos: ele so liga o app. Toda a
/// aparencia esta em `app/theme.dart` e todo o comportamento esta nas telas
/// dentro de `screens/`. Veja o ARQUITETURA.md para o mapa completo.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // O controle so faz sentido em pe (retrato). Sem o `await` o app podia
  // abrir deitado por um instante antes de girar.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(const RobotControllerApp());
}

class RobotControllerApp extends StatelessWidget {
  const RobotControllerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Atlas Controller',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const ConnectScreen(),
    );
  }
}
