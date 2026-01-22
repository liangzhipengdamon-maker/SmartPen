import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/character_provider.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const SmartPenApp());
}

/// SmartPen 主应用
class SmartPenApp extends StatelessWidget {
  const SmartPenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CharacterProvider()),
        // 其他 providers 可以在这里添加
      ],
      child: MaterialApp(
        title: '智笔 - AI 书法教学',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          brightness: Brightness.light,
        ),
        darkTheme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          brightness: Brightness.dark,
        ),
        home: const HomeScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
