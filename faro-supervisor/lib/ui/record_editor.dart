import 'package:flutter/material.dart';
import '../data/schema.dart';
import '../data/supervisor_repository.dart';
import 'common.dart';

Future<bool> editRecord(BuildContext context, SupervisorRepository repository, String table, {RowData? record, int? scaleId}) async {
  final result = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => RecordEditor(repository: repository, tableName: table, record: record, scaleId: scaleId)));
  return result == true;
}

class RecordEditor extends StatefulWidget {
  const RecordEditor({required this.repository, required this.tableName, this.record, this.scaleId, super.key});
  final SupervisorRepository repository;
  final String tableName;
  final RowData? record;
  final int? scaleId;
  @override State<RecordEditor> createState() => _RecordEditorState();
}
class _RecordEditorState extends State<RecordEditor> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, Object?> _values = {};
  final Map<String, List<RowData>> _references = {};
  late TableSpec _table;
  bool _loading = true, _saving = false, _dirty = false, _allowPop = false;
  Object? _loadError;
  List<FieldSpec> get _fields => _table.fields.where((f) => !f.system && f.name != 'ID' && !(widget.scaleId != null && f.name == 'EscalaID')).toList();
  @override void initState() { super.initState(); _table = widget.repository.tables.firstWhere((t) => t.name == widget.tableName); _load(); }
  @override void dispose() { for (final c in _controllers.values) { c.dispose(); } _reason.dispose(); super.dispose(); }
  void _markDirty() { if (mounted && !_dirty) setState(() => _dirty = true); }
  Future<void> _load() async {
    try {
      for (final field in _fields) {
        var value = widget.record?.containsKey(field.name) == true
            ? widget.record![field.name]
            : field.defaultValue;
        if (value == '' && field.type != 'text' && field.type != 'memo') value = null;
        if (field.type == 'boolean') value = value == true || value == 1 || value == -1 || value.toString().toLowerCase() == 'true' ? 1 : 0;
        _values[field.name] = value;
        if (field.references != null) {
          final options = await widget.repository.rows(field.references!, scaleId: widget.scaleId);
          if (!mounted) return;
          _references[field.name] = options;
          if (value != null && !options.any((row) => intValue(row['ID']) == intValue(value))) _values[field.name] = null;
        } else if (!['boolean', 'date'].contains(field.type)) {
          _controllers[field.name] = TextEditingController(text: value == null ? '' : '$value')..addListener(_markDirty);
        }
      }
      if (mounted) setState(() => _loading = false);
    } catch (error) { if (mounted) setState(() { _loading = false; _loadError = error; }); }
  }
  Future<void> _pickDate(FieldSpec field) async {
    final existing = dateValue(_values[field.name])?.toLocal() ?? DateTime.now();
    final firstDate = DateTime(1900);
    final lastDate = DateTime(2200, 12, 31);
    final initialDate = existing.isBefore(firstDate) ? firstDate : existing.isAfter(lastDate) ? lastDate : existing;
    final selected = await showDatePicker(context: context, initialDate: initialDate, firstDate: firstDate, lastDate: lastDate, helpText: field.label);
    if (selected == null || !mounted) return;
    final onlyDate = ['FechaETA', 'AnteriorFechaETA', 'NuevaFechaETA'].contains(field.name);
    TimeOfDay? time;
    if (!onlyDate) time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(existing));
    if ((!onlyDate && time == null) || !mounted) return;
    final date = DateTime(selected.year, selected.month, selected.day, time?.hour ?? 0, time?.minute ?? 0);
    setState(() { _dirty = true; _values[field.name] = onlyDate ? date.toIso8601String().substring(0, 10) : date.toUtc().toIso8601String(); });
  }
  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final result = <String, Object?>{};
      for (final field in _fields) {
        Object? value = _values[field.name];
        if (_controllers.containsKey(field.name)) {
          final raw = _controllers[field.name]!.text.trim();
          value = raw.isEmpty ? null : switch (field.type) {
            'integer' => int.parse(raw),
            'real' => double.parse(raw.replaceAll(',', '.')),
            _ => raw,
          };
        }
        result[field.name] = value;
      }
      await widget.repository.save(widget.tableName, result, id: widget.record == null ? null : intValue(widget.record!['ID']), scaleId: widget.scaleId, reason: _reason.text.trim());
      if (mounted) await _leave(true);
    } catch (error) { if (mounted) { setState(() => _saving = false); notify(context, readableError(error), error: true); } }
  }
  Future<void> _leave([bool? result]) async {
    if (!mounted) return;
    setState(() { _allowPop = true; _dirty = false; _saving = false; });
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context, result);
  }
  Widget _field(FieldSpec field) {
    final humanLabel = field.type == 'date' ? field.label.replaceAll(RegExp(r'\s*\(?UTC\)?'), '') : field.label;
    final label = '$humanLabel${field.required ? ' *' : ''}';
    final choices = field.name == 'CodigoRol' ? const {'AUDITOR': 'Auditor', 'GERENCIA': 'Supervisor / Gerencia'} : field.name == 'CodigoPermiso' ? SupervisorRepository.permissionCodes : field.name == 'EstadoTarea' ? const {'Pendiente': 'Pendiente', 'Completada': 'Completada'} : field.name == 'TipoReporte' ? const {'Arrival': 'Arrival · Llegada', 'Departure': 'Departure · Salida'} : field.name == 'Nivel' ? const {'Advertencia': 'Advertencia', 'Error': 'Error', 'Info': 'Información'} : <String, String>{};
    if (choices.isNotEmpty) {
      final current = _controllers[field.name]?.text ?? _values[field.name]?.toString();
      return DropdownButtonFormField<String>(
        initialValue: choices.containsKey(current) ? current : null,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: choices.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value, overflow: TextOverflow.ellipsis))).toList(),
        onChanged: _saving ? null : (value) { setState(() { _dirty = true; _values[field.name] = value; }); _controllers[field.name]?.text = value ?? ''; },
        validator: (value) => field.required && value == null ? 'Selecciona una opción' : null,
      );
    }
    if (field.references != null) {
      final options = _references[field.name] ?? [];
      final value = _values[field.name] == null ? null : intValue(_values[field.name]);
      return DropdownButtonFormField<int>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, helperText: options.isEmpty ? 'Crea primero un registro en el catálogo relacionado.' : null),
        items: [if (!field.required) const DropdownMenuItem<int>(value: null, child: Text('Sin asignar')), ...options.map((r) => DropdownMenuItem<int>(value: intValue(r['ID']), child: Text(rowLabel(r), overflow: TextOverflow.ellipsis)))],
        onChanged: _saving ? null : (v) => setState(() { _dirty = true; _values[field.name] = v; }),
        validator: (v) => field.required && v == null ? 'Selecciona una opción' : null,
      );
    }
    if (field.type == 'boolean') return SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4), title: Text(field.label), value: _values[field.name] == 1,
      onChanged: _saving ? null : (v) => setState(() { _dirty = true; _values[field.name] = v ? 1 : 0; }),
    );
    if (field.type == 'date') return FormField<Object?>(initialValue: _values[field.name], validator: (_) => field.required && _values[field.name] == null ? 'Indica una fecha' : null, builder: (state) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      InkWell(onTap: _saving ? null : () async { await _pickDate(field); if (mounted && state.mounted) state.didChange(_values[field.name]); }, borderRadius: BorderRadius.circular(14), child: InputDecorator(
        decoration: InputDecoration(labelText: label, errorText: state.errorText, suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [if (!field.required && _values[field.name] != null) IconButton(tooltip: 'Quitar fecha', onPressed: _saving ? null : () { setState(() { _dirty = true; _values[field.name] = null; }); state.didChange(null); }, icon: const Icon(Icons.clear, size: 18)), const Padding(padding: EdgeInsets.all(12), child: Icon(Icons.calendar_month_outlined))])),
        child: Text(_values[field.name] == null ? 'Seleccionar fecha${field.name == 'FechaETA' ? '' : ' y hora'}' : dateText(_values[field.name], time: field.name != 'FechaETA')),
      )),
    ]));
    final numeric = field.type == 'integer' || field.type == 'real';
    return TextFormField(
      controller: _controllers[field.name], enabled: !_saving,
      maxLines: field.type == 'memo' ? 4 : 1,
      textCapitalization: numeric ? TextCapitalization.none : TextCapitalization.sentences,
      keyboardType: numeric ? TextInputType.numberWithOptions(decimal: field.type == 'real') : field.type == 'memo' ? TextInputType.multiline : TextInputType.text,
      decoration: InputDecoration(labelText: label, alignLabelWithHint: true),
      validator: (v) {
        final value = v?.trim() ?? '';
        if (value.isEmpty) return field.required ? 'Este campo es obligatorio' : null;
        if (numeric) {
          final n = num.tryParse(value.replaceAll(',', '.'));
          if (n == null || !n.isFinite) return 'Escribe un número válido';
          if (n < 0) return 'El valor no puede ser negativo';
          if (field.type == 'integer' && int.tryParse(value) == null) return 'Escribe un número entero';
        }
        return null;
      },
    );
  }
  @override Widget build(BuildContext context) => PopScope(
    canPop: _allowPop || (!_saving && !_dirty),
    onPopInvokedWithResult: (didPop, result) async {
      if (didPop || _saving) return;
      final discard = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
        title: const Text('¿Descartar los cambios?'),
        content: const Text('Los datos que has escrito todavía no se han guardado.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Seguir editando')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Descartar'))],
      ));
      if (discard == true && mounted) await _leave();
    },
    child: Scaffold(
      appBar: AppBar(title: Text('${widget.record == null ? 'Nuevo' : 'Editar'} · ${_table.label}')),
      body: _loading ? const Center(child: CircularProgressIndicator()) : _loadError != null ? EmptyState('No se pudo abrir el formulario', readableError(_loadError!), icon: Icons.error_outline) : Form(key: _form, child: ListView(
        padding: const EdgeInsets.all(20), children: [
          Text('Los campos con * son obligatorios. Las fechas se muestran en la hora del dispositivo.', style: const TextStyle(color: muted)), const SizedBox(height: 18),
          ..._fields.map((field) => Padding(padding: const EdgeInsets.only(bottom: 18), child: _field(field))),
          if (widget.record != null) ...[const SizedBox(height: 6), TextFormField(controller: _reason, onChanged: (_) => _markDirty(), minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Motivo del cambio', helperText: 'Obligatorio para cambios que requieren justificación.'))],
          const SizedBox(height: 26), FilledButton.icon(onPressed: _saving ? null : _save, icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check), label: Text(_saving ? 'Guardando…' : 'Guardar cambios')),
          const SizedBox(height: 24),
        ],
      )),
    ),
  );
}

class CatalogPage extends StatefulWidget {
  const CatalogPage({required this.repository, required this.tableName, this.scaleId, this.title, super.key});
  final SupervisorRepository repository;
  final String tableName;
  final int? scaleId;
  final String? title;
  @override State<CatalogPage> createState() => _CatalogPageState();
}
class _CatalogPageState extends State<CatalogPage> {
  int _version = 0;
  String _search = '';
  late TableSpec _table;
  @override void initState() { super.initState(); _table = widget.repository.tables.firstWhere((t) => t.name == widget.tableName); }
  Future<void> _edit(RowData? row) async {
    if (await editRecord(context, widget.repository, widget.tableName, record: row, scaleId: widget.scaleId)) {
      if (mounted) { setState(() => _version++); notify(context, 'Cambios guardados'); }
    }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title ?? _table.label), actions: [IconButton(tooltip: 'Actualizar', onPressed: () => setState(() => _version++), icon: const Icon(Icons.refresh))]),
    floatingActionButton: _table.editable ? FloatingActionButton.extended(onPressed: () => _edit(null), icon: const Icon(Icons.add), label: const Text('Agregar')) : null,
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(20), child: TextField(onChanged: (v) => setState(() => _search = v.toLowerCase()), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar en este catálogo'))),
      Expanded(child: AsyncData<List<RowData>>(version: _version, load: () => widget.repository.rows(widget.tableName, scaleId: widget.scaleId), builder: (context, value) {
        final rows = value.where((r) => r.values.any((v) => v != null && '$v'.toLowerCase().contains(_search))).toList();
        if (rows.isEmpty) return EmptyState('Sin registros', _search.isEmpty ? (_table.editable ? 'Agrega el primer registro para comenzar.' : 'Los registros aparecerán cuando se realicen las operaciones correspondientes.') : 'Prueba con otra búsqueda.');
        return ListView.separated(padding: const EdgeInsets.fromLTRB(20, 0, 20, 100), itemCount: rows.length, separatorBuilder: (_, _) => const SizedBox(height: 8), itemBuilder: (context, index) {
          final row = rows[index];
          final details = _table.fields.where((f) => !f.system && f.name != 'ID' && row[f.name] != null).take(4).map((f) => '${f.label}: ${f.type == 'date' ? dateText(row[f.name]) : f.type == 'boolean' ? (intValue(row[f.name]) == 1 ? 'Sí' : 'No') : row[f.name]}').join(' · ');
          return Material(color: Colors.white, borderRadius: BorderRadius.circular(16), child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(rowLabel(row), style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Padding(padding: const EdgeInsets.only(top: 6), child: Text(details, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: muted, height: 1.4))),
            trailing: _table.editable ? const Icon(Icons.edit_outlined, size: 20) : null,
            onTap: _table.editable ? () => _edit(row) : () => _showRow(row),
          ));
        });
      })),
    ]),
  );
  void _showRow(RowData row) {
    showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true, builder: (context) => SafeArea(child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(22, 10, 22, 30), children: [
      Text(rowLabel(row), style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 16),
      ..._table.fields.where((f) => row[f.name] != null).map((f) => KeyValue(f.label, f.type == 'date' ? dateText(row[f.name]) : text(row[f.name]))),
    ])));
  }
}
