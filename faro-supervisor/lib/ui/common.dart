import 'package:flutter/material.dart';

const ink = Color(0xff142b3d);
const teal = Color(0xff087f79);
const muted = Color(0xff627385);
const canvas = Color(0xfff3f6f8);
const warm = Color(0xffab6800);
const danger = Color(0xffad343b);

typedef RowData = Map<String, Object?>;

String text(Object? value, [String fallback = 'Sin dato']) =>
    value == null || value.toString().trim().isEmpty ? fallback : value.toString();
int intValue(Object? value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;
double number(Object? value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
DateTime? dateValue(Object? value) => value is DateTime ? value : DateTime.tryParse('$value');
String two(int value) => '$value'.padLeft(2, '0');
String dateText(Object? value, {bool time = true}) {
  final parsed = dateValue(value);
  if (parsed == null) return 'Por confirmar';
  final d = parsed.toLocal();
  return '${two(d.day)}/${two(d.month)}/${d.year}${time ? ' · ${two(d.hour)}:${two(d.minute)}' : ''}';
}

String statusLabel(String value) => switch (value) {
  'Pendiente' => 'Pendiente',
  'EnProceso' => 'En proceso',
  'EnPausa' => 'En pausa',
  'PendienteRevision' => 'En revisión',
  'Devuelto' => 'Devuelto',
  'Cerrado' => 'Cerrado',
  _ => value,
};
Color statusColor(String value) => switch (value) {
  'EnProceso' => teal,
  'EnPausa' || 'PendienteRevision' => warm,
  'Devuelto' => danger,
  'Cerrado' => const Color(0xff476e51),
  _ => muted,
};

String rowLabel(RowData row) {
  if (row['HoraInicioUTC'] != null) return '${dateText(row['HoraInicioUTC'])} — ${dateText(row['HoraFinUTC'])}';
  for (final key in ['NombreMostrado', 'NombreBuque', 'NombreServicio', 'TextoTarea', 'NombreRol', 'Nombre', 'NombrePuerto', 'Descripcion', 'CodigoGang', 'CallKey', 'Codigo', 'CodigoTarea', 'EventoCodigo', 'NotaEntrega']) {
    if (row[key] != null && text(row[key], '').isNotEmpty) return text(row[key]);
  }
  return 'Registro ${row['ID'] ?? ''}';
}

void notify(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(message), backgroundColor: error ? danger : ink,
    behavior: SnackBarBehavior.floating,
  ));
}
String readableError(Object error) {
  final message = error.toString().replaceFirst(RegExp(r'^(Exception|StateError|ArgumentError|Bad state|Invalid argument\(s\)):\s*'), '');
  return message.length > 400 ? '${message.substring(0, 400)}…' : message;
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key});
  final String status;
  @override Widget build(BuildContext context) {
    final color = statusColor(status);
    return DecoratedBox(
      decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(30)),
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), child: Text(statusLabel(status), style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12))),
    );
  }
}

class PageHeader extends StatelessWidget {
  const PageHeader(this.title, this.subtitle, {this.action, super.key});
  final String title, subtitle;
  final Widget? action;
  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.5)),
        const SizedBox(height: 5), Text(subtitle, style: const TextStyle(color: muted, height: 1.4)),
      ])),
      if (action != null) Padding(padding: const EdgeInsets.only(left: 10), child: action!),
    ]),
  );
}

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({required this.child, this.padding = const EdgeInsets.all(18), this.margin = const EdgeInsets.symmetric(horizontal: 20, vertical: 6), super.key});
  final Widget child;
  final EdgeInsets padding, margin;
  @override Widget build(BuildContext context) => Container(
    margin: margin, padding: padding,
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xffe2e9ee))),
    child: child,
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {this.trailing, super.key});
  final String title;
  final Widget? trailing;
  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 7),
    child: Row(children: [Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))), if (trailing != null) trailing!]),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.title, this.message, {this.icon = Icons.inbox_outlined, this.action, super.key});
  final String title, message;
  final IconData icon;
  final Widget? action;
  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(30),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 48, color: muted), const SizedBox(height: 14),
      Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8), Text(message, textAlign: TextAlign.center, style: const TextStyle(color: muted, height: 1.5)),
      if (action != null) Padding(padding: const EdgeInsets.only(top: 14), child: action!),
    ]),
  );
}

class AsyncData<T> extends StatefulWidget {
  const AsyncData({required this.load, required this.builder, this.version = 0, super.key});
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T value) builder;
  final int version;
  @override State<AsyncData<T>> createState() => _AsyncDataState<T>();
}
class _AsyncDataState<T> extends State<AsyncData<T>> {
  late Future<T> _future;
  @override void initState() { super.initState(); _future = widget.load(); }
  @override void didUpdateWidget(covariant AsyncData<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.version != widget.version) _future = widget.load();
  }
  @override Widget build(BuildContext context) => FutureBuilder<T>(future: _future, builder: (context, snapshot) {
    if (snapshot.connectionState != ConnectionState.done) return const Center(child: Padding(padding: EdgeInsets.all(35), child: CircularProgressIndicator()));
    if (snapshot.hasError) return EmptyState('No se pudieron cargar los datos', readableError(snapshot.error!), icon: Icons.storage_outlined,
      action: OutlinedButton.icon(onPressed: () => setState(() => _future = widget.load()), icon: const Icon(Icons.refresh), label: const Text('Reintentar')));
    if (!snapshot.hasData) return const EmptyState('Sin datos', 'No hay información disponible todavía.');
    return widget.builder(context, snapshot.data as T);
  });
}

class MetricTile extends StatelessWidget {
  const MetricTile(this.label, this.value, {this.icon = Icons.analytics_outlined, this.color = teal, super.key});
  final String label, value;
  final IconData icon;
  final Color color;
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: color.withValues(alpha: .07), borderRadius: BorderRadius.circular(16)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 20), const SizedBox(height: 12),
      Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: color)),
      const SizedBox(height: 4), Text(label, style: const TextStyle(color: muted, fontSize: 12)),
    ]),
  );
}

class KeyValue extends StatelessWidget {
  const KeyValue(this.label, this.value, {super.key});
  final String label, value;
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Expanded(child: Text(label, style: const TextStyle(color: muted))),
    const SizedBox(width: 12), Flexible(child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w600))),
  ]));
}

Future<String?> askReason(BuildContext context, {required String title, String hint = 'Explica el motivo de esta decisión', String action = 'Confirmar'}) =>
    showDialog<String>(context: context, builder: (_) => _ReasonDialog(title: title, hint: hint, action: action));

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({required this.title, required this.hint, required this.action});
  final String title, hint, action;
  @override State<_ReasonDialog> createState() => _ReasonDialogState();
}
class _ReasonDialogState extends State<_ReasonDialog> {
  final _controller = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override void dispose() { _controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title), content: SingleChildScrollView(child: Form(key: _form, child: TextFormField(controller: _controller, autofocus: true, minLines: 3, maxLines: 6,
      decoration: InputDecoration(labelText: 'Motivo', hintText: widget.hint), validator: (v) => v == null || v.trim().isEmpty ? 'Escribe un motivo para continuar' : null))),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
      FilledButton(onPressed: () { if (_form.currentState!.validate()) Navigator.pop(context, _controller.text.trim()); }, child: Text(widget.action))],
  );
}

class ProjectCard extends StatelessWidget {
  const ProjectCard({required this.project, required this.onTap, super.key});
  final RowData project;
  final VoidCallback onTap;
  @override Widget build(BuildContext context) {
    final state = text(project['EstadoProyecto'], 'Pendiente');
    final eta = project['ETACompletaUTC'] ?? project['FechaETA'];
    final limit = dateValue(project['LimiteInicioPlanUTC'] ?? project['HoraLimiteFinUTC'] ?? project['ETACompletaUTC']);
    final late = state != 'Cerrado' && limit != null && DateTime.now().isAfter(limit);
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6), child: Material(
      color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xffe2e9ee))), clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.all(17), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: teal.withValues(alpha: .08), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.directions_boat_outlined, color: teal)),
          const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(text(project['NombreBuque'], 'Escala ${project['CallKey']}'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 3), Text('${text(project['CallKey'], 'Sin call')} · ${text(project['NombreServicio'], 'Servicio por asignar')}', style: const TextStyle(color: muted, fontSize: 12)),
          ])), const Icon(Icons.chevron_right, color: muted)]),
        const SizedBox(height: 16), Wrap(spacing: 8, runSpacing: 8, children: [StatusPill(state), if (late) const Chip(avatar: Icon(Icons.schedule, size: 15, color: danger), label: Text('Plazo vencido', style: TextStyle(color: danger)), visualDensity: VisualDensity.compact, side: BorderSide.none, backgroundColor: Color(0xfffbecef))]),
        const SizedBox(height: 10), Row(children: [const Icon(Icons.event_outlined, size: 16, color: muted), const SizedBox(width: 6), Expanded(child: Text('ETA ${dateText(eta, time: project['ETACompletaUTC'] != null)}', style: const TextStyle(color: muted, fontSize: 12))),
          if (project['TitularNombre'] != null) Flexible(child: Text(text(project['TitularNombre']), overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)))]),
      ]))),
    ));
  }
}
