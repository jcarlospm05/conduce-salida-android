import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// La interfaz y el documento originales permanecen sin modificaciones.
/// SafeArea reserva las zonas del estado y navegación del sistema Android.
void main() => runApp(const ConduceDeSalidaApp());

class ConduceDeSalidaApp extends StatelessWidget {
  const ConduceDeSalidaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Conduce de Salida',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: false, scaffoldBackgroundColor: Colors.white),
      home: const ConduceOriginalScreen(),
    );
  }
}

class ConduceOriginalScreen extends StatelessWidget {
  const ConduceOriginalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF193B59);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: blue,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: const Scaffold(
        backgroundColor: blue,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          top: true,
          bottom: true,
          left: true,
          right: true,
          child: AndroidView(viewType: 'bobc.conduce.original'),
        ),
      ),
    );
  }
}
