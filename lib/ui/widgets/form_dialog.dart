import 'package:flutter/material.dart';
import '../../core/colors/app_colors.dart';
import '../../core/utils/format.dart';
import '../../core/utils/responsive.dart';

sealed class FieldSpec {
  const FieldSpec(this.key, this.label);
  final String key, label;
}

class FText extends FieldSpec {
  const FText(super.key, super.label,
      {this.multiline = false, this.required = false, this.hint, this.keyboard, this.obscure = false});
  final bool multiline, required, obscure;
  final String? hint;
  final TextInputType? keyboard;
}

class FNumber extends FieldSpec {
  const FNumber(super.key, super.label, {this.decimal = false, this.required = false, this.suffix});
  final bool decimal, required;
  final String? suffix;
}

class FDate extends FieldSpec {
  const FDate(super.key, super.label, {this.required = false});
  final bool required;
}

class FDateTime extends FieldSpec {
  const FDateTime(super.key, super.label);
}

class FChoice extends FieldSpec {
  const FChoice(super.key, super.label, this.options, {this.allowNone = false});
  final Map<String, String> options;
  final bool allowNone;
}

class FSwitch extends FieldSpec {
  const FSwitch(super.key, super.label);
}

/// Opens an adaptive form: bottom sheet on phones, dialog on wide screens.
/// Returns the edited values or null if cancelled.
Future<Map<String, Object?>?> showForm(
  BuildContext context, {
  required String title,
  required List<FieldSpec> fields,
  Map<String, Object?> initial = const {},
  String submitLabel = 'Save',
}) {
  final body = _FormBody(title: title, fields: fields, initial: initial, submitLabel: submitLabel);
  if (Responsive.isCompact(context)) {
    return showModalBottomSheet<Map<String, Object?>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (c) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(c).bottom),
        child: body,
      ),
    );
  }
  return showDialog<Map<String, Object?>>(
    context: context,
    builder: (c) => Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: body),
    ),
  );
}

class _FormBody extends StatefulWidget {
  const _FormBody(
      {required this.title, required this.fields, required this.initial, required this.submitLabel});
  final String title, submitLabel;
  final List<FieldSpec> fields;
  final Map<String, Object?> initial;
  @override
  State<_FormBody> createState() => _FormBodyState();
}

class _FormBodyState extends State<_FormBody> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, Object?> _v = Map.of(widget.initial);
  final _ctl = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    for (final f in widget.fields) {
      if (f is FText || f is FNumber) {
        _ctl[f.key] = TextEditingController(text: _v[f.key]?.toString() ?? '');
      }
    }
  }

  @override
  void dispose() {
    for (final c in _ctl.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(FieldSpec f, {bool time = false}) async {
    final cur = _v[f.key] as DateTime?;
    final d = await showDatePicker(
        context: context,
        initialDate: cur ?? DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100));
    if (d == null || !mounted) return;
    var out = d;
    if (time) {
      final t = await showTimePicker(
          context: context,
          initialTime: cur == null ? TimeOfDay.now() : TimeOfDay.fromDateTime(cur));
      if (t == null) return;
      out = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    }
    setState(() => _v[f.key] = out);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final out = Map<String, Object?>.of(_v);
    for (final f in widget.fields) {
      final c = _ctl[f.key];
      if (c == null) continue;
      final t = c.text.trim();
      if (f is FNumber) {
        out[f.key] = t.isEmpty ? null : (f.decimal ? double.parse(t) : int.parse(t));
      } else {
        out[f.key] = t;
      }
    }
    Navigator.pop(context, out);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
          child: Row(children: [
            Expanded(
                child: Text(widget.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700))),
            IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close)),
          ]),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(children: [for (final f in widget.fields) _field(f)]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Row(children: [
            Expanded(
                child: OutlinedButton(
                    onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
            const SizedBox(width: 12),
            Expanded(child: FilledButton(onPressed: _submit, child: Text(widget.submitLabel))),
          ]),
        ),
      ]),
    );
  }

  Widget _field(FieldSpec f) {
    final pad = const EdgeInsets.only(bottom: 14);
    switch (f) {
      case FText():
        return Padding(
          padding: pad,
          child: TextFormField(
            controller: _ctl[f.key],
            minLines: f.multiline ? 3 : 1,
            maxLines: f.multiline ? 8 : 1,
            obscureText: f.obscure,
            keyboardType: f.multiline ? TextInputType.multiline : f.keyboard,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: f.label, hintText: f.hint),
            validator: f.required
                ? (v) => (v == null || v.trim().isEmpty) ? '${f.label} is required' : null
                : null,
          ),
        );
      case FNumber():
        return Padding(
          padding: pad,
          child: TextFormField(
            controller: _ctl[f.key],
            keyboardType: TextInputType.numberWithOptions(decimal: f.decimal),
            decoration: InputDecoration(labelText: f.label, suffixText: f.suffix),
            validator: (v) {
              final t = v?.trim() ?? '';
              if (t.isEmpty) return f.required ? '${f.label} is required' : null;
              final n = f.decimal ? double.tryParse(t) : int.tryParse(t);
              if (n == null) return 'Enter a valid number';
              if (n < 0) return 'Must not be negative';
              return null;
            },
          ),
        );
      case FDate():
        final d = _v[f.key] as DateTime?;
        return Padding(
          padding: pad,
          child: FormField<DateTime>(
            validator: (_) => f.required && _v[f.key] == null ? '${f.label} is required' : null,
            builder: (s) => InkWell(
              borderRadius: BorderRadius.circular(Radii.sm),
              onTap: () => _pickDate(f),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: f.label,
                  errorText: s.errorText,
                  suffixIcon: d == null || f.required
                      ? const Icon(Icons.calendar_today_outlined, size: 18)
                      : IconButton(
                          tooltip: 'Clear',
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => setState(() => _v[f.key] = null)),
                ),
                child: Text(d == null ? 'Not set' : fmtDate(d)),
              ),
            ),
          ),
        );
      case FDateTime():
        final d = _v[f.key] as DateTime?;
        return Padding(
          padding: pad,
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.sm),
            onTap: () => _pickDate(f, time: true),
            child: InputDecorator(
              decoration: InputDecoration(
                  labelText: f.label, suffixIcon: const Icon(Icons.schedule, size: 18)),
              child: Text(d == null ? 'Not set' : fmtDateTime(d)),
            ),
          ),
        );
      case FChoice():
        final cur = _v[f.key] as String?;
        return Padding(
          padding: pad,
          child: DropdownButtonFormField<String?>(
            initialValue: f.options.containsKey(cur) ? cur : null,
            isExpanded: true,
            decoration: InputDecoration(labelText: f.label),
            items: [
              if (f.allowNone) const DropdownMenuItem<String?>(value: null, child: Text('None')),
              for (final e in f.options.entries)
                DropdownMenuItem<String?>(
                    value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() => _v[f.key] = v),
          ),
        );
      case FSwitch():
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(f.label),
            value: (_v[f.key] as bool?) ?? false,
            onChanged: (v) => setState(() => _v[f.key] = v),
          ),
        );
    }
  }
}
