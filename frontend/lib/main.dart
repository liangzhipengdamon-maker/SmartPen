import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'providers/character_provider.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 请求摄像头权限
  await _requestCameraPermission();

  runApp(const SmartPenApp());
}

/// 请求摄像头权限
Future<void> _requestCameraPermission() async {
  final status = await Permission.camera.request();
  if (status.isDenied) {
    // 权限被拒绝，可以显示提示
    debugPrint('Camera permission denied');
  } else if (status.isPermanentlyDenied) {
    // 权限被永久拒绝，引导用户到设置
    debugPrint('Camera permission permanently denied');
    await openAppSettings();
  }
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
