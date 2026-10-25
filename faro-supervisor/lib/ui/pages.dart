import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/supervisor_repository.dart';
import 'common.dart';
import 'record_editor.dart';
import 'project_detail.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({required this.repository, required this.openProjects, required this.onChanged, super.key});
  final SupervisorRepository repository;
  final void Function(String? state) openProjects;
  final VoidCallback onChanged;
  @override State<DashboardPage> createState() => _DashboardPageState();
}
class _DashboardPageState extends State<DashboardPage> {
  int _version = 0;
  Future<Map<String, Object?>> _load() async => {'counts': await widget.repository.counts(), 'projects': await widget.repository.projects(), 'tasks': await widget.repository.pendingTasks()};
  Future<void> _open(RowData project) async {
    await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => ProjectDetail(repository: widget.repository, projectId: intValue(project['ID']))));
    if (mounted) { setState(() => _version++); widget.onChanged(); }
  }
  @override Widget build(BuildContext context) => AsyncData<Map<String, Object?>>(version: _version, load: _load, builder: (context, data) {
    final counts = data['counts']! as Map<String, int>;
    final projects = data['projects']! as List<RowData>;
    final pending = data['tasks']! as List<RowData>;
    final open = projects.where((p) => p['EstadoProyecto'] != 'Cerrado').toList();
    final revision = projects.where((p) => p['EstadoProyecto'] == 'PendienteRevision').length;
    return RefreshIndicator(onRefresh: () async => setState(() => _version++), child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.only(bottom: 30), children: [
      PageHeader('Tu operación, a la vista', 'Supervisión de buques y decisiones pendientes.', action: IconButton(tooltip: 'Actualizar', onPressed: () => setState(() => _version++), icon: const Icon(Icons.refresh))),
      Container(margin: const EdgeInsets.fromLTRB(20, 0, 20, 18), padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(24)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Icon(Icons.radar, color: Color(0xff6fe0ce), size: 20), const SizedBox(width: 9), const Expanded(child: Text('CENTRO DE SUPERVISIÓN', style: TextStyle(color: Color(0xffa8ccc9), letterSpacing: 1.4, fontWeight: FontWeight.w700, fontSize: 11))), const SizedBox(width: 8), Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xff6fe0ce), shape: BoxShape.circle))]),
        const SizedBox(height: 22), Text('${open.length} ${open.length == 1 ? 'proyecto abierto' : 'proyectos abiertos'}', style: const TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w800, letterSpacing: -.7)), const SizedBox(height: 8),
        Text(revision == 0 ? 'Sin cierres esperando tu aprobación.' : '$revision ${revision == 1 ? 'cierre espera' : 'cierres esperan'} tu revisión.', style: const TextStyle(color: Color(0xffbacdd8), height: 1.5)),
        const SizedBox(height: 18), FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: const Color(0xff6fe0ce), foregroundColor: ink), onPressed: () => widget.openProjects(revision > 0 ? 'PendienteRevision' : null), icon: const Icon(Icons.arrow_forward, size: 18), label: Text(revision > 0 ? 'Revisar cierres' : 'Ver proyectos')),
      ])),
      SizedBox(height: 112, child: ListView(padding: const EdgeInsets.symmetric(horizontal: 20), scrollDirection: Axis.horizontal, children: [
        _kpi('Abiertos', open.length, Icons.directions_boat_outlined, 'Abiertos', teal),
        _kpi('En proceso', counts['EnProceso'] ?? projects.where((p) => p['EstadoProyecto'] == 'EnProceso').length, Icons.play_circle_outline, 'EnProceso', teal),
        _kpi('En pausa', counts['EnPausa'] ?? projects.where((p) => p['EstadoProyecto'] == 'EnPausa').length, Icons.pause_circle_outline, 'EnPausa', warm),
        _kpi('En revisión', counts['PendienteRevision'] ?? revision, Icons.fact_check_outlined, 'PendienteRevision', warm),
        _kpi('Cerrados', counts['Cerrado'] ?? projects.where((p) => p['EstadoProyecto'] == 'Cerrado').length, Icons.task_alt, 'Cerrado', const Color(0xff476e51)),
      ])),
      SectionTitle('Próximos proyectos', trailing: TextButton(onPressed: () => widget.openProjects(null), child: const Text('Ver todos'))),
      if (open.isEmpty) const EmptyState('Todo al día', 'No hay proyectos abiertos en este momento.', icon: Icons.task_alt) else ...open.take(4).map((p) => ProjectCard(project: p, onTap: () => _open(p))),
      const SectionTitle('Pendientes operativos'),
      if (pending.isEmpty) const SurfaceCard(child: Row(children: [Icon(Icons.check_circle_outline, color: teal), SizedBox(width: 12), Expanded(child: Text('No quedan tareas operativas pendientes.', style: TextStyle(color: muted)))])) else ...pending.take(5).map((p) => SurfaceCard(padding: EdgeInsets.zero, child: ListTile(
        leading: const Icon(Icons.checklist_outlined, color: warm), title: Text(text(p['TextoTarea']), maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(text(p['NombreBuque'] ?? p['CallKey'], 'Proyecto ${p['EscalaID']}')), trailing: const Icon(Icons.chevron_right),
        onTap: () => _open({'ID': p['EscalaID']}),
      ))),
    ]));
  });
  Widget _kpi(String label, int count, IconData icon, String? state, Color color) => Padding(padding: const EdgeInsets.only(right: 10), child: Material(color: Colors.white, borderRadius: BorderRadius.circular(17), child: InkWell(borderRadius: BorderRadius.circular(17), onTap: () => widget.openProjects(state), child: SizedBox(width: 125, child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, color: color, size: 18), const Spacer(), Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 23))]), const Spacer(), Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))]))))));
}

class ProjectsPage extends StatefulWidget {
  const ProjectsPage({required this.repository, this.initialStatus, this.filterVersion = 0, this.revision = 0, super.key});
  final SupervisorRepository repository;
  final String? initialStatus;
  final int filterVersion, revision;
  @override State<ProjectsPage> createState() => _ProjectsPageState();
}
class _ProjectsPageState extends State<ProjectsPage> {
  int _version = 0;
  String? _state;
  String _search = '';
  @override void initState() { super.initState(); _state = widget.initialStatus; }
  @override void didUpdateWidget(covariant ProjectsPage oldWidget) { super.didUpdateWidget(oldWidget); if (oldWidget.filterVersion != widget.filterVersion) _state = widget.initialStatus; if (oldWidget.filterVersion != widget.filterVersion || oldWidget.revision != widget.revision) _version++; }
  Future<void> _newProject() async {
    if (await editRecord(context, widget.repository, 'PM_Escalas') && mounted) setState(() => _version++);
  }
  @override Widget build(BuildContext context) => Column(children: [
    PageHeader('Proyectos', 'Itinerario completo, ordenado por llegada.', action: IconButton.filled(tooltip: 'Nueva escala', onPressed: _newProject, icon: const Icon(Icons.add))),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: TextField(onChanged: (v) => setState(() => _search = v.toLowerCase()), decoration: const InputDecoration(hintText: 'Buscar buque, call o viaje', prefixIcon: Icon(Icons.search)))),
    const SizedBox(height: 12), SizedBox(height: 46, child: ListView(padding: const EdgeInsets.symmetric(horizontal: 20), scrollDirection: Axis.horizontal, children: [
      _filter(null, 'Todos'), _filter('Abiertos', 'Abiertos'), ...['Pendiente', 'EnProceso', 'EnPausa', 'PendienteRevision', 'Devuelto', 'Cerrado'].map((s) => _filter(s, statusLabel(s))),
    ])), const SizedBox(height: 6),
    Expanded(child: AsyncData<List<RowData>>(version: _version, load: () => widget.repository.projects(), builder: (context, values) {
      final rows = values.where((r) => (_state == null || (_state == 'Abiertos' ? r['EstadoProyecto'] != 'Cerrado' : r['EstadoProyecto'] == _state)) && ['NombreBuque', 'CallKey', 'Viaje', 'NombreServicio'].any((k) => text(r[k], '').toLowerCase().contains(_search))).toList();
      if (rows.isEmpty) return EmptyState('No hay proyectos para mostrar', 'Cambia los filtros o crea una nueva escala.', icon: Icons.directions_boat_outlined, action: OutlinedButton.icon(onPressed: _newProject, icon: const Icon(Icons.add), label: const Text('Nueva escala')));
      return RefreshIndicator(onRefresh: () async => setState(() => _version++), child: ListView.builder(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.only(bottom: 20), itemCount: rows.length, itemBuilder: (context, i) => ProjectCard(project: rows[i], onTap: () async {
        await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => ProjectDetail(repository: widget.repository, projectId: intValue(rows[i]['ID']))));
        if (mounted) setState(() => _version++);
      })));
    })),
  ]);
  Widget _filter(String? value, String label) => Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(label), selected: _state == value, onSelected: (_) => setState(() => _state = value)));
}

class TeamPage extends StatefulWidget {
  const TeamPage({required this.repository, this.revision = 0, super.key});
  final SupervisorRepository repository;
  final int revision;
  @override State<TeamPage> createState() => _TeamPageState();
}
class _TeamPageState extends State<TeamPage> {
  int _version = 0;
  @override void didUpdateWidget(covariant TeamPage oldWidget) { super.didUpdateWidget(oldWidget); if (oldWidget.revision != widget.revision) _version++; }
  Future<void> _edit(RowData? row) async { if (await editRecord(context, widget.repository, 'PM_Usuarios', record: row) && mounted) setState(() => _version++); }
  @override Widget build(BuildContext context) => Column(children: [
    PageHeader('Equipo', 'Operadores, funciones y participación.', action: IconButton.filled(tooltip: 'Agregar operador', onPressed: () => _edit(null), icon: const Icon(Icons.person_add_alt))),
    Expanded(child: AsyncData<List<RowData>>(version: _version, load: () => widget.repository.rows('PM_Usuarios'), builder: (context, users) => ListView(padding: const EdgeInsets.only(bottom: 25), children: [
      const SurfaceCard(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.info_outline, color: teal, size: 20), SizedBox(width: 10), Expanded(child: Text('El perfil identifica al operador configurado. No se guardan contraseñas propias ni se verifica su identidad.', style: TextStyle(color: muted, height: 1.5)))])),
      ...users.map((u) {
        final active = intValue(u['Activo']) == 1;
        return SurfaceCard(padding: EdgeInsets.zero, child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 10), leading: CircleAvatar(backgroundColor: active ? teal.withValues(alpha: .10) : Colors.grey.shade100, child: Text(text(u['NombreMostrado'], '?').substring(0, 1).toUpperCase(), style: TextStyle(color: active ? teal : muted, fontWeight: FontWeight.w800))),
          title: Text(text(u['NombreMostrado']), style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text('${text(u['UPN'])}\n${active ? 'Activo' : 'Desactivado'}', style: TextStyle(height: 1.6, color: active ? muted : danger)), isThreeLine: true, trailing: const Icon(Icons.edit_outlined, size: 20), onTap: () => _edit(u)));
      }),
      const SectionTitle('Administración del equipo'),
      _link(Icons.assignment_ind_outlined, 'Asignaciones de proyectos', 'PM_Asignaciones'), _link(Icons.stars_outlined, 'Evaluaciones', 'PM_Evaluaciones'), _link(Icons.phone_android, 'Instalaciones registradas', 'PM_Equipos'),
    ]))),
  ]);
  Widget _link(IconData icon, String label, String table) => SurfaceCard(padding: EdgeInsets.zero, child: ListTile(leading: Icon(icon, color: teal), title: Text(label), trailing: const Icon(Icons.chevron_right), onTap: () async { await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => CatalogPage(repository: widget.repository, tableName: table, title: label))); if (mounted) setState(() => _version++); }));
}

class ReportsPage extends StatefulWidget {
  const ReportsPage({required this.repository, this.revision = 0, super.key});
  final SupervisorRepository repository;
  final int revision;
  @override State<ReportsPage> createState() => _ReportsPageState();
}
class _ReportsPageState extends State<ReportsPage> {
  int _version = 0, _tab = 0;
  @override void didUpdateWidget(covariant ReportsPage oldWidget) { super.didUpdateWidget(oldWidget); if (oldWidget.revision != widget.revision) _version++; }
  String _search = '';
  @override Widget build(BuildContext context) => Column(children: [
    PageHeader('Informes', 'Datos operativos e historial del supervisor.', action: IconButton(tooltip: 'Actualizar informes', onPressed: () => setState(() => _version++), icon: const Icon(Icons.refresh))),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: SegmentedButton<int>(segments: const [ButtonSegment(value: 0, label: Text('Servicio'), icon: Icon(Icons.bar_chart)), ButtonSegment(value: 1, label: Text('Movimientos'), icon: Icon(Icons.swap_vert)), ButtonSegment(value: 2, label: Text('Historial'), icon: Icon(Icons.history))], selected: {_tab}, showSelectedIcon: false, onSelectionChanged: (v) => setState(() { _tab = v.first; _version++; _search = ''; })))),
    if (_tab == 2) Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 6), child: TextField(key: ValueKey(_tab), onChanged: (v) => setState(() => _search = v.toLowerCase()), decoration: const InputDecoration(hintText: 'Buscar evento u operador', prefixIcon: Icon(Icons.search)))),
    const SizedBox(height: 12), Expanded(child: AsyncData<List<RowData>>(version: _version, load: () => _tab == 0 ? widget.repository.serviceReport() : _tab == 1 ? widget.repository.movementReport() : widget.repository.audit(), builder: (context, values) {
      final rows = values.where((r) => r.values.any((v) => '$v'.toLowerCase().contains(_search))).toList();
      if (rows.isEmpty) return EmptyState(_tab == 2 ? 'Sin eventos para mostrar' : 'Todavía no hay datos para el informe', _tab == 2 ? 'Prueba con otra búsqueda.' : 'Los resultados aparecerán al registrar operación y cerrar proyectos.', icon: Icons.analytics_outlined);
      return ListView(padding: const EdgeInsets.only(bottom: 25), children: [
        if (_tab == 0) const Padding(padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8), child: Text('La productividad se pondera por tiempo real; no es una calificación automática del auditor.', style: TextStyle(color: muted, height: 1.4))),
        ...rows.map((row) => SurfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_reportTitle(row), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), const SizedBox(height: 10),
          ...row.entries.where((e) => !['ID', 'EscalaID', 'ServicioID', 'ActorID', 'EquipoID', 'CorrelacionGUID', 'Antes', 'Despues', 'NombreServicio', 'NombreBuque', 'EventoCodigo'].contains(e.key) && e.value != null).take(_tab == 2 ? 5 : 12).map((e) => KeyValue(_reportLabel(e.key), _reportValue(e.key, e.value))),
          if (_tab == 2 && row['Despues'] != null) ExpansionTile(tilePadding: EdgeInsets.zero, title: const Text('Detalle del cambio', style: TextStyle(fontSize: 13)), children: [Align(alignment: Alignment.centerLeft, child: SelectableText(text(row['Despues']), style: const TextStyle(color: muted, fontSize: 12, height: 1.4)))]),
        ]))),
      ]);
    })),
  ]);
  String _reportTitle(RowData row) => text(row[_tab == 0 ? 'NombreServicio' : _tab == 1 ? 'NombreBuque' : 'EventoCodigo'], _tab == 2 ? 'Evento' : 'Resultado');
  String _reportLabel(String key) => const {'ProductividadPonderada': 'Productividad ponderada', 'Productividad': 'Productividad', 'HorasOperacion': 'Horas de operación', 'HorasReales': 'Horas reales', 'HorasPlan': 'Horas previstas', 'HorasPerdidas': 'Tiempo perdido (h)', 'DesviacionHoras': 'Desviación (h)', 'Movimientos': 'Movimientos', 'Escalas': 'Escalas', 'FechaUTC': 'Fecha y hora', 'ActorNombre': 'Operador', 'Resultado': 'Resultado', 'Entidad': 'Entidad', 'RegistroID': 'Registro', 'Origen': 'Origen', 'TipoEvento': 'Tipo', 'ImportTotal': 'Importación', 'ExportFull': 'Exportación llena', 'ExportVacio': 'Exportación vacía', 'MovImp': 'Importación', 'ExpFull': 'Exportación llena', 'ExpVacio': 'Exportación vacía', 'RestowDown': 'Restow bajada', 'RestowUp': 'Restow subida', 'Tapas': 'Tapas', 'Especiales': 'Especiales', 'MovTapas': 'Tapas', 'MovEspeciales': 'Especiales'}[key] ?? key.replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}');
  String _reportValue(String key, Object? value) => key.contains('UTC') ? dateText(value) : value is double ? value.toStringAsFixed(2) : text(value);
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({required this.repository, required this.switchProfile, super.key});
  final SupervisorRepository repository;
  final VoidCallback switchProfile;
  @override State<SettingsPage> createState() => _SettingsPageState();
}
class _SettingsPageState extends State<SettingsPage> {
  bool _exporting = false;
  Future<void> _backup() async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Exportar copia de datos'), content: const Text('Se copiarán los datos operativos y el historial al portapapeles. Podrás pegarlos en un archivo que tú elijas. Esta versión no restaura copias desde archivos. El portapapeles puede ser leído por otras aplicaciones; conserva el respaldo en un lugar privado.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Copiar datos'))]));
    if (confirmed != true || !mounted) return;
    setState(() => _exporting = true);
    try { final data = await widget.repository.exportJson(); await Clipboard.setData(ClipboardData(text: data)); if (mounted) notify(context, 'Datos copiados. Pégalos en un archivo privado.'); }
    catch (error) { if (mounted) notify(context, readableError(error), error: true); }
    finally { if (mounted) setState(() => _exporting = false); }
  }
  Future<void> _openCatalogs() async {
    const names = ['PM_Buques', 'PM_Servicios', 'PM_Agentes', 'PM_Puertos', 'PM_RutasServicio', 'PM_Roles', 'PM_PermisosRol', 'PM_CatalogoTareas', 'PM_Criterios', 'PM_TiposMovimiento', 'PM_TiposHito', 'PM_CatalogoParametros'];
    final options = widget.repository.tables.where((t) => names.contains(t.name)).toList();
    await showModalBottomSheet<void>(context: context, showDragHandle: true, isScrollControlled: true, builder: (context) => SafeArea(child: SizedBox(height: MediaQuery.sizeOf(context).height * .75, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Padding(padding: EdgeInsets.fromLTRB(22, 4, 22, 16), child: Text('Catálogos y parámetros', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800))),
      Expanded(child: ListView(children: options.map((t) => ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 22), title: Text(t.label), trailing: const Icon(Icons.chevron_right), onTap: () { Navigator.pop(context); Navigator.of(this.context).push<void>(MaterialPageRoute(builder: (_) => CatalogPage(repository: widget.repository, tableName: t.name))); })).toList())),
    ]))));
  }
  @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.only(bottom: 35), children: [
    const PageHeader('Ajustes', 'Configuración del dispositivo y de la operación.'),
    const SurfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(Icons.phone_android, color: teal), SizedBox(width: 10), Expanded(child: Text('Datos locales en este teléfono', style: TextStyle(fontWeight: FontWeight.w800)))]), const SizedBox(height: 12),
      Text('Esta prueba guarda la información en el dispositivo. No se sincroniza con otros teléfonos, Microsoft Lists ni Access.', style: TextStyle(color: muted, height: 1.5)),
    ])),
    SurfaceCard(padding: EdgeInsets.zero, child: Column(children: [
      ListTile(leading: const Icon(Icons.person_outline, color: teal), title: const Text('Cambiar responsable'), subtitle: const Text('Perfil configurado, sin contraseña propia'), trailing: const Icon(Icons.chevron_right), onTap: widget.switchProfile),
      const Divider(height: 1, indent: 16, endIndent: 16), ListTile(leading: const Icon(Icons.tune, color: teal), title: const Text('Catálogos y parámetros'), subtitle: const Text('Buques, servicios, tareas, hitos y criterios'), trailing: const Icon(Icons.chevron_right), onTap: _openCatalogs),
      const Divider(height: 1, indent: 16, endIndent: 16), ListTile(leading: const Icon(Icons.copy_all_outlined, color: teal), title: Text(_exporting ? 'Preparando copia…' : 'Exportar copia de datos'), subtitle: const Text('Acción manual; no se envía a internet'), trailing: _exporting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.chevron_right), onTap: _exporting ? null : _backup),
    ])),
    const SectionTitle('Privacidad y uso'),
    const SurfaceCard(child: Text('La aplicación registra el operador seleccionado y los cambios de negocio. Esa selección no verifica la identidad de la persona. No incorpora publicidad ni analítica externa. Evita datos personales innecesarios y conserva las copias de respaldo bajo tu control.', style: TextStyle(color: muted, height: 1.6))),
    const Center(child: Padding(padding: EdgeInsets.only(top: 20), child: Text('Faro · Supervisor Portuario\nEdición local de prueba', textAlign: TextAlign.center, style: TextStyle(color: muted, height: 1.8, fontSize: 12)))),
  ]);
}
