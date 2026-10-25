import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pm_buques_supervisor/app.dart';
import 'package:pm_buques_supervisor/data/schema.dart';
import 'package:pm_buques_supervisor/data/supervisor_repository.dart';
import 'package:pm_buques_supervisor/ui/project_detail.dart';
import 'package:pm_buques_supervisor/ui/record_editor.dart';

class _UiRepository implements SupervisorRepository {
  int? selected;
  String? reviewedDecision, reviewedReason;
  String? savedTable;
  Map<String, Object?>? savedValues;
  bool ownsProject = false;
  final List<String> operationCalls = [];
  final Map<String, Object?> vessel = {
    'ID': 3, 'CallKey': 'DEMO-003', 'NombreBuque': 'Buque Demo 03', 'BuqueID': 1,
    'NombreServicio': 'Servicio Demo A', 'FechaETA': '2026-10-25',
    'EstadoProyecto': 'PendienteRevision', 'TitularNombre': null,
  };
  @override int? get actorId => selected;
  @override List<TableSpec> get tables => supervisorSchema;
  @override Future<void> selectOperator(int id) async { selected = id; }
  @override Future<List<Map<String, Object?>>> supervisors() async => [{'ID': 1, 'NombreMostrado': 'Supervisor Demo', 'UPN': 'SUPERVISOR_DEMO', 'Activo': 1, 'RolID': 1}];
  @override Future<List<Map<String, Object?>>> rows(String table, {int? scaleId}) async {
    if (table == 'PM_Usuarios') return supervisors();
    if (table == 'PM_Roles') return [{'ID': 1, 'NombreRol': 'Supervisor', 'CodigoRol': 'GERENCIA', 'Activo': 1}];
    if (table == 'PM_ControlEdicion') return [{'ID':1,'EstadoBloqueo':ownsProject ? 'Tomado' : 'Libre','TitularUsuarioID':ownsProject ? 1 : null}];
    if (table == 'PM_Buques') return [{'ID': 1, 'NombreBuque': 'Buque Demo 03', 'Activo': 1}];
    return [];
  }
  @override Future<List<Map<String, Object?>>> projects({String? status, String search = ''}) async => [vessel];
  @override Future<Map<String, Object?>> project(int id) async => vessel;
  @override Future<Map<String, int>> counts() async => {'PendienteRevision': 1};
  @override Future<List<Map<String, Object?>>> pendingTasks() async => [];
  @override Future<Map<String, Object?>> projectMetrics(int id) async => {'checklistDone': 1, 'checklistTotal': 1, 'movements': 100, 'planMovements': 100, 'productivity': 50.0, 'lostMinutes': 0};
  @override Future<List<String>> closeProblems(int id) async => [];
  @override Future<List<Map<String, Object?>>> audit({int? scaleId}) async => [];
  @override Future<List<Map<String, Object?>>> serviceReport() async => [];
  @override Future<List<Map<String, Object?>>> movementReport() async => [];
  @override Future<void> review(int scaleId, String decision, String reason) async { reviewedDecision = decision; reviewedReason = reason; vessel['EstadoProyecto'] = 'Cerrado'; }
  @override Future<void> start(int scaleId) async { ownsProject = true; vessel['EstadoProyecto'] = 'EnProceso'; operationCalls.add('start'); }
  @override Future<void> pause(int scaleId, String reason) async { ownsProject = false; vessel['EstadoProyecto'] = 'EnPausa'; operationCalls.add('pause'); }
  @override Future<void> freezePlan(int scaleId) async { operationCalls.add('freeze'); }
  @override Future<void> validateReports(int scaleId) async { operationCalls.add('reports'); }
  @override Future<void> finalizeHourly(int scaleId) async { operationCalls.add('hourly'); }
  @override Future<void> submitReview(int scaleId) async { ownsProject = false; vessel['EstadoProyecto'] = 'PendienteRevision'; operationCalls.add('submit'); }
  @override Future<int> save(String table, Map<String, Object?> values, {int? id, int? scaleId, String reason = ''}) async { savedTable = table; savedValues = Map<String, Object?>.from(values); return id ?? 42; }
  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('profile selection opens local supervisor dashboard', (tester) async {
    final repository = _UiRepository();
    await tester.pumpWidget(SupervisorApp(repository: repository));
    await tester.pumpAndSettle();
    expect(find.text('Supervisa cada\noperación.'), findsOneWidget);
    await tester.tap(find.text('Supervisor Demo'));
    await tester.pumpAndSettle();
    expect(repository.actorId, 1);
    expect(find.text('Tu operación, a la vista'), findsOneWidget);
    expect(find.text('Local'), findsOneWidget);
    expect(find.text('1 proyecto abierto'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow Android view navigates reports without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _UiRepository()..selected = 1;
    await tester.pumpWidget(SupervisorApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.bar_chart_outlined).last);
    await tester.pumpAndSettle();
    expect(find.text('Datos operativos e historial del supervisor.'), findsOneWidget);
    expect(find.text('Servicio'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new project form hides system fields and exposes required vessel', (tester) async {
    final repository = _UiRepository()..selected = 1;
    await tester.pumpWidget(SupervisorApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.directions_boat_outlined).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Nueva escala'));
    await tester.pumpAndSettle();
    expect(find.text('Código de visita *'), findsOneWidget);
    expect(find.text('Buque *'), findsOneWidget);
    expect(find.text('Estado Proyecto *'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('approval requires a reason before invoking repository', (tester) async {
    final repository = _UiRepository()..selected = 1;
    await tester.pumpWidget(MaterialApp(home: ProjectDetail(repository: repository, projectId: 3)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revisión'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aprobar y cerrar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Aprobar cierre'));
    await tester.pumpAndSettle();
    expect(find.text('Escribe un motivo para continuar'), findsOneWidget);
    expect(repository.reviewedDecision, isNull);
    await tester.enterText(find.byType(TextFormField).last, 'Documentación revisada');
    await tester.tap(find.widgetWithText(FilledButton, 'Aprobar cierre'));
    await tester.pumpAndSettle();
    expect(repository.reviewedDecision, 'APROBAR');
    expect(repository.reviewedReason, 'Documentación revisada');
    expect(tester.takeException(), isNull);
  });

  testWidgets('saving a changed editor closes the route and returns success', (tester) async {
    final repository = _UiRepository()..selected = 1;
    var saved = false;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(body: TextButton(
      onPressed: () async { saved = await editRecord(context, repository, 'PM_Buques'); },
      child: const Text('Abrir editor'),
    )))));
    await tester.tap(find.text('Abrir editor'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Buque de prueba');
    await tester.ensureVisible(find.text('Guardar cambios'));
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();
    expect(repository.savedTable, 'PM_Buques');
    expect(repository.savedValues?['NombreBuque'], 'Buque de prueba');
    expect(saved, isTrue);
    expect(find.text('Abrir editor'), findsOneWidget);
    expect(find.byType(RecordEditor), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('discarding edited data closes without saving', (tester) async {
    final repository = _UiRepository()..selected = 1;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(body: TextButton(
      onPressed: () => editRecord(context, repository, 'PM_Buques'),
      child: const Text('Abrir editor'),
    )))));
    await tester.tap(find.text('Abrir editor'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'No guardar');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('¿Descartar los cambios?'), findsOneWidget);
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(repository.savedTable, isNull);
    expect(find.byType(RecordEditor), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings explains local storage at narrow width without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(SupervisorApp(repository: _UiRepository()..selected = 1));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.tune_outlined).last);
    await tester.pumpAndSettle();
    expect(find.text('Datos locales en este teléfono'), findsOneWidget);
    expect(find.text('Exportar copia de datos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('negative integer input is rejected rather than silently made positive', (tester) async {
    final repository = _UiRepository()..selected = 1;
    await tester.pumpWidget(MaterialApp(home: RecordEditor(repository: repository, tableName: 'PM_VaciosDestino', scaleId: 3)));
    await tester.pumpAndSettle();
    final quantity = find.widgetWithText(TextFormField, 'Cantidad *');
    await tester.enterText(quantity, '-2');
    await tester.ensureVisible(find.text('Guardar cambios'));
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();
    expect(find.text('El valor no puede ser negativo'), findsOneWidget);
    expect(repository.savedTable, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a fresh local project exposes start and confirmed operational services', (tester) async {
    final repository = _UiRepository()..selected = 1;
    repository.vessel['EstadoProyecto'] = 'Pendiente';
    await tester.pumpWidget(MaterialApp(home: ProjectDetail(repository: repository, projectId: 3)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Tomar / iniciar operación'));
    await tester.tap(find.text('Tomar / iniciar operación'));
    await tester.pumpAndSettle();
    expect(repository.operationCalls, ['start']);
    expect(find.text('Pausa y entrega'), findsOneWidget);
    await tester.tap(find.text('Operación'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('1. Congelar estimado'));
    await tester.tap(find.text('1. Congelar estimado'));
    await tester.pumpAndSettle();
    expect(repository.operationCalls, ['start']);
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
    await tester.pumpAndSettle();
    expect(repository.operationCalls, ['start', 'freeze']);
    expect(tester.takeException(), isNull);
  });

}
