import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/theme.dart';
import 'screens/connect_screen.dart';

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
      home: const ConnectScreen(),
    );
  }
}
