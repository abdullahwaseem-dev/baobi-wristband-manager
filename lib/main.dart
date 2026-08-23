import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/app_theme.dart';
import 'screens/main_layout.dart';
import 'services/db_service.dart';
import 'services/settings_service.dart';
import 'state/app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!Platform.isAndroid && !Platform.isIOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await SettingsService.instance.init();
  await DbService.instance.init();

  if (Platform.isAndroid || Platform.isIOS) {
    await SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const BaobiApp(),
    ),
  );
}

class BaobiApp extends StatelessWidget {
  const BaobiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        return MaterialApp(
          title: 'Baobi Medical Wristband',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.theme,
          home: const MainLayout(),
        );
      },
    );
  }
}
