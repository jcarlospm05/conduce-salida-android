"""Generate Flutter/SQLite metadata from the PM Buques canonical contracts.

No network access. Run `python3 tool/generate_schema.py` from any directory.
"""
from pathlib import Path
import json,re,sqlite3

ROOT=Path(__file__).resolve().parents[1]
REFERENCE=ROOT/'tool/reference'
MODEL=json.loads((REFERENCE/'model.json').read_text())
EXT=json.loads((REFERENCE/'extensions.json').read_text())
FIELDS=[dict(f) for f in MODEL['contratos_campos']]+[dict(f) for f in EXT['fields']]
for override in EXT.get('required_overrides',[]):
    for field in FIELDS:
        if (field['tabla'],field['campo'])==(override['tabla'],override['campo']):
            field['requerido']=override['requerido']
RELATIONS=MODEL['relaciones']+EXT['relations']
REFS={(r['origen'],r['campo']):r['destino'] for r in RELATIONS}
TYPE={'dbLong':'integer','dbDouble':'real','dbText':'text','dbMemo':'memo','dbDate':'date','dbBoolean':'boolean'}
TABLE_LABELS={
'PM_Roles':'Roles','PM_Usuarios':'Operadores','PM_Credenciales':'Credenciales heredadas',
'PM_Equipos':'Instalaciones','PM_Buques':'Buques','PM_Escalas':'Proyectos / escalas',
'PM_ETA_Historial':'Cambios de ETA','PM_Asignaciones':'Asignaciones','PM_ControlEdicion':'Ocupación',
'PM_SesionesTrabajo':'Sesiones de trabajo','PM_CatalogoTareas':'Plantilla de tareas',
'PM_TareasProyecto':'Tareas e instrucciones','PM_Estimados':'Estimados','PM_VaciosDestino':'Vacíos por destino',
'PM_Hourly':'Hourly','PM_Eventos':'Historial de acciones','PM_Relevos':'Relevos','PM_Revisiones':'Revisiones',
'PM_Criterios':'Criterios de evaluación','PM_Evaluaciones':'Evaluaciones','PM_PermisosRol':'Permisos de aplicación',
'PM_Servicios':'Servicios','PM_Agentes':'Agentes','PM_Puertos':'Puertos','PM_RutasServicio':'Rutas de servicio',
'PM_EstimadoGang':'Cuadrillas planificadas','PM_EstimadoGangDetalle':'Plan de cuadrilla por movimiento',
'PM_TiposMovimiento':'Tipos de movimiento','PM_HourlyGang':'Reparto Hourly por cuadrilla',
'PM_Exclusiones':'Exclusiones de movimientos','PM_CierreHourly':'Cierre de Hourly','PM_TiposHito':'Tipos de hito',
'PM_HitosBuque':'Hitos de llegada y salida','PM_ReportesMaritimos':'Arrival / Departure',
'PM_IncidenciasValidacion':'Incidencias de validación','PM_CatalogoParametros':'Parámetros'}
SYSTEM_FIELDS={'ID','CreadaPorID','CreadaUTC','RealizadaPorID','RealizadaUTC',
'ActualizadoPorID','ActualizadoUTC','AltaUTC','BajaUTC','RegistradoUTC','RegistradaUTC',
'VerificadoPorID','InstalacionGUID','FechaUTC','AsignadoPorID','AsignadoUTC','FinAsignacionUTC',
'ModificadoPorID','ModificadoUTC','ActorID','GerenteID','FechaCierreUTC','CerradoPorID',
'EstadoProyecto','VersionProyecto','UltimoCambioUTC','VersionControl','CongeladoUTC','EstimadoCerrado',
'ProductividadCorte','ETCProyectadoUTC','EstadoValidacion','ClaveEscalaIntervalo','ValidadorID','ValidadoUTC',
'EstadoReporte','Validacion','ProductividadEstimadaBuque','ETCEstimadoUTC','HorasEstimadas',
'HoraLimiteOriginalUTC','RevisadoPorID'}
NONEDITABLE={'PM_Credenciales','PM_Eventos','PM_ControlEdicion','PM_SesionesTrabajo','PM_Relevos',
'PM_Revisiones','PM_CierreHourly','PM_ETA_Historial','PM_TiposHito'}
UNIQUE={
'PM_Roles':[['CodigoRol']], 'PM_Usuarios':[['UPN']], 'PM_Equipos':[['InstalacionGUID']],
'PM_PermisosRol':[['RolID','CodigoPermiso']],
'PM_Escalas':[['CallKey']], 'PM_ControlEdicion':[['EscalaID']], 'PM_Estimados':[['EscalaID']],
'PM_CierreHourly':[['EscalaID']], 'PM_Hourly':[['ClaveEscalaIntervalo']],
'PM_HitosBuque':[['EscalaID','TipoHitoID']], 'PM_ReportesMaritimos':[['EscalaID','TipoReporte']],
'PM_HourlyGang':[['HourlyID','GangID']],
}
LABELS={'UPN':'Código único del operador','RolID':'Rol','EscalaID':'Proyecto',
'BuqueID':'Buque','UsuarioID':'Operador','GerenteID':'Supervisor','AuditorID':'Auditor',
'FechaETA':'Fecha ETA','ETACompletaUTC':'ETA completa (UTC)','CallKey':'Código de visita',
'TipoHitoID':'Tipo de hito','TipoMovimientoID':'Tipo de movimiento','GangID':'Cuadrilla',
'HourlyID':'Intervalo Hourly','PuertoID':'Puerto','ServicioID':'Servicio','AgenteID':'Agente',
'CatálogoTareaID':'Tarea del catálogo','CatalogoTareaID':'Tarea del catálogo',
'PM':'PM','NoAplica':'No aplica','EstadoTarea':'Estado de tarea','TextoTarea':'Instrucción / tarea',
'PerdidaHoras':'Tiempo perdido (horas)','PerdidaMinutos':'Tiempo perdido (minutos)',
'CodigoGang':'Código de cuadrilla','MovimientosHora':'Movimientos del intervalo',
'MovImp':'Importación','ExpFull':'Exportación llena','ExpVacio':'Exportación vacía',
'NombreMostrado':'Nombre visible','UPN':'Código de operador (no contraseña)'}
def label(name):
    if name in LABELS:return LABELS[name]
    s=re.sub(r'([a-záéíóúñ])([A-Z])',r'\1 \2',name)
    s=s.replace('ID',' ID').replace('UTC',' UTC')
    return ' '.join(s.split())
def default(field):
    value=field.get('default')
    if field['pk']:return None
    if value in (None,'','SharePoint'):
        return False if TYPE[field['tipo_access']]=='boolean' else None
    typ=TYPE[field['tipo_access']]
    if typ=='integer':return int(value)
    if typ=='real':return float(value)
    if typ=='boolean':return str(value).lower() in {'true','yes','sí','si','1','-1'}
    return str(value)
def quote(value):return json.dumps(value,ensure_ascii=False).replace('$','\\$')
def dart_value(value):
    if value is None:return 'null'
    if isinstance(value,bool):return 'true' if value else 'false'
    if isinstance(value,(int,float)):return str(value)
    return quote(value)
def sql_default(value):
    if isinstance(value,bool):return '1' if value else '0'
    if isinstance(value,(int,float)):return str(value)
    return "'"+str(value).replace("'","''")+"'"
def statements():
    result=[]
    for table in MODEL['tablas']:
        columns=[]
        for f in FIELDS:
            if f['tabla']!=table:continue
            n=f['campo'];typ=TYPE[f['tipo_access']]
            if f['pk']:columns.append(f'"{n}" INTEGER PRIMARY KEY AUTOINCREMENT');continue
            sql_type={'integer':'INTEGER','boolean':'INTEGER','real':'REAL','date':'TEXT','text':'TEXT','memo':'TEXT'}[typ]
            part=f'"{n}" {sql_type}'
            if f['requerido']:part+=' NOT NULL'
            d=default(f)
            if d is not None:part+=' DEFAULT '+sql_default(d)
            if typ=='boolean':part+=f' CHECK ("{n}" IN (0,1))'
            elif typ=='integer':part+=f' CHECK ("{n}" IS NULL OR (typeof("{n}")=\'integer\' AND "{n}">=0))'
            elif typ=='real':part+=f' CHECK ("{n}" IS NULL OR (typeof("{n}") IN (\'real\',\'integer\') AND "{n}">=0))'
            columns.append(part)
        for rel in RELATIONS:
            if rel['origen']==table:
                columns.append(f'FOREIGN KEY ("{rel["campo"]}") REFERENCES "{rel["destino"]}"("{rel["clave"]}") ON DELETE RESTRICT')
        for names in UNIQUE.get(table,[]):columns.append('UNIQUE ('+','.join('"'+n+'"' for n in names)+')')
        result.append('CREATE TABLE "'+table+'" (\n  '+',\n  '.join(columns)+'\n)')
    for rel in RELATIONS:
        result.append(f'CREATE INDEX "IX_{rel["origen"]}_{rel["campo"]}" ON "{rel["origen"]}"("{rel["campo"]}")')
    result.extend([
      'CREATE INDEX "IX_PM_Escalas_EstadoProyecto" ON "PM_Escalas"("EstadoProyecto")',
      'CREATE INDEX "IX_PM_Escalas_FechaETA" ON "PM_Escalas"("FechaETA")',
      'CREATE INDEX "IX_PM_Eventos_FechaUTC" ON "PM_Eventos"("FechaUTC")',
      'CREATE TABLE local_settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
    ])
    return result

def generate():
    body='''// Generated by tool/generate_schema.py. Edit the canonical references, then regenerate.
// SQLite schema preserves the 36 original PM tables, with the GangID extension.

class FieldSpec {
  final String name;
  final String label;
  final String type;
  final bool required;
  final bool system;
  final String? references;
  final Object? defaultValue;
  const FieldSpec({required this.name, required this.label, required this.type,
    this.required = false, this.system = false, this.references, this.defaultValue});
}

class TableSpec {
  final String name;
  final String label;
  final List<FieldSpec> fields;
  final bool editable;
  const TableSpec({required this.name, required this.label, required this.fields,
    this.editable = true});
  FieldSpec? field(String name) {
    for (final field in fields) {
      if (field.name == name) return field;
    }
    return null;
  }
}

const List<TableSpec> supervisorSchema = [
'''
    for table in MODEL['tablas']:
        body+='  TableSpec(name: '+quote(table)+', label: '+quote(TABLE_LABELS[table])+', editable: '+str(table not in NONEDITABLE).lower()+', fields: [\n'
        for f in FIELDS:
            if f['tabla']!=table:continue
            n=f['campo'];args=[f'name: {quote(n)}',f'label: {quote(label(n))}',f'type: {quote(TYPE[f["tipo_access"]])}']
            if f['requerido']:args.append('required: true')
            if n in SYSTEM_FIELDS or table in NONEDITABLE:args.append('system: true')
            if (table,n) in REFS:args.append('references: '+quote(REFS[(table,n)]))
            d=default(f)
            if d is not None:args.append('defaultValue: '+dart_value(d))
            body+='    FieldSpec('+', '.join(args)+'),\n'
        body+='  ]),\n'
    body+='];\n\nList<String> createSchemaStatements() => [\n'
    for stmt in statements():body+='  '+quote(stmt)+',\n'
    body+='];\n'
    path=ROOT/'lib/data/schema.dart';path.parent.mkdir(parents=True,exist_ok=True);path.write_text(body)
    (ROOT/'tool/schema.sql').write_text('-- Generated SQLite schema. No live data or secrets.\nPRAGMA foreign_keys=ON;\n\n'+';\n\n'.join(statements())+';\n')
    db=sqlite3.connect(':memory:');db.execute('PRAGMA foreign_keys=ON')
    for stmt in statements():db.execute(stmt)
    count=sum(len(db.execute(f'PRAGMA table_info("{t}")').fetchall()) for t in MODEL['tablas'])
    fk=sum(len(db.execute(f'PRAGMA foreign_key_list("{t}")').fetchall()) for t in MODEL['tablas'])
    assert len(MODEL['tablas'])==36 and count==323 and fk==66
    assert db.execute('PRAGMA foreign_key_check').fetchall()==[]
    db.close()
    print(f'Generated and SQLite-validated: 36 tables, {count} fields, {fk} foreign keys')
if __name__=='__main__':generate()
