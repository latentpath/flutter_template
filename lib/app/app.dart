import 'package:flutter/material.dart';

class TemplateApp extends StatelessWidget {
  const TemplateApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Flutter Template',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
    ),
    home: const Scaffold(body: Center(child: Text('Flutter Template'))),
  );
}
