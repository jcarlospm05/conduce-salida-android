import 'package:flutter/material.dart';
import '../data/supervisor_repository.dart';
import 'common.dart';
import 'record_editor.dart';

class ProjectDetail extends StatefulWidget {
  const ProjectDetail({required this.repository, required this.projectId, super.key});
  final SupervisorRepository repository;
  final int projectId;
  @override State<ProjectDetail> createState() => _ProjectDetailState();
}
class _ProjectDetailState extends State<ProjectDetail> {
  int _version = 0;
  bool _busy = false;
  Future<Map<String, Object?>> _load() async {
    final results = await Future.wait<Object?>([
      widget.repository.project(widget.projectId),
      widget.repository.projectMetrics(widget.projectId),
      widget.repository.rows('PM_TareasProyecto', scaleId: widget.projectId),
      widget.repository.rows('PM_Hourly', scaleId: widget.projectId),
      widget.repository.audit(scaleId: widget.projectId),
      widget.repository.closeProblems(widget.projectId),
      widget.repository.rows('PM_ControlEdicion', scaleId: widget.projectId),
    ]);
    return {'project': results[0], 'metrics': results[1], 'tasks': results[2], 'hourly': results[3], 'audit': results[4], 'problems': results[5], 'control': results[6]};
  }
  Future<void> _perform(Future<void> Function() action, String success) async {
    if (_busy) return;
    setState(() => _busy = true);
    try { await action(); if (mounted) { setState(() => _version++); notify(context, success); } }
    catch (error) { if (mounted) notify(context, readableError(error), error: true); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _edit(String table, {RowData? row}) async {
    if (await editRecord(context, widget.repository, table, record: row, scaleId: table == 'PM_Escalas' ? null : widget.projectId)) {
      if (mounted) setState(() => _version++);
    }
  }
  Future<void> _catalog(String table, String title) async {
    await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => CatalogPage(repository: widget.repository, tableName: table, scaleId: widget.projectId, title: title)));
    if (mounted) setState(() => _version++);
  }
  Future<void> _instruction() async {
    final result = await showDialog<Map<String, Object?>>(context: context, builder: (_) => const _InstructionDialog());
    if (result != null && mounted) await _perform(() => widget.repository.addInstruction(widget.projectId, result['text']! as String, required: result['required']! as bool), 'Instrucción agregada');
  }
  Future<void> _assign() async {
    try {
      final users = await widget.repository.rows('PM_Usuarios');
      final roles = await widget.repository.rows('PM_Roles');
      final auditorRoles = roles.where((r) => r['CodigoRol'] == 'AUDITOR' && intValue(r['Activo']) == 1).map((r) => intValue(r['ID'])).toSet();
      if (!mounted) return;
      final available = users.where((u) => intValue(u['Activo']) == 1 && auditorRoles.contains(intValue(u['RolID']))).toList();
      if (available.isEmpty) { notify(context, 'No hay auditores activos. Crea o activa uno desde Equipo.'); return; }
      final selected = await showDialog<int>(context: context, builder: (context) => SimpleDialog(title: const Text('Asignar auditor'), children: available.map((u) => SimpleDialogOption(onPressed: () => Navigator.pop(context, intValue(u['ID'])), child: Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Text(rowLabel(u))))).toList()));
      if (selected != null && mounted) await _perform(() => widget.repository.assign(widget.projectId, selected), 'Asignación registrada');
    } catch (error) { if (mounted) notify(context, readableError(error), error: true); }
  }
  Future<void> _review(String decision) async {
    final titles = {'APROBAR': 'Aprobar cierre', 'DEVOLVER': 'Devolver al auditor', 'REABRIR': 'Reabrir proyecto'};
    final reason = await askReason(context, title: titles[decision]!, action: titles[decision]!);
    if (reason != null && mounted) await _perform(() => widget.repository.review(widget.projectId, decision, reason), 'Decisión registrada en el historial');
  }
  Future<void> _release() async {
    final reason = await askReason(context, title: 'Liberar ocupación', hint: 'Confirma primero que el titular ya no está trabajando y explica el motivo.', action: 'Liberar');
    if (reason != null && mounted) await _perform(() => widget.repository.release(widget.projectId, reason), 'Ocupación liberada');
  }
  Future<void> _confirmOperation(String title, String message, Future<void> Function() operation, String success) async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: Text(title), content: Text(message), actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirmar')),
      ],
    ));
    if (confirmed == true && mounted) await _perform(operation, success);
  }
  Future<void> _pause() async {
    final reason = await askReason(context, title: 'Pausa y entrega', hint: 'Deja una observación para quien retome el proyecto.', action: 'Pausar');
    if (reason != null && mounted) await _perform(() => widget.repository.pause(widget.projectId, reason), 'Proyecto en pausa; ocupación liberada');
  }
  @override Widget build(BuildContext context) => DefaultTabController(length: 5, child: Scaffold(
    appBar: AppBar(title: const Text('Expediente del buque', maxLines: 1, overflow: TextOverflow.ellipsis), actions: [IconButton(tooltip: 'Actualizar expediente', onPressed: _busy ? null : () => setState(() => _version++), icon: const Icon(Icons.refresh))], bottom: const TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [Tab(text: 'Resumen'), Tab(text: 'Operación'), Tab(text: 'Tareas'), Tab(text: 'Revisión'), Tab(text: 'Historial')])),
    body: Column(children: [if (_busy) const LinearProgressIndicator(minHeight: 3), Expanded(child: AsyncData<Map<String, Object?>>(version: _version, load: _load, builder: (context, data) {
      final project = data['project']! as RowData;
      final metrics = data['metrics']! as RowData;
      final tasks = data['tasks']! as List<RowData>;
      final hourly = data['hourly']! as List<RowData>;
      final audit = data['audit']! as List<RowData>;
      final problems = data['problems']! as List<String>;
      final controls = data['control']! as List<RowData>;
      final control = controls.isEmpty ? <String, Object?>{} : controls.first;
      final ownOperation = project['EstadoProyecto'] == 'EnProceso' && control['EstadoBloqueo'] == 'Tomado' && intValue(control['TitularUsuarioID']) == widget.repository.actorId;
      return TabBarView(children: [_overview(project, metrics, control, ownOperation), _operations(project, metrics, hourly, ownOperation), _tasks(tasks), _reviewPage(project, problems), _audit(audit)]);
    }))]),
  ));
  Widget _overview(RowData p, RowData metrics, RowData control, bool ownOperation) {
    final done = intValue(metrics['checklistDone']), total = intValue(metrics['checklistTotal']);
    final moves = number(metrics['movements']), plan = number(metrics['planMovements']);
    return ListView(padding: const EdgeInsets.only(bottom: 30), children: [
      PageHeader(text(p['NombreBuque'], 'Buque'), '${text(p['CallKey'])} · ${text(p['NombreServicio'], 'Servicio por definir')}', action: IconButton(tooltip: 'Editar escala o ETA', onPressed: _busy ? null : () => _edit('PM_Escalas', row: p), icon: const Icon(Icons.edit_outlined))),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Wrap(spacing: 8, runSpacing: 8, children: [StatusPill(text(p['EstadoProyecto'])), if (p['TitularNombre'] != null) Chip(avatar: const Icon(Icons.person_outline, size: 17), label: Text(text(p['TitularNombre'])))])),
      SurfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(ownOperation ? 'Tienes la operación activa en este perfil.' : control['EstadoBloqueo'] == 'Tomado' ? 'Ocupado por otro operador. Puedes consultar y supervisar.' : p['EstadoProyecto'] == 'Cerrado' ? 'Proyecto cerrado. La revisión y sus decisiones se conservan en el historial.' : p['EstadoProyecto'] == 'PendienteRevision' ? 'Proyecto pendiente de decisión del supervisor.' : 'Inicia el proyecto para registrar la operación local.', style: const TextStyle(color: muted, height: 1.5)),
        const SizedBox(height: 12),
        if (['Pendiente', 'EnPausa', 'Devuelto'].contains(p['EstadoProyecto']) && control['EstadoBloqueo'] != 'Tomado')
          FilledButton.icon(onPressed: _busy ? null : () => _perform(() => widget.repository.start(widget.projectId), 'Operación iniciada con el responsable actual'), icon: const Icon(Icons.play_arrow), label: const Text('Tomar / iniciar operación')),
        if (ownOperation) OutlinedButton.icon(onPressed: _busy ? null : _pause, icon: const Icon(Icons.pause_circle_outline), label: const Text('Pausa y entrega')),
      ])),
      const SizedBox(height: 12), Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(children: [Expanded(child: MetricTile('Checklist obligatorio', '$done / $total', icon: Icons.fact_check_outlined)), const SizedBox(width: 12), Expanded(child: MetricTile('Movimientos / plan', '${moves.toStringAsFixed(0)} / ${plan.toStringAsFixed(0)}', icon: Icons.swap_vert, color: const Color(0xff415f87)))])),
      SurfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Dos avances, dos medidas', style: TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 16),
        _progress('Checklist', total > 0 ? done / total : 0, '$done de $total tareas', teal), const SizedBox(height: 18),
        _progress('Operación', plan > 0 ? moves / plan : 0, '${moves.toStringAsFixed(0)} de ${plan.toStringAsFixed(0)} movimientos', const Color(0xff415f87)),
      ])),
      const SectionTitle('Itinerario y tiempo'),
      SurfaceCard(child: Column(children: [
        KeyValue('Llegada prevista · ETA', dateText(p['ETACompletaUTC'] ?? p['FechaETA'], time: p['ETACompletaUTC'] != null)),
        if (p['ETACompletaUTC'] == null) const Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Hora de llegada por confirmar', style: TextStyle(color: warm)))),
        KeyValue('Viaje', text(p['Viaje'])), KeyValue('Muelle', text(p['Muelle'])),
        Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: () => _catalog('PM_ETA_Historial', 'Cambios de ETA'), icon: const Icon(Icons.history, size: 17), label: const Text('Ver cambios de ETA'))),
        KeyValue('ETC previsto', dateText(metrics['planEtc'])), KeyValue('ETC proyectado', dateText(metrics['etc'])),
        KeyValue('Hora límite', dateText(metrics['limit'] ?? p['HoraLimiteFinUTC'])),
        KeyValue('Productividad', metrics['productivity'] == null ? 'Sin producción suficiente' : '${number(metrics['productivity']).toStringAsFixed(1)} mov/h'),
        KeyValue('Tiempo perdido', '${intValue(metrics['lostMinutes'])} minutos'),
      ])),
      const SectionTitle('Responsables'),
      SurfaceCard(child: Column(children: [KeyValue('Titular de edición', text(p['TitularNombre'], 'Sin ocupación activa')), KeyValue('Auditor asignado', text(p['AuditorAsignado'], 'Sin asignar')), const SizedBox(height: 10), SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _busy ? null : _assign, icon: const Icon(Icons.person_add_alt), label: const Text('Asignar auditor')))])),
      if (p['NotaGeneral'] != null) ...[const SectionTitle('Observaciones'), SurfaceCard(child: Text(text(p['NotaGeneral']), style: const TextStyle(height: 1.5)))],
    ]);
  }
  Widget _progress(String label, double value, String caption, Color color) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))), Text('${(value * 100).toStringAsFixed(0)}%', style: TextStyle(color: color, fontWeight: FontWeight.w800))]), const SizedBox(height: 8),
    ClipRRect(borderRadius: BorderRadius.circular(5), child: LinearProgressIndicator(value: value.clamp(0.0, 1.0).toDouble(), minHeight: 7, color: color, backgroundColor: color.withValues(alpha: .10))), const SizedBox(height: 5), Text(caption, style: const TextStyle(color: muted, fontSize: 12)),
  ]);
  Widget _operations(RowData project, RowData metrics, List<RowData> hours, bool ownOperation) => ListView(padding: const EdgeInsets.only(bottom: 30), children: [
    const PageHeader('Control de operación', 'Plan original, movimientos y tiempos del buque.'),
    SurfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Preparar y cerrar la operación', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      if (!ownOperation) const Padding(padding: EdgeInsets.only(bottom: 12), child: Text('Estos pasos requieren iniciar el proyecto con tu perfil. Las comprobaciones se repiten al confirmar.', style: TextStyle(color: muted, height: 1.4))),
      OutlinedButton.icon(onPressed: _busy || !ownOperation ? null : () => _confirmOperation('Congelar estimado', 'Comprueba el plan y las cuadrillas. El estimado original no se podrá sobrescribir después de congelarlo.', () => widget.repository.freezePlan(widget.projectId), 'Estimado congelado'), icon: const Icon(Icons.lock_outline), label: const Text('1. Congelar estimado')),
      const SizedBox(height: 8),
      OutlinedButton.icon(onPressed: _busy || !ownOperation ? null : () => _confirmOperation('Validar Arrival / Departure', 'Se comprobarán los reportes y la secuencia de los hitos del buque.', () => widget.repository.validateReports(widget.projectId), 'Reportes validados'), icon: const Icon(Icons.fact_check_outlined), label: const Text('2. Validar reportes')),
      const SizedBox(height: 8),
      OutlinedButton.icon(onPressed: _busy || !ownOperation ? null : () => _confirmOperation('Finalizar Hourly', 'La conciliación debe quedar a cero por categoría y cuadrilla. No se modifica el estimado para cuadrar.', () => widget.repository.finalizeHourly(widget.projectId), 'Hourly finalizado'), icon: const Icon(Icons.rule), label: const Text('3. Finalizar Hourly')),
      const SizedBox(height: 8),
      FilledButton.icon(onPressed: _busy || !ownOperation ? null : () => _confirmOperation('Enviar a revisión', 'Se comprobarán tareas, reportes y Hourly. Después podrás aprobar o devolver desde Revisión.', () => widget.repository.submitReview(widget.projectId), 'Proyecto enviado a revisión'), icon: const Icon(Icons.send_outlined), label: const Text('4. Terminar y enviar a revisión')),
    ])),
    SurfaceCard(child: Column(children: [
      _dataLink(Icons.assignment_outlined, 'Estimado original', 'Importación, exportación y planificación', 'PM_Estimados'),
      const Divider(height: 20), _dataLink(Icons.groups_outlined, 'Cuadrillas', 'Plan de movimientos y productividad', 'PM_EstimadoGang'),
      const Divider(height: 20), _dataLink(Icons.list_alt, 'Detalle del plan por cuadrilla', 'Categorías de movimientos asignadas', 'PM_EstimadoGangDetalle'),
      const Divider(height: 20), _dataLink(Icons.pie_chart_outline, 'Reparto Hourly por cuadrilla', 'Conciliación de cada corte', 'PM_HourlyGang'),
      const Divider(height: 20), _dataLink(Icons.local_shipping_outlined, 'Vacíos por destino', 'Distribución de exportación vacía', 'PM_VaciosDestino'),
      const Divider(height: 20), _dataLink(Icons.rule_outlined, 'Exclusiones', 'Conciliación justificada de diferencias', 'PM_Exclusiones'),
    ])),
    SectionTitle('Hourly', trailing: TextButton.icon(onPressed: _busy ? null : () => _catalog('PM_Hourly', 'Hourly del proyecto'), icon: const Icon(Icons.open_in_new, size: 16), label: const Text('Ver datos'))),
    if (hours.isEmpty) const EmptyState('Sin cortes registrados', 'Los intervalos de operación aparecerán aquí.', icon: Icons.timeline) else ...[
      SurfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Línea de operación real', style: TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 8),
        const Text('Los cortes se muestran en proporción a su duración.', style: TextStyle(color: muted, fontSize: 12)), const SizedBox(height: 18),
        ..._timeline(hours),
      ])),
      ...hours.map((h) => SurfaceCard(child: InkWell(onTap: () => _edit('PM_Hourly', row: h), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Icon(Icons.schedule, size: 18, color: teal), const SizedBox(width: 8), Expanded(child: Text('${dateText(h['HoraInicioUTC'])}\n${dateText(h['HoraFinUTC'])}', style: const TextStyle(fontWeight: FontWeight.w700, height: 1.5))), const Icon(Icons.chevron_right, color: muted)]),
        const SizedBox(height: 8), Text('${_hourMovements(h)} movimientos · ${intValue(h['PerdidaHoras'])} h ${intValue(h['PerdidaMinutos'])} min perdidos', style: const TextStyle(color: muted)),
        if (h['NotaHora'] != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(text(h['NotaHora']))),
      ])))),
    ],
    const SectionTitle('Llegada y salida'),
    SurfaceCard(child: Column(children: [
      _dataLink(Icons.login, 'Arrival / Departure', 'Remolque, calados, consumos y puertos', 'PM_ReportesMaritimos'),
      const Divider(height: 20), _dataLink(Icons.flag_outlined, 'Hitos del buque', 'Fechas reales y secuencia cronológica', 'PM_HitosBuque'),
      const Divider(height: 20), _dataLink(Icons.report_outlined, 'Incidencias', 'Advertencias y revisión justificada', 'PM_IncidenciasValidacion'),
      const Divider(height: 20), _dataLink(Icons.star_outline, 'Evaluaciones', 'Calificación por criterio y auditor', 'PM_Evaluaciones'),
    ])),
  ]);
  List<Widget> _timeline(List<RowData> hours) {
    final valid = hours.where((h) => dateValue(h['HoraInicioUTC']) != null && dateValue(h['HoraFinUTC']) != null).toList();
    if (valid.isEmpty) return [const Text('Faltan fechas de los cortes.')];
    final start = valid.map((h) => dateValue(h['HoraInicioUTC'])!).reduce((a, b) => a.isBefore(b) ? a : b);
    final end = valid.map((h) => dateValue(h['HoraFinUTC'])!).reduce((a, b) => a.isAfter(b) ? a : b);
    final span = end.difference(start).inMinutes.toDouble();
    if (span <= 0) return [const Text('No hay duración suficiente para mostrar el gráfico.')];
    return valid.take(20).map((h) {
      final a = dateValue(h['HoraInicioUTC'])!, b = dateValue(h['HoraFinUTC'])!;
      final left = (a.difference(start).inMinutes / span).clamp(0.0, 1.0).toDouble(), width = (b.difference(a).inMinutes / span).clamp(.01, 1.0).toDouble();
      return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [SizedBox(width: 52, child: Text('${two(a.toLocal().hour)}:${two(a.toLocal().minute)}', style: const TextStyle(fontSize: 12, color: muted))), Expanded(child: LayoutBuilder(builder: (context, c) => SizedBox(height: 19, child: Stack(children: [Positioned(left: left * c.maxWidth, width: (width * c.maxWidth).clamp(0.0, c.maxWidth * (1 - left)).toDouble(), child: Container(height: 16, decoration: BoxDecoration(color: teal, borderRadius: BorderRadius.circular(5))))]))))]));
    }).toList();
  }
  int _hourMovements(RowData row) => ['MovImp', 'ExpFull', 'ExpVacio', 'RestowDown', 'RestowUp', 'MovTapas', 'MovEspeciales'].fold(0, (sum, key) => sum + intValue(row[key]));
  Widget _dataLink(IconData icon, String title, String subtitle, String table) => ListTile(contentPadding: EdgeInsets.zero, leading: Icon(icon, color: teal), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(subtitle, style: const TextStyle(color: muted)), trailing: const Icon(Icons.chevron_right), onTap: () => _catalog(table, title));
  Widget _tasks(List<RowData> tasks) => ListView(padding: const EdgeInsets.only(bottom: 30), children: [
    PageHeader('Checklist e instrucciones', 'Las tareas aplicables y obligatorias intervienen en el cierre.', action: IconButton(tooltip: 'Agregar instrucción especial', onPressed: _busy ? null : _instruction, icon: const Icon(Icons.add_circle_outline))),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5), child: FilledButton.icon(onPressed: _busy ? null : _instruction, icon: const Icon(Icons.add), label: const Text('Agregar instrucción especial'))),
    if (tasks.isEmpty) const EmptyState('Sin tareas', 'Agrega una instrucción o configura el catálogo de tareas.'),
    ...tasks.map((task) {
      final done = task['EstadoTarea'] == 'Completada', applies = intValue(task['Aplica']) == 1;
      return SurfaceCard(child: InkWell(onTap: () => _edit('PM_TareasProyecto', row: task), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(done ? Icons.check_circle : applies ? Icons.radio_button_unchecked : Icons.remove_circle_outline, color: done ? teal : muted), const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(text(task['TextoTarea']), style: TextStyle(fontWeight: FontWeight.w700, height: 1.4, decoration: !applies ? TextDecoration.lineThrough : null)), const SizedBox(height: 7),
          Wrap(spacing: 8, runSpacing: 6, children: [Text(done ? 'Completada' : applies ? 'Pendiente' : 'No aplica', style: TextStyle(color: done ? teal : muted, fontSize: 12)), if (intValue(task['Obligatoria']) == 1) const Text('• Obligatoria', style: TextStyle(color: warm, fontSize: 12)), if (intValue(task['EsEspecial']) == 1) const Text('• Especial', style: TextStyle(color: teal, fontSize: 12))]),
          if (task['VenceUTC'] != null) Padding(padding: const EdgeInsets.only(top: 7), child: Text('Vence ${dateText(task['VenceUTC'])}', style: const TextStyle(color: muted, fontSize: 12))),
        ])), const Icon(Icons.chevron_right, color: muted),
      ])));
    }),
  ]);
  Widget _reviewPage(RowData project, List<String> problems) {
    final state = text(project['EstadoProyecto']);
    return ListView(padding: const EdgeInsets.only(bottom: 35), children: [
      const PageHeader('Revisión del supervisor', 'Cada decisión conserva su motivo en el historial.'),
      SurfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(problems.isEmpty ? Icons.task_alt : Icons.rule, color: problems.isEmpty ? teal : warm), const SizedBox(width: 10), Expanded(child: Text(problems.isEmpty ? 'Validaciones completas' : '${problems.length} comprobaciones pendientes', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)))]),
        const SizedBox(height: 16),
        if (problems.isEmpty) const Text('No se detectaron pendientes en las reglas de cierre.', style: TextStyle(color: muted, height: 1.5)) else ...problems.map((p) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.circle, size: 7, color: warm), const SizedBox(width: 9), Expanded(child: Text(p, style: const TextStyle(height: 1.4)))]))),
      ])),
      if (state == 'PendienteRevision') SurfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        FilledButton.icon(onPressed: _busy || problems.isNotEmpty ? null : () => _review('APROBAR'), icon: const Icon(Icons.task_alt), label: const Text('Aprobar y cerrar')),
        const SizedBox(height: 10), OutlinedButton.icon(onPressed: _busy ? null : () => _review('DEVOLVER'), icon: const Icon(Icons.assignment_return_outlined), label: const Text('Devolver con observaciones')),
        if (problems.isNotEmpty) const Padding(padding: EdgeInsets.only(top: 10), child: Text('Resuelve los pendientes antes de aprobar.', style: TextStyle(color: muted))),
      ])) else if (state == 'Cerrado') SurfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [const Text('El cierre anterior se conserva al reabrir el proyecto.', style: TextStyle(color: muted)), const SizedBox(height: 12), OutlinedButton.icon(onPressed: _busy ? null : () => _review('REABRIR'), icon: const Icon(Icons.lock_open_outlined), label: const Text('Reabrir con motivo'))])) else const SurfaceCard(child: Text('La aprobación estará disponible cuando el auditor termine y envíe el proyecto a revisión.', style: TextStyle(color: muted, height: 1.5))),
      const SectionTitle('Intervención administrativa'),
      SurfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [const Text('Libera una ocupación abandonada solo después de comprobar que el titular dejó de trabajar.', style: TextStyle(color: muted, height: 1.5)), const SizedBox(height: 12), OutlinedButton.icon(onPressed: _busy ? null : _release, icon: const Icon(Icons.person_off_outlined), label: const Text('Liberar ocupación con motivo'))])),
    ]);
  }
  Widget _audit(List<RowData> rows) => ListView(padding: const EdgeInsets.only(bottom: 30), children: [
    const PageHeader('Historial del proyecto', 'Operador configurado, fecha y resultado de cada acción.'),
    if (rows.isEmpty) const EmptyState('Sin eventos', 'Los cambios relevantes se registran aquí.'),
    ...rows.map((row) => SurfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text(text(row['EventoCodigo']), style: const TextStyle(fontWeight: FontWeight.w800))), Text(dateText(row['FechaUTC']), style: const TextStyle(color: muted, fontSize: 11))]),
      const SizedBox(height: 7), Text('${text(row['ActorNombre'], 'Operador ${row['ActorID']}')} · ${text(row['Resultado'], 'Registrado')}', style: const TextStyle(color: muted)),
      if (row['Despues'] != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(text(row['Despues']), maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, height: 1.4))),
    ]))),
  ]);
}

class _InstructionDialog extends StatefulWidget {
  const _InstructionDialog();
  @override State<_InstructionDialog> createState() => _InstructionDialogState();
}
class _InstructionDialogState extends State<_InstructionDialog> {
  final _controller = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _required = true;
  @override void dispose() { _controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nueva instrucción especial'),
    content: SingleChildScrollView(child: Form(key: _form, child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('Se añadirá a las tareas del proyecto, incluso si otro operador lo tiene ocupado.', style: TextStyle(color: muted, height: 1.4)), const SizedBox(height: 18),
      TextFormField(controller: _controller, maxLines: 4, autofocus: true, decoration: const InputDecoration(labelText: 'Instrucción'), validator: (v) => v == null || v.trim().isEmpty ? 'Escribe la instrucción' : null),
      SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, title: const Text('Obligatoria para terminar'), value: _required, onChanged: (v) => setState(() => _required = v)),
    ]))),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')), FilledButton(onPressed: () { if (_form.currentState!.validate()) Navigator.pop(context, {'text': _controller.text.trim(), 'required': _required}); }, child: const Text('Agregar'))],
  );
}
