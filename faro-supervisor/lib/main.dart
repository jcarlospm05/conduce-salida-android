import 'package:flutter/material.dart';

import 'app.dart';
import 'data/supervisor_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _OpenLocalApp());
}

class _OpenLocalApp extends StatefulWidget {
  const _OpenLocalApp();

  @override
  State<_OpenLocalApp> createState() => _OpenLocalAppState();
}

class _OpenLocalAppState extends State<_OpenLocalApp> {
  late Future<SupervisorRepository> _opening;
  SupervisorRepository? _repository;

  @override
  void initState() {
    super.initState();
    _opening = _open();
  }

  Future<SupervisorRepository> _open() async {
    final repository = await SupervisorRepository.open();
    _repository = repository;
    return repository;
  }

  @override
  void dispose() {
    _repository?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<SupervisorRepository>(
        future: _opening,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return SupervisorApp(repository: snapshot.data!);
          }
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Faro · Supervisor Portuario',
            theme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: const Color(0xff087f72),
            ),
            home: Scaffold(
              backgroundColor: const Color(0xfff4f7fa),
              body: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: snapshot.hasError
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.storage_outlined,
                                  size: 48, color: Color(0xff123047)),
                              const SizedBox(height: 18),
                              const Text('No se pudo abrir la base local',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 12),
                              const Text(
                                'Comprueba que el teléfono tenga espacio disponible. '
                                'Tus datos no se borrarán al reintentar.',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 22),
                              FilledButton.icon(
                                onPressed: () => setState(() {
                                  _opening = _open();
                                }),
                                icon: const Icon(Icons.refresh),
                                label: const Text('Volver a intentar'),
                              ),
                            ],
                          )
                        : const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 20),
                              Text('Abriendo tus datos locales…'),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          );
        },
      );
}
