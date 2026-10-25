import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'data/supervisor_repository.dart';
import 'ui/common.dart';
import 'ui/pages.dart';

class SupervisorApp extends StatefulWidget {
  const SupervisorApp({required this.repository, super.key});
  final SupervisorRepository repository;
  @override State<SupervisorApp> createState() => _SupervisorAppState();
}
class _SupervisorAppState extends State<SupervisorApp> {
  late bool _selecting;
  @override void initState() { super.initState(); _selecting = widget.repository.actorId == null; }
  @override Widget build(BuildContext context) => MaterialApp(
    title: 'Faro · Supervisor Portuario', debugShowCheckedModeBanner: false,
    locale: const Locale('es'), supportedLocales: const [Locale('es')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: teal, brightness: Brightness.light, surface: Colors.white),
      scaffoldBackgroundColor: canvas,
      textTheme: const TextTheme(bodyMedium: TextStyle(color: ink), bodyLarge: TextStyle(color: ink), titleMedium: TextStyle(color: ink), titleLarge: TextStyle(color: ink), headlineSmall: TextStyle(color: ink)),
      appBarTheme: const AppBarTheme(backgroundColor: ink, foregroundColor: Colors.white, elevation: 0, scrolledUnderElevation: 0, titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
      tabBarTheme: const TabBarThemeData(labelColor: Colors.white, unselectedLabelColor: Color(0xffb9cedb), indicatorColor: Color(0xff6fe0ce), dividerColor: Color(0xff365064)),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xffdce5eb))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xffdce5eb))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: teal, width: 2)),
        labelStyle: const TextStyle(color: muted),
      ),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(backgroundColor: teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)))),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(foregroundColor: teal, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)))),
      navigationBarTheme: NavigationBarThemeData(backgroundColor: Colors.white, indicatorColor: teal.withValues(alpha: .12), labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500, fontSize: 11, color: states.contains(WidgetState.selected) ? teal : muted))),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      dividerColor: const Color(0xffe4eaef),
      visualDensity: VisualDensity.standard,
    ),
    home: _selecting
      ? _ProfilePicker(repository: widget.repository, onSelected: () => setState(() => _selecting = false), onCancel: widget.repository.actorId == null ? null : () => setState(() => _selecting = false))
      : _SupervisorShell(repository: widget.repository, switchProfile: () => setState(() => _selecting = true)),
  );
}

class _ProfilePicker extends StatefulWidget {
  const _ProfilePicker({required this.repository, required this.onSelected, this.onCancel});
  final SupervisorRepository repository;
  final VoidCallback onSelected;
  final VoidCallback? onCancel;
  @override State<_ProfilePicker> createState() => _ProfilePickerState();
}
class _ProfilePickerState extends State<_ProfilePicker> {
  bool _busy = false;
  Future<void> _select(RowData row) async {
    setState(() => _busy = true);
    try { await widget.repository.selectOperator(intValue(row['ID'])); if (mounted) widget.onSelected(); }
    catch (error) { if (mounted) { setState(() => _busy = false); notify(context, readableError(error), error: true); } }
  }
  @override Widget build(BuildContext context) => Scaffold(body: SafeArea(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 620), child: ListView(padding: const EdgeInsets.fromLTRB(26, 45, 26, 30), children: [
    Align(alignment: Alignment.centerLeft, child: Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(22)), child: const Icon(Icons.light_outlined, color: Color(0xff6fe0ce), size: 36))),
    const SizedBox(height: 25), const Text('FARO', style: TextStyle(letterSpacing: 3, fontWeight: FontWeight.w800, color: teal, fontSize: 12)),
    const SizedBox(height: 12), const Text('Supervisa cada\noperación.', style: TextStyle(color: ink, fontSize: 38, height: 1.15, letterSpacing: -1.4, fontWeight: FontWeight.w800)),
    const SizedBox(height: 18), const Text('Elige el responsable que quedará registrado en las decisiones de este teléfono.', style: TextStyle(color: muted, fontSize: 16, height: 1.5)),
    const SizedBox(height: 28), const Text('RESPONSABLE', style: TextStyle(color: muted, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 1.5)), const SizedBox(height: 10),
    AsyncData<List<RowData>>(load: widget.repository.supervisors, builder: (context, users) => users.isEmpty
      ? const EmptyState('No hay supervisores activos', 'Se necesita un perfil de Gerencia habilitado para abrir esta aplicación.', icon: Icons.person_off_outlined)
      : Column(children: users.map((u) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Material(color: Colors.white, borderRadius: BorderRadius.circular(17), child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        leading: CircleAvatar(backgroundColor: teal.withValues(alpha: .10), child: const Icon(Icons.person_outline, color: teal)),
        title: Text(text(u['NombreMostrado']), style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: const Text('Supervisor · Gerencia'),
        trailing: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.arrow_forward, color: teal),
        onTap: _busy ? null : () => _select(u),
      )))).toList())),
    const SizedBox(height: 24), const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.info_outline, size: 18, color: muted), SizedBox(width: 9), Expanded(child: Text('Perfil configurado, sin verificación de identidad. Esta prueba conserva los datos localmente en el dispositivo.', style: TextStyle(color: muted, fontSize: 12, height: 1.6)))]),
    if (widget.onCancel != null) Padding(padding: const EdgeInsets.only(top: 15), child: TextButton(onPressed: _busy ? null : widget.onCancel, child: const Text('Continuar con el responsable actual'))),
  ])))));
}

class _SupervisorShell extends StatefulWidget {
  const _SupervisorShell({required this.repository, required this.switchProfile});
  final SupervisorRepository repository;
  final VoidCallback switchProfile;
  @override State<_SupervisorShell> createState() => _SupervisorShellState();
}
class _SupervisorShellState extends State<_SupervisorShell> {
  int _index = 0, _revision = 0, _filterRevision = 0;
  String? _projectStatus;
  void _openProjects(String? status) => setState(() { _projectStatus = status; _filterRevision++; _index = 1; });
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Row(children: [Icon(Icons.light_outlined, size: 23, color: Color(0xff6fe0ce)), SizedBox(width: 10), Expanded(child: Text('Faro', overflow: TextOverflow.ellipsis))]), actions: [Padding(padding: const EdgeInsets.only(right: 16), child: Semantics(label: 'Datos almacenados en este teléfono', child: const Chip(side: BorderSide.none, backgroundColor: Color(0xff2a4355), label: Text('Local', style: TextStyle(color: Color(0xffd6e8ef), fontSize: 11)), avatar: Icon(Icons.phone_android, size: 15, color: Color(0xffb9cedb)))))]),
    body: SafeArea(top: false, child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 900), child: IndexedStack(index: _index, children: [
      DashboardPage(key: ValueKey('dashboard-$_revision'), repository: widget.repository, openProjects: _openProjects, onChanged: () {}),
      ProjectsPage(repository: widget.repository, initialStatus: _projectStatus, filterVersion: _filterRevision, revision: _revision),
      TeamPage(repository: widget.repository, revision: _revision), ReportsPage(repository: widget.repository, revision: _revision), SettingsPage(repository: widget.repository, switchProfile: widget.switchProfile),
    ])))),
    bottomNavigationBar: NavigationBar(selectedIndex: _index, onDestinationSelected: (v) => setState(() { _index = v; _revision++; }), destinations: const [
      NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Inicio'),
      NavigationDestination(icon: Icon(Icons.directions_boat_outlined), selectedIcon: Icon(Icons.directions_boat), label: 'Proyectos'),
      NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Equipo'),
      NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Informes'),
      NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune), label: 'Ajustes'),
    ]),
  );
}
