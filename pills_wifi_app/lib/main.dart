import 'package:flutter/material.dart';
import 'ui/controller_screen.dart';
import 'services/pills_connection_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await PillsConnectionService().init();
  } catch (e) {
    debugPrint('❌TCP connection init failed: $e');
  }

  runApp(const PillsWifiApp());
}

class PillsWifiApp extends StatelessWidget {
  const PillsWifiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const ControllerScreen(),
    );
  }
}
