import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/api.dart';

class FormFieldSpec {
  final String keyName, label;
  final String type;
  final bool required;
  final Map<String, String>? options;
  final String? hint;
  const FormFieldSpec(
    this.keyName,
    this.label, {
    this.type = 'text',
    this.required = true,
    this.options,
    this.hint,
  });
}

Future<bool> showEditor(
  BuildContext context, {
  required String title,
  required List<FormFieldSpec> fields,
  required Future<void> Function(Json) save,
  Json initial = const {},
}) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _Editor(title: title, fields: fields, save: save, initial: initial),
    ) ??
    false;

class _Editor extends StatefulWidget {
  final String title;
  final List<FormFieldSpec> fields;
  final Future<void> Function(Json) save;
  final Json initial;
  const _Editor({
    required this.title,
    required this.fields,
    required this.save,
    required this.initial,
  });
  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  final form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> controls;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    controls = {
      for (final field in widget.fields)
        field.keyName: TextEditingController(
          text:
              field.type == 'datetime' && widget.initial[field.keyName] != null
              ? DateTime.parse(
                  widget.initial[field.keyName].toString(),
                ).toLocal().toIso8601String()
              : widget.initial[field.keyName]?.toString() ?? '',
        ),
    };
  }

  @override
  void dispose() {
    for (final c in controls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final Json result = {};
      for (final field in widget.fields) {
        final text = field.type == 'password'
            ? controls[field.keyName]!.text
            : controls[field.keyName]!.text.trim();
        if (text.isEmpty && !field.required) continue;
        result[field.keyName] = switch (field.type) {
          'int' || 'selectInt' => int.parse(text),
          'double' => double.parse(text),
          'datetime' => DateTime.parse(text).toUtc().toIso8601String(),
          _ => text,
        };
      }
      await widget.save(result);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.title,
      style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
    ),
    content: SizedBox(
      width: 450,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final field in widget.fields)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: field.options != null
                      ? DropdownButtonFormField<String>(
                          initialValue:
                              field.options!.containsKey(
                                controls[field.keyName]!.text,
                              )
                              ? controls[field.keyName]!.text
                              : null,
                          isExpanded: true,
                          decoration: InputDecoration(labelText: field.label),
                          items: field.options!.entries
                              .map(
                                (entry) => DropdownMenuItem(
                                  value: entry.key,
                                  child: Text(
                                    entry.value,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: busy
                              ? null
                              : (value) =>
                                    controls[field.keyName]!.text = value ?? '',
                          validator: (v) =>
                              field.required && (v == null || v.isEmpty)
                              ? 'Chọn ${field.label.toLowerCase()}'
                              : null,
                        )
                      : TextFormField(
                          controller: controls[field.keyName],
                          enabled: !busy,
                          obscureText: field.type == 'password',
                          readOnly:
                              field.type == 'date' ||
                              field.type == 'time' ||
                              field.type == 'datetime',
                          maxLines: field.type == 'multiline' ? 3 : 1,
                          keyboardType: ['int', 'double'].contains(field.type)
                              ? const TextInputType.numberWithOptions(
                                  decimal: true,
                                  signed: true,
                                )
                              : field.type == 'email'
                              ? TextInputType.emailAddress
                              : TextInputType.text,
                          decoration: InputDecoration(
                            labelText: field.label,
                            hintText: field.hint,
                            suffixIcon: field.type == 'date'
                                ? const Icon(
                                    Icons.calendar_today_outlined,
                                    size: 18,
                                  )
                                : field.type == 'time'
                                ? const Icon(Icons.schedule, size: 18)
                                : null,
                          ),
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(
                              field.type == 'multiline'
                                  ? 1000
                                  : field.type == 'email'
                                  ? 254
                                  : 128,
                            ),
                          ],
                          onTap: field.type == 'datetime'
                              ? () async {
                                  final current =
                                      DateTime.tryParse(
                                        controls[field.keyName]!.text,
                                      )?.toLocal() ??
                                      DateTime.now();
                                  final date = await showDatePicker(
                                    context: context,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2100),
                                    initialDate: current,
                                  );
                                  if (date == null || !context.mounted) return;
                                  final time = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.fromDateTime(
                                      current,
                                    ),
                                  );
                                  if (time != null) {
                                    controls[field.keyName]!.text = DateTime(
                                      date.year,
                                      date.month,
                                      date.day,
                                      time.hour,
                                      time.minute,
                                    ).toIso8601String();
                                  }
                                }
                              : field.type == 'date'
                              ? () async {
                                  final first = DateTime.now().subtract(
                                    const Duration(days: 365),
                                  );
                                  final last = DateTime.now().add(
                                    const Duration(days: 730),
                                  );
                                  final current =
                                      DateTime.tryParse(
                                        controls[field.keyName]!.text,
                                      ) ??
                                      DateTime.now();
                                  final date = await showDatePicker(
                                    context: context,
                                    firstDate: first,
                                    lastDate: last,
                                    initialDate: current.isBefore(first)
                                        ? first
                                        : current.isAfter(last)
                                        ? last
                                        : current,
                                  );
                                  if (date != null) {
                                    controls[field.keyName]!.text =
                                        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                                  }
                                }
                              : field.type == 'time'
                              ? () async {
                                  final date = await showTimePicker(
                                    context: context,
                                    initialTime:
                                        _TimeParser.tryParse(
                                          controls[field.keyName]!.text,
                                        ) ??
                                        const TimeOfDay(hour: 8, minute: 30),
                                  );
                                  if (date != null) {
                                    controls[field.keyName]!.text =
                                        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                                  }
                                }
                              : null,
                          validator: (v) {
                            final text = v?.trim() ?? '';
                            if (field.required && text.isEmpty) {
                              return 'Nhập ${field.label.toLowerCase()}';
                            }
                            if (text.isEmpty) return null;
                            if (field.type == 'int' &&
                                int.tryParse(text) == null) {
                              return 'Nhập số nguyên';
                            }
                            if (field.type == 'double' &&
                                (double.tryParse(text) == null ||
                                    !double.parse(text).isFinite)) {
                              return 'Nhập số hợp lệ';
                            }
                            if (field.type == 'password' && text.length < 10) {
                              return 'Mật khẩu tối thiểu 10 ký tự';
                            }
                            if (field.type == 'email' &&
                                !RegExp(
                                  r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                ).hasMatch(text)) {
                              return 'Email chưa hợp lệ';
                            }
                            return null;
                          },
                        ),
                ),
              if (error != null)
                Text(
                  error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context, false),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: busy ? null : submit,
        child: Text(busy ? 'Đang lưu…' : 'Lưu thay đổi'),
      ),
    ],
  );
}

class _TimeParser {
  static TimeOfDay? tryParse(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }
}
