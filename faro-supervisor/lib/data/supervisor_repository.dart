import 'dart:convert';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../domain/domain_exception.dart';
import 'schema.dart';

/// Offline SQL repository. An operator profile is attribution, not authentication.
/// Every business write and its audit record share a single SQLite transaction.
class SupervisorRepository {
  final Database _db;
  int? _actorId;
  SupervisorRepository._(this._db);

  List<TableSpec> get tables => supervisorSchema;
  int? get actorId => _actorId;

  static Future<SupervisorRepository> open({
    DatabaseFactory? factory,
    String? path,
    bool seedDemo = true,
  }) async {
    final dbFactory = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await dbFactory.getDatabasesPath(), 'pm_supervisor_v1.db');
    final db = await dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
          await db.execute('PRAGMA busy_timeout = 5000');
        },
        onCreate: (db, version) async {
          for (final sql in createSchemaStatements()) {
            await db.execute(sql);
          }
          if (seedDemo) await _seed(db);
        },
      ),
    );
    final repo = SupervisorRepository._(db);
    final settings = await db.query('local_settings', where: 'key = ?', whereArgs: ['operator_id']);
    if (settings.isNotEmpty) {
      repo._actorId = int.tryParse(settings.first['value'] as String);
      try {
        await repo._requireSupervisor(db);
      } on DomainException {
        repo._actorId = null;
      }
    }
    return repo;
  }

  TableSpec _table(String name) => tables.firstWhere(
    (table) => table.name == name,
    orElse: () => throw const DomainException('La tabla no pertenece al proyecto.'),
  );

  static String _now() => DateTime.now().toUtc().toIso8601String();
  static String _token() {
    final random = Random.secure();
    return List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  static const permissionCodes = <String, String>{
    'ADMINISTRAR': 'Administrar operadores, roles e instalaciones',
    'ITINERARIO': 'Crear y modificar visitas',
    'ASIGNAR_AUDITOR': 'Asignar auditores',
    'AGREGAR_INSTRUCCION': 'Crear y modificar tareas e instrucciones',
    'REVISAR_CIERRE': 'Aprobar, devolver y reabrir proyectos',
    'LIBERAR_OCUPACION': 'Liberar una ocupación',
    'EVALUAR': 'Evaluar auditores',
    'AJUSTAR_PLAN': 'Editar planes todavía no congelados',
    'EDITAR_OPERACION': 'Modificar registros operativos',
    'EXPORTAR': 'Exportar copia de los datos',
  };

  static String _tableCapability(String table) {
    if (['PM_Roles','PM_Usuarios','PM_Equipos','PM_PermisosRol'].contains(table)) return 'ADMINISTRAR';
    if (table == 'PM_Escalas') return 'ITINERARIO';
    if (table == 'PM_Asignaciones') return 'ASIGNAR_AUDITOR';
    if (table == 'PM_TareasProyecto') return 'AGREGAR_INSTRUCCION';
    if (table == 'PM_Evaluaciones') return 'EVALUAR';
    if (['PM_Estimados','PM_EstimadoGang','PM_EstimadoGangDetalle'].contains(table)) return 'AJUSTAR_PLAN';
    return 'EDITAR_OPERACION';
  }

  Future<void> _requireSupervisor(DatabaseExecutor tx, {String? capability, int? operatorId}) async {
    final actor = operatorId ?? _actorId;
    if (actor == null) throw const DomainException('Selecciona un supervisor para continuar.');
    final users = await tx.rawQuery('''
SELECT U.ID,U.RolID FROM PM_Usuarios U JOIN PM_Roles R ON U.RolID=R.ID
WHERE U.ID=? AND U.Activo=1 AND R.Activo=1 AND R.CodigoRol='GERENCIA'
''', [actor]);
    if (users.isEmpty) throw const DomainException('El perfil ya no está activo o no pertenece a Gerencia.');
    if (capability != null) {
      final rules = await tx.query('PM_PermisosRol', where: 'RolID=? AND CodigoPermiso=?', whereArgs: [users.first['RolID'], capability], orderBy: 'ID DESC', limit: 1);
      if (rules.isNotEmpty && rules.first['Habilitado'] != 1) throw DomainException('Tu rol no tiene permiso: ${permissionCodes[capability] ?? capability}.');
    }
  }

  Future<List<Map<String, Object?>>> supervisors() => _db.rawQuery('''
SELECT U.* FROM PM_Usuarios U JOIN PM_Roles R ON U.RolID=R.ID
WHERE U.Activo=1 AND R.Activo=1 AND R.CodigoRol='GERENCIA' ORDER BY U.NombreMostrado
''');

  Future<void> selectOperator(int id) async {
    await _db.transaction((tx) async {
      // Validate and persist first. Only publish the new profile after commit.
      await _requireSupervisor(tx, operatorId: id);
      await tx.insert('local_settings', {'key': 'operator_id', 'value': '$id'}, conflictAlgorithm: ConflictAlgorithm.replace);
      await _audit(tx, 'PERFIL_SELECCIONADO', 'PM_Usuarios', id, null, {'ID': id}, null, actorOverride: id);
    });
    _actorId = id;
  }

  Future<List<Map<String, Object?>>> rows(String table, {int? scaleId}) async {
    _table(table);
    if (scaleId == null) return _db.query(table, orderBy: 'ID DESC');
    if (_table(table).fields.any((f) => f.name == 'EscalaID')) {
      return _db.query(table, where: 'EscalaID=?', whereArgs: [scaleId], orderBy: 'ID DESC');
    }
    if (table == 'PM_Escalas') return _db.query(table, where: 'ID=?', whereArgs: [scaleId]);
    if (table == 'PM_HourlyGang') {
      return _db.rawQuery('SELECT G.* FROM PM_HourlyGang G JOIN PM_Hourly H ON G.HourlyID=H.ID WHERE H.EscalaID=? ORDER BY G.ID DESC', [scaleId]);
    }
    if (table == 'PM_EstimadoGangDetalle') {
      return _db.rawQuery('SELECT D.* FROM PM_EstimadoGangDetalle D JOIN PM_EstimadoGang G ON D.GangID=G.ID WHERE G.EscalaID=? ORDER BY D.ID DESC', [scaleId]);
    }
    return _db.query(table, orderBy: 'ID DESC');
  }

  static const _projectSelect = '''
SELECT E.*, B.NombreBuque, S.NombreServicio,
 C.EstadoBloqueo, C.TitularUsuarioID, C.SesionTrabajoID,
 U.NombreMostrado AS TitularNombre,
 (SELECT A2.NombreMostrado FROM PM_Asignaciones A JOIN PM_Usuarios A2 ON A.UsuarioID=A2.ID WHERE A.EscalaID=E.ID AND A.Vigente=1 ORDER BY A.ID DESC LIMIT 1) AS AuditorAsignado
FROM PM_Escalas E JOIN PM_Buques B ON E.BuqueID=B.ID
LEFT JOIN PM_Servicios S ON E.ServicioID=S.ID
LEFT JOIN PM_ControlEdicion C ON C.EscalaID=E.ID
LEFT JOIN PM_Usuarios U ON C.TitularUsuarioID=U.ID
''';

  Future<List<Map<String, Object?>>> projects({String? status, String search = ''}) async {
    final where = <String>[];
    final args = <Object?>[];
    if (status != null && status.isNotEmpty && status != 'Todos') {
      if (status == 'Abiertos') {
        where.add("E.EstadoProyecto<>'Cerrado'");
      } else {
        where.add('E.EstadoProyecto=?'); args.add(status);
      }
    }
    if (search.trim().isNotEmpty) {
      where.add(r"""(B.NombreBuque LIKE ? ESCAPE '\' OR E.CallKey LIKE ? ESCAPE '\' OR E.Viaje LIKE ? ESCAPE '\')""");
      final escaped = search.trim().replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
      final term = '%$escaped%';
      args.addAll([term, term, term]);
    }
    return _db.rawQuery('$_projectSelect ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} ORDER BY E.FechaETA, E.ETACompletaUTC, E.ID', args);
  }

  Future<Map<String, Object?>> project(int id) async {
    final result = await _db.rawQuery('$_projectSelect WHERE E.ID=?', [id]);
    if (result.isEmpty) throw const DomainException('El proyecto ya no existe.');
    return result.first;
  }

  Future<Map<String, int>> counts() async {
    final result = await _db.rawQuery('SELECT EstadoProyecto,COUNT(*) AS n FROM PM_Escalas GROUP BY EstadoProyecto');
    final counts = <String, int>{'Todos': 0, 'Abiertos': 0, 'Pendiente': 0, 'EnProceso': 0, 'EnPausa': 0, 'PendienteRevision': 0, 'Devuelto': 0, 'Cerrado': 0};
    for (final row in result) {
      final key = row['EstadoProyecto'] as String;
      final count = (row['n'] as num).toInt();
      counts[key] = count;
      counts['Todos'] = counts['Todos']! + count;
      if (key != 'Cerrado') counts['Abiertos'] = counts['Abiertos']! + count;
    }
    return counts;
  }

  Future<List<Map<String, Object?>>> pendingTasks() => _db.rawQuery('''
SELECT T.*,E.CallKey,B.NombreBuque FROM PM_TareasProyecto T
JOIN PM_Escalas E ON E.ID=T.EscalaID JOIN PM_Buques B ON B.ID=E.BuqueID
WHERE T.Aplica=1 AND T.EstadoTarea<>'Completada' AND E.EstadoProyecto<>'Cerrado'
ORDER BY T.Obligatoria DESC,T.VenceUTC,T.ID
''');

  Future<Map<String, Object?>> _row(DatabaseExecutor tx, String table, int id) async {
    _table(table);
    final rows = await tx.query(table, where: 'ID=?', whereArgs: [id]);
    if (rows.isEmpty) throw const DomainException('El registro ya no existe.');
    return Map<String, Object?>.from(rows.first);
  }

  Future<int?> _scaleFor(DatabaseExecutor tx, String table, Map<String, Object?> values, int? id) async {
    if (table == 'PM_Escalas') return id;
    if (values['EscalaID'] != null) return (values['EscalaID'] as num).toInt();
    if (table == 'PM_HourlyGang' && values['HourlyID'] != null) {
      return ((await _row(tx, 'PM_Hourly', values['HourlyID'] as int))['EscalaID'] as num).toInt();
    }
    if (table == 'PM_EstimadoGangDetalle' && values['GangID'] != null) {
      return ((await _row(tx, 'PM_EstimadoGang', values['GangID'] as int))['EscalaID'] as num).toInt();
    }
    return null;
  }

  Map<String, Object?> _newRecord(TableSpec table) {
    final map = <String, Object?>{};
    for (final field in table.fields.where((f) => f.name != 'ID')) {
      if (field.defaultValue != null) {
        map[field.name] = field.type == 'boolean' && field.defaultValue is bool ? (field.defaultValue == true ? 1 : 0) : field.defaultValue;
      } else if (field.type == 'boolean') {
        map[field.name] = 0;
      } else if ((field.type == 'integer' || field.type == 'real') && field.references == null && field.required) {
        map[field.name] = 0;
      } else {
        map[field.name] = null;
      }
    }
    return map;
  }

  Object? _coerce(FieldSpec field, Object? value) {
    if (value == null || value is String && value.trim().isEmpty) return null;
    switch (field.type) {
      case 'integer':
        final number = value is num ? value : num.tryParse('$value');
        if (number == null || !number.isFinite || number != number.truncate()) throw DomainException('${field.label}: se requiere un entero.');
        return number.toInt();
      case 'real':
        final number = value is num ? value : num.tryParse('$value');
        if (number == null || !number.isFinite) throw DomainException('${field.label}: número inválido.');
        return number.toDouble();
      case 'boolean':
        if (value is bool) return value ? 1 : 0;
        if (value == 0 || value == 1) return value;
        throw DomainException('${field.label}: selecciona Sí o No.');
      case 'date':
        final date = value is DateTime ? value : _strictDate('$value');
        if (date == null) throw DomainException('${field.label}: fecha inválida.');
        if (field.name == 'FechaETA' || field.name == 'AnteriorFechaETA' || field.name == 'NuevaFechaETA') {
          return '${date.year.toString().padLeft(4,'0')}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}';
        }
        return date.toUtc().toIso8601String();
      default:
        return '$value'.trim();
    }
  }

  Future<void> _validate(DatabaseExecutor tx, TableSpec table, Map<String, Object?> values) async {
    for (final field in table.fields.where((f) => f.name != 'ID')) {
      final value = values[field.name];
      if (field.required && (value == null || value is String && value.trim().isEmpty)) throw DomainException('Completa ${field.label}.');
      if (value == null) continue;
      if (field.type == 'text' && '$value'.length > 255) throw DomainException('${field.label}: máximo 255 caracteres.');
      if ((field.type == 'integer' || field.type == 'real') && value is num && value < 0) throw DomainException('${field.label}: no puede ser negativo.');
      if (field.references != null) await _row(tx, field.references!, value as int);
    }
  }

  Future<int> save(String table, Map<String, Object?> values, {int? id, int? scaleId, String reason = ''}) async {
    final spec = _table(table);
    if (!spec.editable) throw const DomainException('Este registro se modifica desde su acción específica.');
    try {
      return await _db.transaction((tx) async {
        await _requireSupervisor(tx, capability: _tableCapability(table));
        final before = id == null ? <String, Object?>{} : await _row(tx, table, id);
        final merged = id == null ? _newRecord(spec) : Map<String, Object?>.from(before)..remove('ID');
        for (final entry in values.entries) {
          final matching = spec.fields.where((f) => f.name == entry.key);
          if (matching.isEmpty || matching.first.system) throw DomainException('Campo no editable: ${entry.key}.');
          merged[entry.key] = _coerce(matching.first, entry.value);
        }
        if (scaleId != null && spec.fields.any((f) => f.name == 'EscalaID')) {
          if (merged['EscalaID'] != null && merged['EscalaID'] != scaleId) throw const DomainException('No se puede mover un registro a otro proyecto.');
          merged['EscalaID'] = scaleId;
        }
        final scale = await _scaleFor(tx, table, merged, id);
        if (id != null && await _scaleFor(tx, table, before, id) != scale) throw const DomainException('No se puede mover un registro a otro proyecto.');
        if (scale != null && table != 'PM_Evaluaciones') {
          final project = await _row(tx, 'PM_Escalas', scale);
          if (project['EstadoProyecto'] == 'Cerrado' || project['EstadoProyecto'] == 'PendienteRevision') {
            // Instructions may be added to a review request; they immediately block approval.
            if (table != 'PM_TareasProyecto' || project['EstadoProyecto'] == 'Cerrado') throw const DomainException('Devuelve o reabre el proyecto antes de modificarlo.');
          }
        }
        if (scale != null && _operationalTables.contains(table)) {
          await _ownedControl(tx, scale);
        }
        await _prepareBusiness(tx, table, merged, before, id, scale, reason);
        await _validate(tx, spec, merged);
        final recordId = id ?? await tx.insert(table, merged);
        if (id != null) await tx.update(table, merged, where: 'ID=?', whereArgs: [id]);
        var actualScale = scale;
        if (table == 'PM_Escalas') {
          actualScale = recordId;
          if (id == null) {
            await _initializeScale(tx, recordId);
          } else if (before['FechaETA'] != merged['FechaETA'] || before['ETACompletaUTC'] != merged['ETACompletaUTC']) {
            await tx.insert('PM_ETA_Historial', {'EscalaID': recordId, 'AnteriorFechaETA': before['FechaETA'], 'NuevaFechaETA': merged['FechaETA'], 'AnteriorETACompletaUTC': before['ETACompletaUTC'], 'NuevaETACompletaUTC': merged['ETACompletaUTC'], 'Motivo': reason.trim(), 'ActorID': _actorId, 'FechaUTC': _now()});
          }
        }
        if (['PM_Hourly','PM_HourlyGang','PM_Exclusiones'].contains(table) && actualScale != null) {
          await tx.update('PM_CierreHourly', {'Finalizado': 0}, where: 'EscalaID=?', whereArgs: [actualScale]);
        }
        if (table == 'PM_HitosBuque' && actualScale != null) {
          await tx.update('PM_ReportesMaritimos', {'EstadoReporte': 'Borrador','ValidadorID': null,'ValidadoUTC': null}, where: 'EscalaID=?', whereArgs: [actualScale]);
        }
        await _audit(tx, id == null ? 'CREAR' : 'MODIFICAR', table, recordId, before.isEmpty ? null : before, merged, actualScale, reason: reason);
        return recordId;
      });
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) throw const DomainException('Ya existe un registro con esa clave.');
      if (error.toString().contains('FOREIGN KEY constraint failed')) throw const DomainException('La referencia seleccionada no existe o todavía se utiliza.');
      rethrow;
    }
  }

  Future<void> _prepareBusiness(DatabaseExecutor tx, String table, Map<String, Object?> data, Map<String, Object?> before, int? id, int? scale, String reason) async {
    final now = _now();
    switch (table) {
      case 'PM_Usuarios':
        if (id == _actorId && (data['Activo'] != 1 || data['RolID'] != before['RolID'])) throw const DomainException('No puedes desactivar tu propio perfil o cambiar su rol mientras lo utilizas.');
        if (id == null) data['AltaUTC'] = now;
        if (data['Activo'] == 0) data['BajaUTC'] = now;
        if (data['Activo'] == 1) data['BajaUTC'] = null;
        break;
      case 'PM_Roles':
        if (id != null && (before['CodigoRol'] == 'GERENCIA' || before['CodigoRol'] == 'AUDITOR') && (data['CodigoRol'] != before['CodigoRol'] || data['Activo'] != 1)) throw const DomainException('Los roles base deben conservar sus códigos y permanecer activos.');
        break;
      case 'PM_Equipos':
        if (id == null) { data['InstalacionGUID'] = _token(); data['RegistradoUTC'] = now; }
        break;
      case 'PM_Escalas':
        data['EstadoProyecto'] = before['EstadoProyecto'] ?? 'Pendiente';
        data['VersionProyecto'] = ((before['VersionProyecto'] as num?)?.toInt() ?? 0) + 1;
        if (id != null && (before['FechaETA'] != data['FechaETA'] || before['ETACompletaUTC'] != data['ETACompletaUTC']) && reason.trim().isEmpty) throw const DomainException('Explica el motivo del cambio de ETA.');
        final start = _date(data['InicioRealUTC']); final end = _date(data['FinRealUTC']);
        if (start != null && end != null && !end.isAfter(start)) throw const DomainException('El fin de operación debe ser posterior al inicio.');
        if (before['HoraLimiteOriginalUTC'] == null) data['HoraLimiteOriginalUTC'] = data['HoraLimiteFinUTC'];
        break;
      case 'PM_TareasProyecto':
        if (id == null) {
          data['CreadaPorID'] = _actorId; data['CreadaUTC'] = now;
          data['EstadoTarea'] ??= 'Pendiente'; data['Seccion'] ??= 'Especial';
          data['EsEspecial'] = 1;
        }
        if (!['Pendiente','Completada'].contains(data['EstadoTarea'])) throw const DomainException('Estado de tarea inválido.');
        if (data['Aplica'] == 0 && '${data['Observacion'] ?? ''}'.trim().isEmpty) throw const DomainException('Justifica por qué no aplica la tarea.');
        if (data['EstadoTarea'] == 'Completada') {
          data['RealizadaPorID'] = _actorId; data['RealizadaUTC'] = now;
        } else {
          if (before['EstadoTarea'] == 'Completada' && reason.trim().isEmpty) throw const DomainException('Explica por qué reviertes una tarea.');
          data['RealizadaPorID'] = null; data['RealizadaUTC'] = null;
        }
        break;
      case 'PM_Asignaciones':
        await _activeAuditor(tx, data['UsuarioID'] as int?);
        data['AsignadoPorID'] = _actorId; data['AsignadoUTC'] = now;
        data['TipoParticipacion'] ??= 'Responsable';
        if (data['Vigente'] == 0 && before['Vigente'] == 1) data['FinAsignacionUTC'] = now;
        if (data['Vigente'] == 1) data['FinAsignacionUTC'] = null;
        if (data['Vigente'] == 1) {
          await tx.update('PM_Asignaciones', {'Vigente':0,'FinAsignacionUTC':now}, where: 'EscalaID=? AND Vigente=1 AND ID<>?', whereArgs: [scale,id ?? -1]);
        }
        break;
      case 'PM_Evaluaciones':
        data['GerenteID'] = _actorId; data['FechaUTC'] = now;
        await _activeAuditor(tx, data['AuditorID'] as int?, requireActive: false);
        final participants = await tx.rawQuery('SELECT ID FROM PM_Asignaciones WHERE EscalaID=? AND UsuarioID=? UNION SELECT ID FROM PM_SesionesTrabajo WHERE EscalaID=? AND UsuarioID=?', [scale, data['AuditorID'], scale, data['AuditorID']]);
        if (participants.isEmpty) throw const DomainException('Solo se evalúa a un auditor que participó en este proyecto.');
        break;
      case 'PM_PermisosRol':
        if (!permissionCodes.containsKey(data['CodigoPermiso'])) throw DomainException('Código de permiso desconocido. Usa uno de: ${permissionCodes.keys.join(', ')}.');
        if (data['CodigoPermiso'] == 'ADMINISTRAR' && data['Habilitado'] == 0) {
          final current = await _row(tx, 'PM_Usuarios', _actorId!);
          if (data['RolID'] == current['RolID']) throw const DomainException('No puedes retirar la administración a tu propio rol.');
        }
        data['ModificadoPorID'] = _actorId; data['ModificadoUTC'] = now;
        break;
      case 'PM_Estimados':
      case 'PM_EstimadoGang':
      case 'PM_EstimadoGangDetalle':
        if (scale != null) {
          final plans = await tx.query('PM_Estimados', where: 'EscalaID=?', whereArgs: [scale]);
          if (plans.isNotEmpty && plans.first['EstimadoCerrado'] == 1) throw const DomainException('El estimado está congelado. Registra las diferencias como exclusiones.');
        }
        if (table == 'PM_Estimados') {
          if (_num(data['ExpSeaCarrierVacios']) > _num(data['ExpVacios'])) throw const DomainException('El subtipo de vacíos supera el total.');
          if (_num(data['ExpGensetChassis']) > _num(data['ExpFull']) + _num(data['ExpEspecial'])) throw const DomainException('El subtipo genset/chassis supera la exportación.');
          final total = _plan(data); final product = _num(data['ProductividadMeta']) * _num(data['CuadrillasPrevistas']);
          data['ProductividadEstimadaBuque'] = product;
          if (product > 0) {
            data['HorasEstimadas'] = total / product;
            final date = _date(data['InicioPrevistoUTC']);
            data['ETCEstimadoUTC'] = date?.add(Duration(minutes:(total/product*60).round())).toIso8601String();
          } else {
            data['HorasEstimadas'] = null;
            data['ETCEstimadoUTC'] = null;
          }
        }
        break;
      case 'PM_VaciosDestino':
        if (_num(data['Cantidad']) <= 0) throw const DomainException('La cantidad debe ser positiva.');
        break;
      case 'PM_Hourly':
        final plans = await tx.query('PM_Estimados', where: 'EscalaID=?', whereArgs: [scale]);
        if (plans.length != 1 || plans.first['EstimadoCerrado'] != 1) throw const DomainException('Congela el estimado antes de registrar Hourly.');
        data['ActualizadoPorID'] = _actorId; data['ActualizadoUTC'] = now;
        data['EstadoValidacion'] = 'Borrador';
        final start = _date(data['HoraInicioUTC']); final end = _date(data['HoraFinUTC']);
        if (start == null || end == null || !end.isAfter(start)) throw const DomainException('El intervalo necesita inicio y fin válidos.');
        final duration = end.difference(start).inMicroseconds / Duration.microsecondsPerMinute;
        final lostHours = _num(data['PerdidaHoras']); final lostMinutes = _num(data['PerdidaMinutos']);
        if (lostMinutes < 0 || lostMinutes > 59 || lostHours < 0 || lostHours*60+lostMinutes > duration) throw const DomainException('Tiempo perdido inválido para el intervalo.');
        final overlaps = await tx.rawQuery('SELECT ID FROM PM_Hourly WHERE EscalaID=? AND ID<>? AND HoraInicioUTC<? AND HoraFinUTC>?', [scale,id ?? -1,end.toUtc().toIso8601String(),start.toUtc().toIso8601String()]);
        if (overlaps.isNotEmpty) throw const DomainException('El intervalo se solapa con otro registro Hourly.');
        data['ClaveEscalaIntervalo'] = '$scale/${start.toUtc().toIso8601String()}';
        final project = await _row(tx, 'PM_Escalas', scale!);
        final operationStart = _date(project['InicioRealUTC']);
        if (operationStart == null || start.isBefore(operationStart)) throw const DomainException('El intervalo no puede empezar antes de la operación.');
        final operationEnd = _date(project['FinRealUTC']);
        if (operationEnd != null && end.isAfter(operationEnd)) throw const DomainException('El intervalo termina después del fin de operación.');
        final earlier = await tx.query('PM_Hourly', where: 'EscalaID=? AND ID<>? AND HoraFinUTC<=?', whereArgs: [scale, id ?? -1, end.toUtc().toIso8601String()]);
        final elapsed = end.difference(operationStart).inMicroseconds / Duration.microsecondsPerMinute;
        final actual = earlier.fold<int>(0, (sum, h) => sum + _movements(h)) + _movements(data);
        final production = actual * 60 / elapsed;
        data['ProductividadCorte'] = production;
        final excluded = await tx.rawQuery('SELECT COALESCE(SUM(Cantidad),0) AS n FROM PM_Exclusiones WHERE EscalaID=? AND Validado=1', [scale]);
        final remaining = _plan(plans.first) - actual - _num(excluded.single['n']);
        data['ETCProyectadoUTC'] = production > 0 && remaining >= 0 ? end.add(Duration(minutes: (remaining / production * 60).round())).toUtc().toIso8601String() : null;
        if (duration > 24*60 && '${data['NotaHora'] ?? ''}'.trim().isEmpty) throw const DomainException('Justifica el intervalo extraordinario en la observación.');
        break;
      case 'PM_HourlyGang':
        final hourly = await _row(tx, 'PM_Hourly', data['HourlyID'] as int);
        final gang = await _row(tx, 'PM_EstimadoGang', data['GangID'] as int);
        if (hourly['EscalaID'] != gang['EscalaID']) throw const DomainException('La cuadrilla pertenece a otro proyecto.');
        break;
      case 'PM_Exclusiones':
        data['ActorID'] = _actorId; data['RegistradaUTC'] = now;
        if (data['Validado'] == 1) {
          if (data['GangID'] == null) throw const DomainException('Asigna la exclusión validada a una cuadrilla.');
          final gang = await _row(tx, 'PM_EstimadoGang', data['GangID'] as int);
          if (gang['EscalaID'] != scale) throw const DomainException('La cuadrilla pertenece a otro proyecto.');
        }
        break;
      case 'PM_HitosBuque':
        data['ActualizadoPorID'] = _actorId; data['Validacion'] = 'Pendiente';
        final type = await _row(tx, 'PM_TiposHito', data['TipoHitoID'] as int);
        if (data['NoAplica'] == 1) {
          if (type['PermiteNA'] != 1 || '${data['Justificacion'] ?? ''}'.trim().isEmpty || data['FechaHoraUTC'] != null) throw const DomainException('No aplica requiere permiso del catálogo, justificación y fecha vacía.');
        } else if (_date(data['FechaHoraUTC']) == null) { throw const DomainException('Indica la fecha y hora del hito.'); }
        break;
      case 'PM_ReportesMaritimos':
        data['EstadoReporte'] = 'Borrador'; data['ValidadorID'] = null; data['ValidadoUTC'] = null;
        if (!['Arrival','Departure'].contains(data['TipoReporte'])) throw const DomainException('Selecciona Arrival o Departure.');
        final start = _date(data['RemolqueDesdeUTC']); final end = _date(data['RemolqueHastaUTC']);
        if (start != null && end != null && end.isBefore(start)) throw const DomainException('El remolque finaliza antes de empezar.');
        break;
      case 'PM_IncidenciasValidacion':
        data['FechaUTC'] = now;
        if (data['Revisada'] == 1) {
          if ('${data['Justificacion'] ?? ''}'.trim().isEmpty) throw const DomainException('Justifica la revisión de la incidencia.');
          data['RevisadoPorID'] = _actorId;
        }
        break;
    }
  }

  static DateTime? _strictDate(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2})(?::(\d{2})(?:\.\d{1,6})?)?(?:[zZ]|([+-])(\d{2}):?(\d{2}))?)?$').firstMatch(value);
    if (match == null) return null;
    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    if (match[4] != null && (int.parse(match[4]!) > 23 || int.parse(match[5]!) > 59 || match[6] != null && int.parse(match[6]!) > 59)) return null;
    if (match[8] != null && (int.parse(match[8]!) > 23 || int.parse(match[9]!) > 59)) return null;
    final calendar = DateTime.utc(year, month, day);
    if (calendar.year != year || calendar.month != month || calendar.day != day) return null;
    return DateTime.tryParse(value);
  }
  static DateTime? _date(Object? value) => value == null ? null : _strictDate('$value');
  static num _num(Object? value) => value is num ? value : 0;
  static const _groups = <String,List<String>>{
    'MovImp':['ImpFull','ImpVacios','ImpEslingados','ImpEspecial'],
    'ExpFull':['ExpFull','ExpEslingados','ExpEspecial'],
    'ExpVacio':['ExpVacios'], 'RestowDown':['RestowsBajan'],
    'RestowUp':['RestowsSuben'], 'MovTapas':['MovTapas'],
    'MovEspeciales':['MovDama','MovCapones','MovOtros','MovChasis'],
  };
  static int _plan(Map<String,Object?> row) => _groups.values.expand((list)=>list).fold<num>(0,(sum,key)=>sum+_num(row[key])).toInt();
  static int _movements(Map<String,Object?> row) => _groups.keys.fold<num>(0,(sum,key)=>sum+_num(row[key])).toInt();

  Future<void> _activeAuditor(DatabaseExecutor tx, int? id, {bool requireActive = true}) async {
    if (id == null) throw const DomainException('Selecciona un auditor activo.');
    final records = await tx.rawQuery("SELECT U.ID FROM PM_Usuarios U JOIN PM_Roles R ON U.RolID=R.ID WHERE U.ID=? AND (${requireActive ? 'U.Activo=1' : '1=1'}) AND R.Activo=1 AND R.CodigoRol='AUDITOR'", [id]);
    if (records.isEmpty) throw const DomainException('El operador seleccionado no es un auditor activo.');
  }

  Future<void> _initializeScale(DatabaseExecutor tx, int scale, {bool initializeMaritime = true}) async {
    await tx.insert('PM_ControlEdicion', {'EscalaID':scale,'EstadoBloqueo':'Libre','UltimoCambioUTC':_now(),'VersionControl':1});
    final plan = _newRecord(_table('PM_Estimados'))..['EscalaID']=scale;
    await tx.insert('PM_Estimados',plan);
    await tx.insert('PM_CierreHourly',{'EscalaID':scale,'Finalizado':0});
    final tasks = await tx.query('PM_CatalogoTareas',where:'Activa=1',orderBy:'Orden');
    for (final task in tasks) {
      await tx.insert('PM_TareasProyecto',{'EscalaID':scale,'CatalogoTareaID':task['ID'],'EsEspecial':0,'TextoTarea':task['NombreTarea'],'Seccion':task['Seccion'],'Obligatoria':task['ObligatoriaDefecto'],'Aplica':1,'EstadoTarea':'Pendiente','CreadaPorID':_actorId,'CreadaUTC':_now()});
    }
    if (initializeMaritime) {
      for (final type in await tx.query('PM_TiposHito', orderBy: 'Orden')) {
        await tx.insert('PM_HitosBuque', {'EscalaID': scale, 'TipoHitoID': type['ID'], 'NoAplica': 0, 'Validacion': 'Pendiente', 'ActualizadoPorID': _actorId});
      }
      for (final kind in ['Arrival', 'Departure']) {
        await tx.insert('PM_ReportesMaritimos', {'EscalaID': scale, 'TipoReporte': kind, 'EstadoReporte': 'Borrador'});
      }
    }
  }

  Future<void> _audit(DatabaseExecutor tx, String event, String entity, int record, Map<String,Object?>? before, Map<String,Object?>? after, int? scale, {String reason='', int? actorOverride}) async {
    await tx.insert('PM_Eventos',{'EscalaID':scale,'ActorID':actorOverride ?? _actorId,'FechaUTC':_now(),'EventoCodigo':event,'Entidad':entity,'RegistroID':record,'Antes':before==null?null:jsonEncode(before),'Despues':jsonEncode({'data':after,'motivo':reason}),'Resultado':'OK','Origen':'Android SQLite local','TipoEvento':'SUPERVISOR','RequiereAuditoria':1,'CorrelacionGUID':_token()});
  }

  Future<void> addInstruction(int scaleId, String text, {bool required=true, DateTime? due}) async {
    if (text.trim().isEmpty) throw const DomainException('Escribe la instrucción.');
    await save('PM_TareasProyecto',{'TextoTarea':text.trim(),'Seccion':'Instrucción especial','Obligatoria':required?1:0,'Aplica':1,'VenceUTC':due?.toUtc().toIso8601String()},scaleId:scaleId);
  }

  Future<void> assign(int scaleId, int auditorId) async {
    await save('PM_Asignaciones',{'UsuarioID':auditorId,'TipoParticipacion':'Responsable','Vigente':1},scaleId:scaleId);
  }

  static const _operationalTables = <String>{
    'PM_Estimados', 'PM_EstimadoGang', 'PM_EstimadoGangDetalle',
    'PM_Hourly', 'PM_HourlyGang', 'PM_VaciosDestino', 'PM_Exclusiones',
    'PM_HitosBuque', 'PM_ReportesMaritimos',
  };

  Future<Map<String, Object?>> _ownedControl(DatabaseExecutor tx, int scaleId) async {
    final scale = await _row(tx, 'PM_Escalas', scaleId);
    if (scale['EstadoProyecto'] != 'EnProceso') throw const DomainException('Inicia o retoma el proyecto antes de modificar la operación.');
    final controls = await tx.query('PM_ControlEdicion', where: 'EscalaID=?', whereArgs: [scaleId]);
    if (controls.length != 1) throw const DomainException('El control de ocupación no es válido.');
    final control = controls.first;
    if (control['EstadoBloqueo'] != 'Tomado' || control['TitularUsuarioID'] != _actorId || control['SesionTrabajoID'] == null) throw const DomainException('Este proyecto está en consulta. Inícialo o solicita su liberación.');
    final session = await _row(tx, 'PM_SesionesTrabajo', control['SesionTrabajoID'] as int);
    if (session['EscalaID'] != scaleId || session['UsuarioID'] != _actorId || session['FinUTC'] != null) throw const DomainException('La sesión de trabajo no está activa.');
    return control;
  }

  Future<int> _localEquipment(DatabaseExecutor tx) async {
    final existing = await tx.query('PM_Equipos', where: 'UsuarioID=? AND Activo=1', whereArgs: [_actorId], orderBy: 'ID', limit: 1);
    if (existing.isNotEmpty) return existing.first['ID'] as int;
    return tx.insert('PM_Equipos', {'InstalacionGUID': _token(), 'UsuarioID': _actorId, 'EquipoEtiqueta': 'Supervisor local', 'RegistradoUTC': _now(), 'Activo': 1});
  }

  /// Starts a local SQLite session. This does not coordinate other devices.
  Future<void> start(int scaleId) async {
    await _db.transaction((tx) async {
      await _requireSupervisor(tx, capability: 'EDITAR_OPERACION');
      final before = await _row(tx, 'PM_Escalas', scaleId);
      if (!['Pendiente', 'EnPausa', 'Devuelto'].contains(before['EstadoProyecto'])) throw const DomainException('Este estado no permite iniciar el proyecto.');
      final controls = await tx.query('PM_ControlEdicion', where: 'EscalaID=?', whereArgs: [scaleId]);
      if (controls.length != 1 || controls.first['EstadoBloqueo'] != 'Libre') throw const DomainException('El proyecto ya tiene una ocupación.');
      final control = controls.first;
      final now = _now();
      final session = await tx.insert('PM_SesionesTrabajo', {'EscalaID': scaleId, 'UsuarioID': _actorId, 'EquipoID': await _localEquipment(tx), 'InicioUTC': now});
      await tx.update('PM_ControlEdicion', {'EstadoBloqueo': 'Tomado', 'TitularUsuarioID': _actorId, 'SesionTrabajoID': session, 'UltimoCambioUTC': now, 'VersionControl': (_num(control['VersionControl']) + 1).toInt()}, where: 'ID=?', whereArgs: [control['ID']]);
      await tx.update('PM_Escalas', {'EstadoProyecto': 'EnProceso', 'InicioRealUTC': before['InicioRealUTC'] ?? now, 'VersionProyecto': (_num(before['VersionProyecto']) + 1).toInt()}, where: 'ID=?', whereArgs: [scaleId]);
      final handovers = await tx.query('PM_Relevos', where: 'EscalaID=? AND TomaUTC IS NULL', whereArgs: [scaleId], orderBy: 'ID DESC', limit: 1);
      if (handovers.isNotEmpty) await tx.update('PM_Relevos', {'EntraUsuarioID': _actorId, 'TomaUTC': now}, where: 'ID=?', whereArgs: [handovers.first['ID']]);
      await _audit(tx, 'INICIAR', 'PM_Escalas', scaleId, before, {'EstadoProyecto': 'EnProceso', 'SesionTrabajoID': session}, scaleId);
    });
  }

  Future<void> pause(int scaleId, String reason) async {
    if (reason.trim().isEmpty) throw const DomainException('Escribe una observación de entrega.');
    await _db.transaction((tx) async {
      await _requireSupervisor(tx, capability: 'EDITAR_OPERACION');
      final before = await _row(tx, 'PM_Escalas', scaleId);
      final control = await _ownedControl(tx, scaleId);
      final now = _now();
      await tx.update('PM_SesionesTrabajo', {'FinUTC': now, 'FinTipo': 'PAUSA', 'Observacion': reason.trim()}, where: 'ID=?', whereArgs: [control['SesionTrabajoID']]);
      await tx.insert('PM_Relevos', {'EscalaID': scaleId, 'SaleUsuarioID': _actorId, 'PausaUTC': now, 'NotaEntrega': reason.trim()});
      await tx.update('PM_ControlEdicion', {'EstadoBloqueo': 'Libre', 'TitularUsuarioID': null, 'SesionTrabajoID': null, 'UltimoCambioUTC': now, 'VersionControl': (_num(control['VersionControl']) + 1).toInt()}, where: 'ID=?', whereArgs: [control['ID']]);
      await tx.update('PM_Escalas', {'EstadoProyecto': 'EnPausa', 'VersionProyecto': (_num(before['VersionProyecto']) + 1).toInt()}, where: 'ID=?', whereArgs: [scaleId]);
      await _audit(tx, 'PAUSA', 'PM_Escalas', scaleId, before, {'EstadoProyecto': 'EnPausa'}, scaleId, reason: reason);
    });
  }

  Future<void> freezePlan(int scaleId) async {
    await _db.transaction((tx) async {
      await _requireSupervisor(tx, capability: 'AJUSTAR_PLAN');
      await _ownedControl(tx, scaleId);
      final plans = await tx.query('PM_Estimados', where: 'EscalaID=?', whereArgs: [scaleId]);
      if (plans.length != 1) throw const DomainException('Falta un estimado único.');
      final plan = plans.first;
      if (plan['EstimadoCerrado'] == 1) throw const DomainException('El estimado ya está congelado.');
      final initial = _plan(plan);
      if (initial <= 0) throw const DomainException('El estimado necesita movimientos positivos.');
      final gangs = await tx.query('PM_EstimadoGang', where: 'EscalaID=?', whereArgs: [scaleId]);
      if (gangs.isEmpty || gangs.fold<num>(0, (sum, g) => sum + _num(g['MovimientosAsignados'])) != initial) throw const DomainException('Las cuadrillas planificadas deben sumar el estimado del buque.');
      final hourly = await tx.query('PM_Hourly', where: 'EscalaID=?', whereArgs: [scaleId], limit: 1);
      if (hourly.isNotEmpty) throw const DomainException('El plan debe congelarse antes del primer intervalo Hourly.');
      final now = _now();
      await tx.update('PM_Estimados', {'EstimadoCerrado': 1, 'CongeladoUTC': now}, where: 'ID=?', whereArgs: [plan['ID']]);
      final closings = await tx.query('PM_CierreHourly', where: 'EscalaID=?', whereArgs: [scaleId]);
      if (closings.length != 1) throw const DomainException('Falta el control de cierre Hourly.');
      await tx.update('PM_CierreHourly', {'MovInicial': initial, 'Finalizado': 0}, where: 'ID=?', whereArgs: [closings.first['ID']]);
      await _audit(tx, 'CONGELAR_ESTIMADO', 'PM_Estimados', plan['ID'] as int, plan, {'EstimadoCerrado': 1, 'MovInicial': initial}, scaleId);
    });
  }

  Future<void> validateReports(int scaleId) async {
    await _db.transaction((tx) async {
      await _requireSupervisor(tx, capability: 'EDITAR_OPERACION');
      await _ownedControl(tx, scaleId);
      final problems = await _maritimeProblems(tx, scaleId, requireValidated: false);
      if (problems.isNotEmpty) throw DomainException(problems.join('\n'));
      final now = _now();
      await tx.update('PM_HitosBuque', {'Validacion': 'OK', 'ActualizadoPorID': _actorId}, where: 'EscalaID=?', whereArgs: [scaleId]);
      await tx.update('PM_ReportesMaritimos', {'EstadoReporte': 'Validado', 'ValidadorID': _actorId, 'ValidadoUTC': now}, where: 'EscalaID=?', whereArgs: [scaleId]);
      await _audit(tx, 'VALIDAR_REPORTES', 'PM_Escalas', scaleId, null, {'Arrival': 'Validado', 'Departure': 'Validado'}, scaleId);
    });
  }

  Future<void> finalizeHourly(int scaleId) async {
    await _db.transaction((tx) async {
      await _requireSupervisor(tx, capability: 'EDITAR_OPERACION');
      await _ownedControl(tx, scaleId);
      final problems = await _closeProblems(tx, scaleId, hourlyOnly: true, requireFinalized: false);
      if (problems.isNotEmpty) throw DomainException(problems.join('\n'));
      final plan = (await tx.query('PM_Estimados', where: 'EscalaID=?', whereArgs: [scaleId])).single;
      final hourly = await tx.query('PM_Hourly', where: 'EscalaID=?', whereArgs: [scaleId]);
      final exclusions = await tx.query('PM_Exclusiones', where: 'EscalaID=? AND Validado=1', whereArgs: [scaleId]);
      final scale = await _row(tx, 'PM_Escalas', scaleId);
      final movements = hourly.fold<int>(0, (sum, h) => sum + _movements(h));
      final minutes = _date(scale['FinRealUTC'])!.difference(_date(scale['InicioRealUTC'])!).inMicroseconds / Duration.microsecondsPerMinute;
      final changes = <String, Object?>{'Finalizado': 1, 'FinalizadoUTC': _now(), 'FinalizadoPorID': _actorId, 'MovInicial': _plan(plan), 'MovReal': movements, 'MovExcluido': exclusions.fold<num>(0, (sum, x) => sum + _num(x['Cantidad'])), 'SaldoFinal': 0, 'ProdRealFinal': movements * 60 / minutes, 'ProdEstimada': plan['ProductividadEstimadaBuque']};
      final closing = (await tx.query('PM_CierreHourly', where: 'EscalaID=?', whereArgs: [scaleId])).single;
      await tx.update('PM_CierreHourly', changes, where: 'ID=?', whereArgs: [closing['ID']]);
      await _audit(tx, 'FINALIZAR_HOURLY', 'PM_CierreHourly', closing['ID'] as int, closing, changes, scaleId);
    });
  }

  Future<void> submitReview(int scaleId) async {
    await _db.transaction((tx) async {
      await _requireSupervisor(tx, capability: 'EDITAR_OPERACION');
      final before = await _row(tx, 'PM_Escalas', scaleId);
      final control = await _ownedControl(tx, scaleId);
      final problems = await _closeProblems(tx, scaleId);
      if (problems.isNotEmpty) throw DomainException(problems.join('\n'));
      final now = _now();
      await tx.update('PM_SesionesTrabajo', {'FinUTC': now, 'FinTipo': 'TERMINAR'}, where: 'ID=?', whereArgs: [control['SesionTrabajoID']]);
      await tx.update('PM_ControlEdicion', {'EstadoBloqueo': 'EnRevision', 'TitularUsuarioID': null, 'SesionTrabajoID': null, 'UltimoCambioUTC': now, 'VersionControl': (_num(control['VersionControl']) + 1).toInt()}, where: 'ID=?', whereArgs: [control['ID']]);
      await tx.update('PM_Escalas', {'EstadoProyecto': 'PendienteRevision', 'VersionProyecto': (_num(before['VersionProyecto']) + 1).toInt()}, where: 'ID=?', whereArgs: [scaleId]);
      await _audit(tx, 'TERMINAR', 'PM_Escalas', scaleId, before, {'EstadoProyecto': 'PendienteRevision'}, scaleId);
    });
  }

  Future<void> release(int scaleId,String reason) async {
    if(reason.trim().isEmpty) throw const DomainException('Explica el motivo de liberar la ocupación.');
    await _db.transaction((tx) async {
      await _requireSupervisor(tx, capability: 'LIBERAR_OCUPACION');
      final scale=await _row(tx,'PM_Escalas',scaleId);
      if(!['EnProceso','EnPausa','Devuelto','Pendiente'].contains(scale['EstadoProyecto'])) throw const DomainException('Este estado no permite liberar ocupación.');
      final controls=await tx.query('PM_ControlEdicion',where:'EscalaID=?',whereArgs:[scaleId]);
      if(controls.length!=1) throw const DomainException('El control de ocupación no es válido.');
      final control=controls.first;
      if(control['EstadoBloqueo']!='Tomado') throw const DomainException('El proyecto ya está libre.');
      if(control['SesionTrabajoID']!=null) {
        final session = await _row(tx, 'PM_SesionesTrabajo', control['SesionTrabajoID'] as int);
        if (session['EscalaID'] != scaleId || session['UsuarioID'] != control['TitularUsuarioID'] || session['FinUTC'] != null) throw const DomainException('La sesión de ocupación es incoherente; revisa el historial antes de liberar.');
        await tx.update('PM_SesionesTrabajo',{'FinUTC':_now(),'FinTipo':'LIBERAR_GERENCIA','Observacion':reason.trim()},where:'ID=? AND FinUTC IS NULL',whereArgs:[control['SesionTrabajoID']]);
      }
      await tx.insert('PM_Relevos',{'EscalaID':scaleId,'SaleUsuarioID':control['TitularUsuarioID'],'PausaUTC':_now(),'NotaEntrega':reason.trim()});
      await tx.update('PM_ControlEdicion',{'EstadoBloqueo':'Libre','TitularUsuarioID':null,'SesionTrabajoID':null,'UltimoCambioUTC':_now(),'VersionControl':(_num(control['VersionControl'])+1).toInt()},where:'ID=?',whereArgs:[control['ID']]);
      await tx.update('PM_Escalas',{'EstadoProyecto':'EnPausa','VersionProyecto':(_num(scale['VersionProyecto'])+1).toInt()},where:'ID=?',whereArgs:[scaleId]);
      await _audit(tx,'LIBERAR_OCUPACION','PM_Escalas',scaleId,scale,{'EstadoProyecto':'EnPausa'},scaleId,reason:reason);
    });
  }

  Future<List<String>> closeProblems(int id) async => _closeProblems(_db,id);

  Future<List<String>> _closeProblems(DatabaseExecutor tx,int id, {bool hourlyOnly = false, bool requireFinalized = true}) async {
    final problems=<String>[];
    final scale=await _row(tx,'PM_Escalas',id);
    final start=_date(scale['InicioRealUTC']); final end=_date(scale['FinRealUTC']);
    if(start==null || end==null || !end.isAfter(start)) problems.add('Completar inicio y fin real de operación en orden cronológico.');
    final tasks=await tx.query('PM_TareasProyecto',where:"EscalaID=? AND Obligatoria=1 AND Aplica=1 AND EstadoTarea<>'Completada'",whereArgs:[id]);
    if(!hourlyOnly && tasks.isNotEmpty) problems.add('${tasks.length} tareas obligatorias pendientes.');
    final issues=await tx.query('PM_IncidenciasValidacion',where:"EscalaID=? AND Revisada=0 AND Nivel IN ('Error','Advertencia')",whereArgs:[id]);
    if(issues.isNotEmpty) problems.add('${issues.length} incidencias pendientes de revisión.');
    final closings=await tx.query('PM_CierreHourly',where:'EscalaID=?',whereArgs:[id]);
    if(closings.length!=1 || requireFinalized && (closings.first['Finalizado']!=1 || _num(closings.first['SaldoFinal'])!=0)) problems.add('Hourly no finalizado o saldo final distinto de cero.');
    final plans=await tx.query('PM_Estimados',where:'EscalaID=?',whereArgs:[id]);
    if(plans.length!=1 || plans.first['EstimadoCerrado']!=1) problems.add('Falta el estimado original congelado.');
    final hourly=await tx.query('PM_Hourly',where:'EscalaID=?',whereArgs:[id],orderBy:'HoraInicioUTC');
    if(hourly.isEmpty) problems.add('No hay intervalos Hourly.');
    DateTime? previous;
    for(final hour in hourly){
      final a=_date(hour['HoraInicioUTC']);final b=_date(hour['HoraFinUTC']);
      if(a==null || b==null || !b.isAfter(a)) {problems.add('Intervalo Hourly ${hour['ID']} inválido.');continue;}
      if(previous!=null && a.isBefore(previous)) problems.add('Hay intervalos Hourly solapados.');
      previous=b;
      if(start!=null && a.isBefore(start)) problems.add('Hourly empieza antes del inicio real de operación.');
      if(end!=null && b.isAfter(end)) problems.add('Hourly termina después del fin real de operación.');
      final minutes=_num(hour['PerdidaMinutos']);final lost=_num(hour['PerdidaHoras'])*60+minutes;
      if(minutes<0 || minutes>59 || lost>b.difference(a).inMinutes) problems.add('Tiempo perdido inválido en Hourly ${hour['ID']}.');
      final gangs=await tx.query('PM_HourlyGang',where:'HourlyID=?',whereArgs:[hour['ID']]);
      if(gangs.fold<num>(0,(sum,g)=>sum+_num(g['MovimientosHora']))!=_movements(hour)) problems.add('Reparto por cuadrillas no cuadra en Hourly ${hour['ID']}.');
    }
    final exclusions=await tx.query('PM_Exclusiones',where:'EscalaID=?',whereArgs:[id]);
    if(exclusions.any((x)=>x['Validado']!=1)) problems.add('Hay exclusiones sin validar.');
    final approvedExclusions=exclusions.where((x)=>x['Validado']==1);
    final actualTotal=hourly.fold<int>(0,(sum,h)=>sum+_movements(h));
    final excludedTotal=approvedExclusions.fold<num>(0,(sum,x)=>sum+_num(x['Cantidad']));
    if(plans.length==1 && closings.length==1){
      final initial=_plan(plans.first);final closing=closings.first;
      if(initial-actualTotal-excludedTotal!=0 || requireFinalized && (_num(closing['MovInicial'])!=initial || _num(closing['MovReal'])!=actualTotal || _num(closing['MovExcluido'])!=excludedTotal)){
        problems.add('El cierre Hourly guardado no coincide con el plan y los movimientos actuales.');
      }
    }
    if(plans.length==1){
      for(final entry in _groups.entries){
        final initial=entry.value.fold<num>(0,(sum,k)=>sum+_num(plans.first[k]));
        final actual=hourly.fold<num>(0,(sum,h)=>sum+_num(h[entry.key]));
        final types=await tx.query('PM_TiposMovimiento',where:'Codigo=?',whereArgs:[entry.key]);
        final type=types.isEmpty?null:types.first['ID'];
        final excluded=approvedExclusions.where((x)=>x['TipoMovimientoID']==type).fold<num>(0,(sum,x)=>sum+_num(x['Cantidad']));
        if(initial-actual-excluded!=0) problems.add('Saldo por categoría ${entry.key} distinto de cero.');
      }
      final destinationRows=await tx.query('PM_VaciosDestino',where:'EscalaID=?',whereArgs:[id]);
      if(destinationRows.fold<num>(0,(sum,x)=>sum+_num(x['Cantidad']))>_num(plans.first['ExpVacios'])) problems.add('Los vacíos por destino superan el estimado.');
    }
    final gangs=await tx.query('PM_EstimadoGang',where:'EscalaID=?',whereArgs:[id]);
    for(final gang in gangs){
      final parts=await tx.query('PM_HourlyGang',where:'GangID=?',whereArgs:[gang['ID']]);
      final actual=parts.fold<num>(0,(sum,g)=>sum+_num(g['MovimientosHora']));
      final excluded=approvedExclusions.where((x)=>x['GangID']==gang['ID']).fold<num>(0,(sum,x)=>sum+_num(x['Cantidad']));
      if(_num(gang['MovimientosAsignados'])-actual-excluded!=0) problems.add('Saldo de cuadrilla ${gang['CodigoGang']} distinto de cero.');
    }
    if(gangs.isEmpty) problems.add('Falta el plan por cuadrillas.');
    if(plans.length==1 && gangs.fold<num>(0,(sum,g)=>sum+_num(g['MovimientosAsignados']))!=_plan(plans.first)) problems.add('El plan por cuadrillas no coincide con el estimado del buque.');
    if (!hourlyOnly) problems.addAll(await _maritimeProblems(tx, id));
    return problems.toSet().toList();
  }

  Future<List<String>> _maritimeProblems(DatabaseExecutor tx, int id, {bool requireValidated = true}) async {
    final problems = <String>[];
    for(final kind in ['Arrival','Departure']){
      final reports=await tx.query('PM_ReportesMaritimos',where:'EscalaID=? AND TipoReporte=?',whereArgs:[id,kind]);
      if(reports.length!=1 || requireValidated && reports.first['EstadoReporte']!='Validado') problems.add('$kind no validado.');
    }
    final types=await tx.query('PM_TiposHito',orderBy:'Orden');
    if(types.isEmpty) problems.add('Falta el catálogo de hitos.');
    DateTime? prev;
    for(final type in types){
      final hits=await tx.query('PM_HitosBuque',where:'EscalaID=? AND TipoHitoID=?',whereArgs:[id,type['ID']]);
      if(hits.isEmpty){if(type['Obligatorio']==1)problems.add('Falta hito ${type['Descripcion']}.');continue;}
      final hit=hits.first;
      if(hit['NoAplica']==1){
        if(type['PermiteNA']!=1 || '${hit['Justificacion']??''}'.trim().isEmpty || hit['FechaHoraUTC']!=null)problems.add('No aplica inválido en ${type['Descripcion']}.');
      }else{
        final date=_date(hit['FechaHoraUTC']);
        if(date==null){problems.add('Fecha vacía en ${type['Descripcion']}.');continue;}
        if(prev!=null && date.isBefore(prev)) problems.add('Cronología inválida en ${type['Descripcion']}.');
        if(prev!=null && date.difference(prev).inHours>24 && '${hit['Justificacion']??''}'.trim().isEmpty) problems.add('Justifica la duración extraordinaria en ${type['Descripcion']}.');
        prev=date;
      }
    }
    return problems.toSet().toList();
  }

  Future<void> review(int scaleId,String decision,String reason) async {
    if(reason.trim().isEmpty)throw const DomainException('Escribe el motivo de la decisión.');
    if(!['APROBAR','DEVOLVER','REABRIR'].contains(decision))throw const DomainException('Decisión desconocida.');
    await _db.transaction((tx)async{
      await _requireSupervisor(tx, capability: 'REVISAR_CIERRE');
      final before=await _row(tx,'PM_Escalas',scaleId);
      if(decision=='REABRIR'){
        if(before['EstadoProyecto']!='Cerrado')throw const DomainException('Solo se reabren proyectos cerrados.');
      }else if(before['EstadoProyecto']!='PendienteRevision'){
        throw const DomainException('El proyecto no está pendiente de revisión.');
      }
      if(decision=='APROBAR'){
        final problems=await _closeProblems(tx,scaleId);
        if(problems.isNotEmpty)throw DomainException(problems.join('\n'));
      }
      final now=_now();
      await tx.insert('PM_Revisiones',{'EscalaID':scaleId,'GerenteID':_actorId,'Decision':decision,'Observacion':reason.trim(),'FechaUTC':now});
      final changes=<String,Object?>{'EstadoProyecto':decision=='APROBAR'?'Cerrado':'Devuelto','FinalizadaRevisionUTC':now,'VersionProyecto':(_num(before['VersionProyecto'])+1).toInt()};
      if(decision=='APROBAR'){changes['FechaCierreUTC']=now;changes['CerradoPorID']=_actorId;}
      await tx.update('PM_Escalas',changes,where:'ID=?',whereArgs:[scaleId]);
      final controls = await tx.query('PM_ControlEdicion', where: 'EscalaID=?', whereArgs: [scaleId]);
      if (controls.length != 1) throw const DomainException('El control de ocupación no es válido.');
      await tx.update('PM_ControlEdicion',{'EstadoBloqueo':decision=='APROBAR'?'EnRevision':'Libre','TitularUsuarioID':null,'SesionTrabajoID':null,'UltimoCambioUTC':now,'VersionControl':(_num(controls.first['VersionControl'])+1).toInt()},where:'EscalaID=?',whereArgs:[scaleId]);
      if(decision!='APROBAR'){
        await tx.update('PM_CierreHourly',{'Finalizado':0},where:'EscalaID=?',whereArgs:[scaleId]);
        await tx.insert('PM_TareasProyecto',{'EscalaID':scaleId,'TextoTarea':reason.trim(),'Seccion':'Revisión de supervisor','Obligatoria':1,'Aplica':1,'EsEspecial':1,'EstadoTarea':'Pendiente','CreadaPorID':_actorId,'CreadaUTC':now});
      }
      await _audit(tx,decision,'PM_Escalas',scaleId,before,changes,scaleId,reason:reason);
    });
  }

  Future<Map<String,Object?>> projectMetrics(int id) async {
    final scale=await _row(_db,'PM_Escalas',id);
    final plans=await rows('PM_Estimados',scaleId:id);
    final plan=plans.isEmpty?<String,Object?>{}:plans.first;
    final hourly=await rows('PM_Hourly',scaleId:id);
    final tasks=await rows('PM_TareasProyecto',scaleId:id);
    final necessary=tasks.where((t)=>t['Aplica']==1 && t['Obligatoria']==1);
    final movements=hourly.fold<int>(0,(sum,h)=>sum+_movements(h));
    final exclusions=await rows('PM_Exclusiones',scaleId:id);
    final excluded=exclusions.where((x)=>x['Validado']==1).fold<num>(0,(sum,x)=>sum+_num(x['Cantidad']));
    final begin=_date(scale['InicioRealUTC']);
    DateTime? cut=_date(scale['FinRealUTC']);
    for(final h in hourly){final date=_date(h['HoraFinUTC']);if(date!=null && (cut==null || date.isAfter(cut)))cut=date;}
    final minutes=begin==null || cut==null?0:cut.difference(begin).inSeconds/60;
    final productivity=minutes>0?movements*60/minutes:0.0;
    final remaining=_plan(plan)-movements-excluded;
    return {'checklistDone':necessary.where((t)=>t['EstadoTarea']=='Completada').length,'checklistTotal':necessary.length,'movements':movements,'planMovements':_plan(plan),'productivity':productivity,'remaining':remaining,'etc':cut!=null && productivity>0 && remaining>=0?cut.add(Duration(minutes:(remaining/productivity*60).round())).toIso8601String():null,'limit':scale['HoraLimiteFinUTC'],'planEtc':plan['ETCEstimadoUTC'],'lostMinutes':hourly.fold<num>(0,(sum,h)=>sum+_num(h['PerdidaHoras'])*60+_num(h['PerdidaMinutos'])),'status':scale['EstadoProyecto']};
  }

  Future<List<Map<String,Object?>>> audit({int? scaleId})=>_db.rawQuery('''
SELECT E.*,U.NombreMostrado AS ActorNombre FROM PM_Eventos E JOIN PM_Usuarios U ON E.ActorID=U.ID
${scaleId==null?'':'WHERE E.EscalaID=?'} ORDER BY E.ID DESC LIMIT 500
''',scaleId==null?[]:[scaleId]);

  Future<List<Map<String,Object?>>> serviceReport() async {
    final scales=await _db.rawQuery("$_projectSelect WHERE E.EstadoProyecto='Cerrado'");
    final groups=<String,Map<String,Object?>>{};
    for(final scale in scales){
      final label='${scale['NombreServicio']??'Sin servicio'}';
      final key = '${scale['ServicioID'] ?? 'sin-servicio'}';
      final group=groups.putIfAbsent(key,()=>{'ServicioID':scale['ServicioID'],'NombreServicio':label,'Escalas':0,'Movimientos':0,'HorasReales':0.0,'HorasPerdidas':0.0,'HorasPlan':0.0});
      final id=scale['ID'] as int;final metrics=await projectMetrics(id);
      group['Escalas']=_num(group['Escalas'])+1;
      group['Movimientos']=_num(group['Movimientos'])+_num(metrics['movements']);
      final start=_date(scale['InicioRealUTC']);final end=_date(scale['FinRealUTC']);
      group['HorasReales']=_num(group['HorasReales'])+(start!=null && end!=null && end.isAfter(start)?end.difference(start).inSeconds/3600:0);
      group['HorasPerdidas']=_num(group['HorasPerdidas'])+_num(metrics['lostMinutes'])/60;
      final plan=await rows('PM_Estimados',scaleId:id);
      if(plan.isNotEmpty)group['HorasPlan']=_num(group['HorasPlan'])+_num(plan.first['HorasEstimadas']);
    }
    for(final group in groups.values){
      group['ProductividadPonderada']=_num(group['HorasReales'])>0?_num(group['Movimientos'])/_num(group['HorasReales']):null;
      group['DesviacionHoras']=_num(group['HorasReales'])-_num(group['HorasPlan']);
    }
    return groups.values.toList();
  }

  Future<List<Map<String,Object?>>> movementReport()=>_db.rawQuery('''
SELECT E.ID AS EscalaID,E.CallKey,B.NombreBuque,S.NombreServicio,
COALESCE(SUM(H.MovImp),0) AS MovImp,COALESCE(SUM(H.ExpFull),0) AS ExpFull,COALESCE(SUM(H.ExpVacio),0) AS ExpVacio,
COALESCE(SUM(H.RestowDown),0) AS RestowDown,COALESCE(SUM(H.RestowUp),0) AS RestowUp,COALESCE(SUM(H.MovTapas),0) AS MovTapas,COALESCE(SUM(H.MovEspeciales),0) AS MovEspeciales
FROM PM_Escalas E JOIN PM_Buques B ON E.BuqueID=B.ID
LEFT JOIN PM_Servicios S ON E.ServicioID=S.ID JOIN PM_Hourly H ON H.EscalaID=E.ID
WHERE E.EstadoProyecto='Cerrado' GROUP BY E.ID ORDER BY E.FechaCierreUTC DESC
''');

  Future<String> exportJson() async {
    return _db.transaction((tx) async {
      await _requireSupervisor(tx, capability: 'EXPORTAR');
      final data=<String,Object?>{};
      for(final table in tables.where((t)=>t.name!='PM_Credenciales')){
        data[table.name]=await tx.query(table.name,orderBy:'ID');
      }
      final result=const JsonEncoder.withIndent('  ').convert({'formato':'PM_BUQUES_SUPERVISOR_LOCAL_V1','exportadoUTC':_now(),'operadorConfigurado':_actorId,'sincronizacion':false,'datos':data});
      await _audit(tx,'EXPORTAR','PM_Eventos',0,null,{'formato':'JSON local'},null);
      return result;
    });
  }

  Future<void> close()=>_db.close();

  static Future<void> _seed(Database db) async {
    final repo=SupervisorRepository._(db).._actorId=1;
    final now=DateTime.now().toUtc();
    Future<int> insert(String table,Map<String,Object?> values) async {
      final data=repo._newRecord(repo._table(table))..addAll(values);
      return db.insert(table,data);
    }
    final managerRole=await insert('PM_Roles',{'CodigoRol':'GERENCIA','NombreRol':'Supervisor','Activo':1});
    final auditorRole=await insert('PM_Roles',{'CodigoRol':'AUDITOR','NombreRol':'Auditor','Activo':1});
    final manager=await insert('PM_Usuarios',{'UPN':'SUPERVISOR_DEMO_01','NombreMostrado':'Supervisor Demo','RolID':managerRole,'Activo':1,'AltaUTC':now.toIso8601String()});
    repo._actorId=manager;
    final auditor=await insert('PM_Usuarios',{'UPN':'AUDITOR_DEMO_01','NombreMostrado':'Auditor Demo 01','RolID':auditorRole,'Activo':1,'AltaUTC':now.toIso8601String()});
    await insert('PM_Usuarios',{'UPN':'AUDITOR_DEMO_02','NombreMostrado':'Auditor Demo 02','RolID':auditorRole,'Activo':1,'AltaUTC':now.toIso8601String()});
    await insert('PM_Equipos',{'InstalacionGUID':'DEMO_LOCAL_SUPERVISOR','UsuarioID':manager,'EquipoEtiqueta':'Teléfono Demo Supervisor','RegistradoUTC':now.toIso8601String(),'Activo':1});
    final equipment=await insert('PM_Equipos',{'InstalacionGUID':'DEMO_LOCAL_AUDITOR','UsuarioID':auditor,'EquipoEtiqueta':'Instalación Demo Auditor','RegistradoUTC':now.toIso8601String(),'Activo':1});
    final service=await insert('PM_Servicios',{'CodigoServicio':'DEMO_A','NombreServicio':'Servicio Demo A','VarianteCall':'Ruta Demo','AnticipacionHoras':48,'Activo':1});
    final port=await insert('PM_Puertos',{'CodigoPuerto':'DEMO','NombrePuerto':'Puerto Demo','Pais':'País Demo'});
    await insert('PM_Agentes',{'NombreAgente':'Agente Demo','Activo':1});
    await insert('PM_RutasServicio',{'ServicioID':service,'PuertoID':port,'Secuencia':1});
    await insert('PM_Criterios',{'CodigoCriterio':'CALIDAD','Nombre':'Calidad de información','Peso':1.0,'Activo':1});
    await insert('PM_CatalogoTareas',{'CodigoTarea':'VERIFICAR','Seccion':'Preplan','NombreTarea':'Verificar documentación del proyecto','Orden':1,'ObligatoriaDefecto':1,'CondicionAplica':'Siempre','Activa':1});
    final movementTypes=<String,int>{};
    for(final key in _groups.keys){movementTypes[key]=await insert('PM_TiposMovimiento',{'Codigo':key,'Grupo':'Operación','Nombre':key,'CuentaEnTotal':1,'Activo':1});}
    const milestoneData=<List<Object>>[
      ['EOSP','Arrival','Fin de navegación',0,0],
      ['VESSEL_ARRIVED','Arrival','Llegada del buque',1,0],
      ['PILOT_ON_BOARD_ARRIVAL','Arrival','Práctico a bordo de llegada',2,0],
      ['PASSING_BREAKWATER','Arrival','Paso del rompeolas',3,1],
      ['FIRST_LINE_ASHORE','Arrival','Primera línea en tierra',4,1],
      ['ALL_FAST','Arrival','Buque amarrado',5,0],
      ['GANGWAY_READY','Arrival','Escala lista',6,1],
      ['AUTHORITIES_ON_BOARD','Arrival','Autoridades a bordo',7,1],
      ['FREE_PRATIQUE','Arrival','Libre plática',8,1],
      ['COMPLETED_OPS','Departure','Operaciones terminadas',20,0],
      ['SEARCH_TEAM_ON_BOARD','Departure','Inspección a bordo',21,1],
      ['SEARCH_TEAM_COMPLETED','Departure','Inspección terminada',22,1],
      ['PILOT_ON_BOARD_DEPART','Departure','Práctico a bordo de salida',23,0],
      ['VESSEL_UNDOCKED','Departure','Buque desatracado',24,0],
      ['PILOT_OFF_SAILED','Departure','Salida del buque',25,0],
    ];
    final milestoneIds=<int>[];
    for(final type in milestoneData){milestoneIds.add(await insert('PM_TiposHito',{'Codigo':type[0],'ReporteTipo':type[1],'Descripcion':type[2],'Orden':type[3],'Obligatorio':1,'PermiteNA':type[4]}));}
    for(var i=1;i<=3;i++){
      final ship=await insert('PM_Buques',{'NombreBuque':'Buque Demo ${i.toString().padLeft(2,'0')}','Activo':1});
      final eta=i==1?now.add(const Duration(days:2)):now.subtract(Duration(hours:i==2?2:8));
      final status=i==1?'Pendiente':i==2?'EnProceso':'PendienteRevision';
      final start=now.subtract(const Duration(hours:8)).add(const Duration(minutes:75));
      final end=start.add(const Duration(hours:1));
      final scale=await insert('PM_Escalas',{'CallKey':'DEMO-00$i','BuqueID':ship,'Viaje':'Viaje Demo $i','FechaETA':eta.toIso8601String().split('T').first,'ETACompletaUTC':eta.toIso8601String(),'ServicioID':service,'EstadoProyecto':status,'VersionProyecto':1,'Muelle':'Muelle Demo $i','HoraLimiteFinUTC':now.add(const Duration(hours:4)).toIso8601String(),'LimiteInicioPlanUTC':eta.subtract(const Duration(hours:48)).toIso8601String(),'InicioRealUTC':i==1?null:start.toIso8601String(),'FinRealUTC':i==3?end.toIso8601String():null,'NotaGeneral':i==3?'Proyecto sintético listo para ensayar revisión.':'Datos locales de demostración.'});
      await repo._initializeScale(db,scale,initializeMaritime:false);
      await insert('PM_Asignaciones',{'EscalaID':scale,'UsuarioID':auditor,'TipoParticipacion':'Responsable','Vigente':1,'AsignadoPorID':manager,'AsignadoUTC':now.toIso8601String()});
      if(i==1)continue;
      await db.update('PM_Estimados',{'ImpFull':100,'ExpFull':100,'CuadrillasPrevistas':1,'ProductividadMeta':200.0,'HorasEstimadas':1.0,'InicioPrevistoUTC':start.toIso8601String(),'EstimadoCerrado':1,'CongeladoUTC':start.toIso8601String(),'ProductividadEstimadaBuque':200.0,'ETCEstimadoUTC':end.toIso8601String()},where:'EscalaID=?',whereArgs:[scale]);
      final gang=await insert('PM_EstimadoGang',{'EscalaID':scale,'CodigoGang':'Cuadrilla Demo 01','CodigoGrua':'Grúa Demo 01','MovimientosAsignados':200,'ProductividadMeta':200.0,'HorasPrevistas':1.0});
      final actual=i==3?200:80;
      final hour=await insert('PM_Hourly',{'EscalaID':scale,'HoraInicioUTC':start.toIso8601String(),'HoraFinUTC':end.toIso8601String(),'MovImp':i==3?100:40,'ExpFull':i==3?100:40,'MovEspeciales':0,'ActualizadoPorID':auditor,'ActualizadoUTC':end.toIso8601String(),'ClaveEscalaIntervalo':'$scale/${start.toIso8601String()}','ProductividadCorte':actual.toDouble(),'EstadoValidacion':'OK','PerdidaHoras':0,'PerdidaMinutos':0});
      await insert('PM_HourlyGang',{'HourlyID':hour,'GangID':gang,'MovimientosHora':actual,'RestantesAlCorte':200-actual});
      if(i==2){
        final session=await insert('PM_SesionesTrabajo',{'EscalaID':scale,'UsuarioID':auditor,'EquipoID':equipment,'InicioUTC':start.toIso8601String()});
        await db.update('PM_ControlEdicion',{'EstadoBloqueo':'Tomado','TitularUsuarioID':auditor,'SesionTrabajoID':session},where:'EscalaID=?',whereArgs:[scale]);
      }else{
        await db.update('PM_ControlEdicion',{'EstadoBloqueo':'EnRevision'},where:'EscalaID=?',whereArgs:[scale]);
        await db.update('PM_TareasProyecto',{'EstadoTarea':'Completada','RealizadaPorID':auditor,'RealizadaUTC':end.toIso8601String()},where:'EscalaID=?',whereArgs:[scale]);
        await db.update('PM_CierreHourly',{'Finalizado':1,'FinalizadoUTC':end.toIso8601String(),'FinalizadoPorID':auditor,'MovInicial':200,'MovReal':200,'MovExcluido':0,'SaldoFinal':0,'ProdRealFinal':200.0,'ProdEstimada':200.0},where:'EscalaID=?',whereArgs:[scale]);
        for(var j=0;j<milestoneIds.length;j++){
          await insert('PM_HitosBuque',{'EscalaID':scale,'TipoHitoID':milestoneIds[j],'FechaHoraUTC':now.subtract(const Duration(hours:8)).add(Duration(minutes:j*15)).toIso8601String(),'NoAplica':0,'Validacion':'OK','ActualizadoPorID':auditor});
        }
        for(final kind in ['Arrival','Departure']){
          await insert('PM_ReportesMaritimos',{'EscalaID':scale,'TipoReporte':kind,'EstadoReporte':'Validado','ValidadorID':auditor,'ValidadoUTC':now.toIso8601String(),'RemolcadoresQty':1,'RemolcadoresNombre':'Remolcador Demo','FuelOilMT':120.0,'DieselOilMT':20.0,'FreshWaterMT':30.0,'DraftFwdM':7.2,'DraftAftM':7.4,'PuertoAnteriorID':port,'PuertoSiguienteID':port,'Observaciones':'Registro de demostración local.'});
        }
      }
      await repo._audit(db,'DATOS_DEMO','PM_Escalas',scale,null,{'EstadoProyecto':status},scale);
    }
    // First launch requires an explicit configured-operator choice in the UI.
  }
}
