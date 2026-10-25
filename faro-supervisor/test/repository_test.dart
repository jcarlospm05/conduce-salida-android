import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pm_buques_supervisor/data/supervisor_repository.dart';
import 'package:pm_buques_supervisor/domain/domain_exception.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late SupervisorRepository repo;

  setUp(() async {
    repo = await SupervisorRepository.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    await repo.selectOperator(1);
  });
  tearDown(() async => repo.close());

  test('fresh install asks for a profile and persists only an explicit selection', () async {
    final dir = await Directory.systemTemp.createTemp('pm-supervisor-profile-');
    final path = '${dir.path}/profile.db';
    var local = await SupervisorRepository.open(factory: databaseFactoryFfi, path: path);
    try {
      expect(local.actorId, isNull);
      await expectLater(local.save('PM_Buques', {'NombreBuque': 'Sin perfil', 'Activo': 1}), throwsA(isA<DomainException>()));
      await local.selectOperator(1);
      await local.close();
      local = await SupervisorRepository.open(factory: databaseFactoryFfi, path: path);
      expect(local.actorId, 1);
    } finally {
      await local.close();
      await dir.delete(recursive: true);
    }
  });

  test('impossible calendar dates and overflowed times are rejected without writes', () async {
    final before = (await repo.audit()).length;
    await expectLater(repo.save('PM_Escalas', {'CallKey': 'BAD-DATE', 'BuqueID': 1, 'FechaETA': '2026-02-30'}), throwsA(isA<DomainException>()));
    await expectLater(repo.save('PM_Escalas', {'CallKey': 'BAD-TIME', 'BuqueID': 1, 'FechaETA': '2026-02-20', 'ETACompletaUTC': '2026-02-20T25:00:00Z'}), throwsA(isA<DomainException>()));
    expect((await repo.audit()).length, before);
  });

  test('new project completes the operational lifecycle without seeded closing records', () async {
    final id = await repo.save('PM_Escalas', {'CallKey': 'LOCAL-COMPLETE', 'BuqueID': 1, 'FechaETA': '2026-10-25', 'InicioRealUTC': '2026-10-25T12:00:00Z', 'FinRealUTC': '2026-10-25T13:00:00Z'});
    expect((await repo.rows('PM_HitosBuque', scaleId: id)).length, 15);
    expect((await repo.rows('PM_ReportesMaritimos', scaleId: id)).length, 2);
    await repo.start(id);
    final plan = (await repo.rows('PM_Estimados', scaleId: id)).single;
    await repo.save('PM_Estimados', {'ImpFull': 2, 'ExpFull': 3, 'CuadrillasPrevistas': 1, 'ProductividadMeta': 5, 'InicioPrevistoUTC': '2026-10-25T12:00:00Z'}, id: plan['ID'] as int);
    final gang = await repo.save('PM_EstimadoGang', {'CodigoGang': 'Cuadrilla local', 'MovimientosAsignados': 5}, scaleId: id);
    await repo.freezePlan(id);
    await expectLater(repo.freezePlan(id), throwsA(isA<DomainException>()));
    final hourly = await repo.save('PM_Hourly', {'HoraInicioUTC': '2026-10-25T12:00:00Z', 'HoraFinUTC': '2026-10-25T13:00:00Z', 'MovImp': 2, 'ExpFull': 3}, scaleId: id);
    await repo.save('PM_HourlyGang', {'HourlyID': hourly, 'GangID': gang, 'MovimientosHora': 5});
    await repo.finalizeHourly(id);
    for (final task in await repo.rows('PM_TareasProyecto', scaleId: id)) {
      await repo.save('PM_TareasProyecto', {'EstadoTarea': 'Completada'}, id: task['ID'] as int);
    }
    final types = await repo.rows('PM_TiposHito');
    final byId = {for (final t in types) t['ID']: t};
    for (final hit in await repo.rows('PM_HitosBuque', scaleId: id)) {
      final type = byId[hit['TipoHitoID']]!;
      final order = type['Orden'] as int;
      final stamp = DateTime.utc(2026, 10, 25, 10).add(Duration(minutes: order * 10));
      await repo.save('PM_HitosBuque', {'FechaHoraUTC': stamp.toIso8601String()}, id: hit['ID'] as int);
    }
    await repo.validateReports(id);
    expect(await repo.closeProblems(id), isEmpty);
    await repo.submitReview(id);
    expect((await repo.project(id))['EstadoProyecto'], 'PendienteRevision');
    expect((await repo.rows('PM_SesionesTrabajo', scaleId: id)).single['FinTipo'], 'TERMINAR');
    await repo.review(id, 'APROBAR', 'Revisión completa del proyecto local.');
    expect((await repo.project(id))['EstadoProyecto'], 'Cerrado');
  });

  test('local start pause and ownership are persisted and do not create duplicate sessions', () async {
    await repo.start(1);
    await expectLater(repo.start(1), throwsA(isA<DomainException>()));
    await expectLater(repo.pause(1, ''), throwsA(isA<DomainException>()));
    await repo.pause(1, 'Entrega de prueba');
    expect((await repo.project(1))['EstadoProyecto'], 'EnPausa');
    expect((await repo.rows('PM_ControlEdicion', scaleId: 1)).single['EstadoBloqueo'], 'Libre');
    await repo.start(1);
    expect((await repo.rows('PM_SesionesTrabajo', scaleId: 1)).where((s) => s['FinUTC'] == null).length, 1);
    expect((await repo.rows('PM_Relevos', scaleId: 1)).single['TomaUTC'], isNotNull);
  });

  test('operation editing requires local ownership but supervisor instruction does not', () async {
    await expectLater(repo.save('PM_VaciosDestino', {'PuertoDestino': 'Puerto Demo', 'Cantidad': 1}, scaleId: 2), throwsA(isA<DomainException>()));
    await repo.addInstruction(2, 'Instrucción durante ocupación de otro operador');
    expect((await repo.rows('PM_TareasProyecto', scaleId: 2)).any((t) => t['TextoTarea'] == 'Instrucción durante ocupación de otro operador'), isTrue);
  });

  test('canonical schema persists 36 tables and 323 typed fields', () async {
    expect(repo.tables.length,36);
    expect(repo.tables.fold<int>(0,(n,t)=>n+t.fields.length),323);
    for (final table in repo.tables) {
      expect(await repo.rows(table.name),isA<List<Map<String,Object?>>>());
    }
    expect((await repo.projects()).length,3);
    expect(repo.actorId,1);
  });

  test('complete demonstration scale can be approved and reports use real moves', () async {
    expect(await repo.closeProblems(3),isEmpty);
    await repo.review(3,'APROBAR','Información comprobada en demostración.');
    expect((await repo.project(3))['EstadoProyecto'],'Cerrado');
    expect((await repo.rows('PM_Revisiones',scaleId:3)).single['Decision'],'APROBAR');
    final report=await repo.movementReport();
    expect(report.single['MovImp'],100);
    expect(report.single['ExpFull'],100);
    final services=await repo.serviceReport();
    expect(services.single['ProductividadPonderada'],200);
  });

  test('new mandatory instruction blocks approval and leaves no partial review', () async {
    await repo.addInstruction(3,'Revisar la instrucción agregada antes del cierre.');
    final reviewsBefore=(await repo.rows('PM_Revisiones')).length;
    final eventsBefore=(await repo.audit()).length;
    await expectLater(repo.review(3,'APROBAR','Intento de cierre'),throwsA(isA<DomainException>()));
    expect((await repo.project(3))['EstadoProyecto'],'PendienteRevision');
    expect((await repo.rows('PM_Revisiones')).length,reviewsBefore);
    expect((await repo.audit()).length,eventsBefore);
  });

  test('concurrent approval requests produce one review, not two', () async {
    var successes=0;var failures=0;
    Future<void> approve() async {
      try {await repo.review(3,'APROBAR','Revisión concurrente local');successes++;}
      on DomainException {failures++;}
    }
    await Future.wait([approve(),approve()]);
    expect(successes,1);expect(failures,1);
    expect((await repo.rows('PM_Revisiones',scaleId:3)).length,1);
  });

  test('return and reopening add mandatory work while preserving past closure facts', () async {
    await repo.review(3,'DEVOLVER','Falta revisar una observación.');
    expect((await repo.project(3))['EstadoProyecto'],'Devuelto');
    expect((await repo.rows('PM_TareasProyecto',scaleId:3)).any((t)=>t['EstadoTarea']=='Pendiente' && t['Obligatoria']==1),isTrue);
    expect((await repo.rows('PM_CierreHourly',scaleId:3)).single['Finalizado'],0);
  });

  test('reopening keeps original approved timestamp and adds a second review', () async {
    await repo.review(3,'APROBAR','Todo correcto.');
    final date=(await repo.project(3))['FechaCierreUTC'];
    await repo.review(3,'REABRIR','Corrección posterior documentada.');
    expect((await repo.project(3))['EstadoProyecto'],'Devuelto');
    expect((await repo.project(3))['FechaCierreUTC'],date);
    expect((await repo.rows('PM_Revisiones',scaleId:3)).length,2);
  });

  test('assignment supersedes previous active assignment transactionally', () async {
    await repo.assign(1,3);
    final assignments=await repo.rows('PM_Asignaciones',scaleId:1);
    expect(assignments.where((a)=>a['Vigente']==1).single['UsuarioID'],3);
    expect(assignments.where((a)=>a['Vigente']==0).length,1);
    expect((await repo.project(1))['AuditorAsignado'],'Auditor Demo 02');
  });

  test('inactive auditor cannot be assigned and previous assignment remains', () async {
    await repo.save('PM_Usuarios',{'Activo':0},id:3);
    await expectLater(repo.assign(1,3),throwsA(isA<DomainException>()));
    expect((await repo.rows('PM_Asignaciones',scaleId:1)).where((a)=>a['Vigente']==1).single['UsuarioID'],2);
  });

  test('release closes active session, frees control, records reason and handover', () async {
    await expectLater(repo.release(2,''),throwsA(isA<DomainException>()));
    await repo.release(2,'Equipo no disponible; entrega supervisada.');
    expect((await repo.project(2))['EstadoProyecto'],'EnPausa');
    final control=(await repo.rows('PM_ControlEdicion',scaleId:2)).single;
    expect(control['EstadoBloqueo'],'Libre');expect(control['TitularUsuarioID'],isNull);
    expect((await repo.rows('PM_SesionesTrabajo',scaleId:2)).single['FinUTC'],isNotNull);
    expect((await repo.rows('PM_Relevos',scaleId:2)).length,1);
  });

  test('scale creation initializes related records and ETA changes need history reason', () async {
    final id=await repo.save('PM_Escalas',{'CallKey':'PRUEBA-NEW','BuqueID':1,'FechaETA':'2026-10-26'});
    expect((await repo.rows('PM_ControlEdicion',scaleId:id)).single['EstadoBloqueo'],'Libre');
    expect((await repo.rows('PM_Estimados',scaleId:id)).length,1);
    expect((await repo.rows('PM_TareasProyecto',scaleId:id)).length,1);
    await expectLater(repo.save('PM_Escalas',{'FechaETA':'2026-10-27'},id:id),throwsA(isA<DomainException>()));
    await repo.save('PM_Escalas',{'FechaETA':'2026-10-27'},id:id,reason:'Nueva previsión.');
    final history=(await repo.rows('PM_ETA_Historial',scaleId:id)).single;
    expect(history['AnteriorFechaETA'],'2026-10-26');expect(history['NuevaFechaETA'],'2026-10-27');
  });

  test('invalid FK and duplicate call do not create orphan records or audit entries', () async {
    final initial=(await repo.audit()).length;
    await expectLater(repo.save('PM_Escalas',{'CallKey':'BAD','BuqueID':999,'FechaETA':'2026-10-26'}),throwsA(isA<DomainException>()));
    await expectLater(repo.save('PM_Escalas',{'CallKey':'DEMO-001','BuqueID':1,'FechaETA':'2026-10-26'}),throwsA(isA<DomainException>()));
    expect((await repo.projects()).length,3);
    expect((await repo.audit()).length,initial);
  });

  test('managed states cannot bypass review and frozen plans stay immutable', () async {
    await expectLater(repo.save('PM_Escalas',{'EstadoProyecto':'Cerrado'},id:2),throwsA(isA<DomainException>()));
    await expectLater(repo.save('PM_Eventos',{'Resultado':'BORRAR'}),throwsA(isA<DomainException>()));
    await expectLater(repo.save('PM_Estimados',{'ImpFull':999},id:2),throwsA(isA<DomainException>()));
    expect((await repo.rows('PM_Estimados',scaleId:2)).single['ImpFull'],100);
  });

  test('operator selection is limited to active supervisor profiles', () async {
    await expectLater(repo.selectOperator(2),throwsA(isA<DomainException>()));
    expect(repo.actorId,1);
    await expectLater(repo.save('PM_Usuarios',{'Activo':0},id:1),throwsA(isA<DomainException>()));
    await repo.selectOperator(1);
    expect(repo.actorId,1);
  });

  test('invalid fractional counts and query metacharacters are handled safely', () async {
    await expectLater(repo.save('PM_VaciosDestino',{'PuertoDestino':'Puerto Demo','Cantidad':1.5},scaleId:2),throwsA(isA<DomainException>()));
    expect(await repo.projects(search:"' OR 1=1 --"),isEmpty);
    expect((await repo.projects(search:'Demo')).length,3);
    expect(await repo.projects(search:'%'),isEmpty);
  });

  test('export is explicit and carries offline attribution without credential table', () async {
    final decoded=jsonDecode(await repo.exportJson()) as Map<String,dynamic>;
    expect(decoded['sincronizacion'],false);
    final data=decoded['datos'] as Map<String,dynamic>;
    expect(data.containsKey('PM_Credenciales'),false);
    expect(data['PM_Escalas'],hasLength(3));
  });
  test('local role permission can deny review without changing the project', () async {
    await repo.save('PM_PermisosRol', {'RolID':1,'CodigoPermiso':'REVISAR_CIERRE','Habilitado':0});
    await expectLater(repo.review(3,'APROBAR','Comprobado'),throwsA(isA<DomainException>()));
    expect((await repo.project(3))['EstadoProyecto'],'PendienteRevision');
    expect(await repo.rows('PM_Revisiones'),isEmpty);
    await expectLater(repo.save('PM_PermisosRol', {'RolID':1,'CodigoPermiso':'ADMINISTRAR','Habilitado':0}),throwsA(isA<DomainException>()));
  });

}
