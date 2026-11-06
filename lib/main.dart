import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home_screen.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);
  runApp(const TrangNguyenApp());
}

class TrangNguyenApp extends StatelessWidget {
  const TrangNguyenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Đường Tới Trạng Nguyên',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const HomeScreen(),
    );
  }
}
