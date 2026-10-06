import 'package:flutter/material.dart';

import '../core/locale.dart';

import 'package:provider/provider.dart';

import '../core/dates.dart';
import '../core/theme.dart';
import '../models/event_item.dart';
import '../services/calendar_repository.dart';
import '../widgets/cal_date_picker.dart';
import '../widgets/common.dart';

/// Bottom sheet to create / edit an event or reminder.
Future<void> showEventEditor(
  BuildContext context, {
  EventItem? existing,
  DateTime? day,
  int? hour,
  bool reminder = false,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<CalendarRepository>(),
      child: _EventEditor(
        existing: existing,
        day: day,
        hour: hour,
        reminder: reminder,
      ),
    ),
  );
}

class _EventEditor extends StatefulWidget {
  const _EventEditor({
    this.existing,
    this.day,
    this.hour,
    this.reminder = false,
  });
  final EventItem? existing;
  final DateTime? day;
  final int? hour;
  final bool reminder;

  @override
  State<_EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends State<_EventEditor> {
  late final TextEditingController _title;
  late final TextEditingController _location;
  late bool _isReminder;
  late bool _allDay;
  late DateTime _date;
  late TimeOfDay _from;
  late TimeOfDay _to;
  late int _color;
  String? _calendarId; // null => this app only
  bool _saving = false;

  EventItem? get _e => widget.existing;

  @override
  void initState() {
    super.initState();
    final repo = context.read<CalendarRepository>();
    final now = DateTime.now();
    _title = TextEditingController(text: _e?.title ?? '');
    _location = TextEditingController(text: _e?.location ?? '');
    _isReminder = _e?.isReminder ?? widget.reminder;
    _allDay = _e?.allDay ?? false;
    final base = _e?.start ?? widget.day ?? repo.selectedDay;
    _date = dateOnly(base);
    final startHour = _e != null
        ? _e!.start.hour
        : widget.hour ??
              (sameDay(_date, now) ? (now.hour + 1).clamp(0, 22) : 9);
    _from = _e != null
        ? TimeOfDay.fromDateTime(_e!.start)
        : TimeOfDay(hour: startHour, minute: 0);
    _to = _e != null && !_e!.isReminder
        ? TimeOfDay.fromDateTime(_e!.end)
        : TimeOfDay(hour: (startHour + 1).clamp(0, 23), minute: 0);
    _color = _e?.colorIndex ?? 0;
    if (_e == null) {
      final writable = repo.writableCalendars;
      if (repo.hasDeviceAccess && writable.isNotEmpty) {
        _calendarId = writable.any((c) => c.id == repo.defaultCalendarId)
            ? repo.defaultCalendarId
            : (writable.firstWhere(
                (c) => c.isPrimary,
                orElse: () => writable.first,
              )).id;
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    super.dispose();
  }

  DateTime _at(TimeOfDay t) =>
      DateTime(_date.year, _date.month, _date.day, t.hour, t.minute);

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      showSnack(context, t('Give it a title first'));
      return;
    }
    final repo = context.read<CalendarRepository>();
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);

    String? err;
    if (_isReminder && _e == null) {
      await repo.addReminder(title, _at(_from));
    } else {
      var start = _allDay ? _date : _at(_from);
      var end = _allDay ? addDays(_date, 1) : _at(_to);
      if (!_isReminder && !end.isAfter(start)) {
        end = start.add(const Duration(hours: 1));
      }
      if (_isReminder) end = start;
      if (_e == null) {
        err = await repo.createEvent(
          title: title,
          start: start,
          end: end,
          allDay: _allDay,
          location: _location.text,
          colorIndex: _color,
          calendarId: _calendarId,
        );
      } else {
        err = await repo.updateEvent(
          _e!,
          title: title,
          start: start,
          end: end,
          allDay: _allDay,
          location: _location.text,
          colorIndex: _color,
        );
      }
    }
    repo.selectDay(_date);
    nav.pop();
    if (err != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(err), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _delete() async {
    final repo = context.read<CalendarRepository>();
    final nav = Navigator.of(context);
    await repo.deleteEvent(_e!);
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<CalendarRepository>();
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final editing = _e != null;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Material(
        color: AppColors.paper,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      editing
                          ? t(_isReminder ? 'Edit reminder' : 'Edit event')
                          : t('New'),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.5,
                      ),
                    ),
                  ),
                  if (!editing)
                    PillToggle(
                      labels: [t('Event'), t('Reminder')],
                      index: _isReminder ? 1 : 0,
                      onChanged: (i) => setState(() => _isReminder = i == 1),
                    ),
                  if (editing)
                    RoundIconButton(
                      icon: Icons.delete_outline,
                      onTap: _delete,
                      tooltip: t('Delete'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _title,
                autofocus: !editing,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: _isReminder ? t('Remind me to…') : t('Event title'),
                  border: InputBorder.none,
                ),
              ),
              const Divider(height: 8),
              const SizedBox(height: 8),
              _row(
                Icons.event_outlined,
                '${weekdayName(_date)}, ${fmtDate(_date)}',
                onTap: () async {
                  final d = await showCalDatePicker(
                    context,
                    initial: _date,
                    weekStartsMonday: repo.weekStartsMonday,
                  );
                  if (d != null) setState(() => _date = dateOnly(d));
                },
              ),
              if (!_isReminder)
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('All day'),
                  secondary: const Icon(Icons.wb_sunny_outlined),
                  value: _allDay,
                  onChanged: (v) => setState(() => _allDay = v),
                ),
              if (!_allDay)
                Row(
                  children: [
                    Expanded(
                      child: _row(
                        Icons.schedule,
                        _from.format(context),
                        onTap: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: _from,
                          );
                          if (t != null) {
                            setState(() {
                              final dur =
                                  (_to.hour * 60 + _to.minute) -
                                  (_from.hour * 60 + _from.minute);
                              _from = t;
                              final end =
                                  (t.hour * 60 +
                                          t.minute +
                                          (dur > 0 ? dur : 60))
                                      .clamp(0, 1439);
                              _to = TimeOfDay(
                                hour: end ~/ 60,
                                minute: end % 60,
                              );
                            });
                          }
                        },
                      ),
                    ),
                    if (!_isReminder) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: _row(
                          Icons.arrow_forward,
                          _to.format(context),
                          onTap: () async {
                            final t = await showTimePicker(
                              context: context,
                              initialTime: _to,
                            );
                            if (t != null) setState(() => _to = t);
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              if (!_isReminder) ...[
                TextField(
                  controller: _location,
                  decoration: InputDecoration(
                    icon: Icon(Icons.place_outlined),
                    hintText: t('Location'),
                    border: InputBorder.none,
                  ),
                ),
                if (!editing) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.sync, size: 22),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            isExpanded: true,
                            value: _calendarId,
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('This app only'),
                              ),
                              for (final c in repo.writableCalendars)
                                DropdownMenuItem(
                                  value: c.id,
                                  child: Text(
                                    c.accountName == null ||
                                            c.accountName == c.name
                                        ? c.name
                                        : '${c.name} · ${c.accountName}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (v) => setState(() => _calendarId = v),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (_calendarId == null &&
                    (_e == null || _e!.source == EventSource.local)) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.palette_outlined, size: 22),
                      const SizedBox(width: 16),
                      for (var i = 0; i < palettes.length; i++)
                        GestureDetector(
                          onTap: () => setState(() => _color = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.only(right: 10),
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: palettes[i].bg,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _color == i
                                    ? AppColors.ink
                                    : Colors.transparent,
                                width: 2.2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.ink,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(40),
                    ),
                  ),
                  onPressed: _saving ? null : _save,
                  child: Text(
                    editing
                        ? t('Save changes')
                        : (_isReminder ? t('Add reminder') : t('Add event')),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(IconData icon, String text, {required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 16),
            Flexible(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
