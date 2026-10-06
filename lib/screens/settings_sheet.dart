import 'package:device_calendar_plus/device_calendar_plus.dart';
import 'package:flutter/material.dart';

import '../core/dates.dart';
import '../core/holidays.dart';
import '../core/locale.dart';

import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../services/calendar_repository.dart';
import '../services/notification_service.dart';
import '../services/widget_sync.dart';
import '../widgets/holiday_views.dart';
import '../widgets/common.dart';

Future<void> showSettingsSheet(BuildContext context) {
  final repo = context.read<CalendarRepository>();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ChangeNotifierProvider.value(
      value: repo,
      child: const _SettingsSheet(),
    ),
  );
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<CalendarRepository>();
    final granted = repo.hasDeviceAccess;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .8,
      minChildSize: .5,
      maxChildSize: .95,
      builder: (context, controller) => Material(
        color: AppColors.paper,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
        clipBehavior: Clip.antiAlias,
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),
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
            Text(
              t('Settings'),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -.6,
              ),
            ),
            const SizedBox(height: 18),
            _section(t('Calendar & language')),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('Calendar system'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: PillToggle(
                      labels: [t('Gregorian'), '${t('Ethiopian')} · ዓ.ም'],
                      index: repo.ethiopian ? 1 : 0,
                      onChanged: (i) => repo.setEthiopian(i == 1),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    t('Language'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  PillToggle(
                    labels: const ['English', 'አማርኛ'],
                    index: repo.language == 'am' ? 1 : 0,
                    onChanged: (i) => repo.setLanguage(i == 1 ? 'am' : 'en'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _section(t('Holidays')),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 8, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (kind, label) in [
                      (HolidayKind.national, t('Ethiopian public holidays')),
                      (HolidayKind.orthodox, t('Orthodox feasts & fasts')),
                      (HolidayKind.islamic, t('Islamic holidays')),
                      (HolidayKind.saint, t('Monthly saints\' days')),
                    ])
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        secondary: Icon(holidayIcon(kind)),
                        title: Text(
                          label,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        value: switch (kind) {
                          HolidayKind.national => repo.showNational,
                          HolidayKind.orthodox => repo.showOrthodox,
                          HolidayKind.islamic => repo.showIslamic,
                          HolidayKind.saint => repo.showSaints,
                        },
                        onChanged: (v) => repo.setHolidayCategory(kind, v),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        t(
                          'Islamic dates follow the moon and may move by a day.',
                        ),
                        style: const TextStyle(
                          color: AppColors.mute,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            _section(t('Notifications')),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 8, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.event_available_outlined),
                      title: Text(
                        t('Event alerts'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      value: repo.notify.events,
                      onChanged: (v) => repo.setNotify((n) => n.events = v),
                    ),
                    if (repo.notify.events)
                      Padding(
                        padding: const EdgeInsets.only(left: 56, bottom: 4),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            for (final m in const [5, 10, 15, 30, 60])
                              ChoiceChip(
                                label: Text('$m'),
                                selected: repo.notify.eventLead == m,
                                onSelected: (_) =>
                                    repo.setNotify((n) => n.eventLead = m),
                                selectedColor: AppColors.ink,
                                labelStyle: TextStyle(
                                  color: repo.notify.eventLead == m
                                      ? Colors.white
                                      : AppColors.ink,
                                  fontWeight: FontWeight.w700,
                                ),
                                showCheckmark: false,
                                shape: const StadiumBorder(),
                              ),
                            Text(
                              t('minutes before'),
                              style: const TextStyle(color: AppColors.mute),
                            ),
                          ],
                        ),
                      ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(
                        Icons.notifications_active_outlined,
                      ),
                      title: Text(
                        t('Reminders'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      value: repo.notify.reminders,
                      onChanged: (v) => repo.setNotify((n) => n.reminders = v),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.wb_twilight_rounded),
                      title: Text(
                        t('Morning briefing'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: GestureDetector(
                        onTap: () async {
                          final tm = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(
                              hour: repo.notify.briefingHour,
                              minute: repo.notify.briefingMinute,
                            ),
                          );
                          if (tm != null) {
                            await repo.setNotify(
                              (n) => n
                                ..briefingHour = tm.hour
                                ..briefingMinute = tm.minute,
                            );
                          }
                        },
                        child: Text(
                          fmtTime(
                            DateTime(
                              2000,
                              1,
                              1,
                              repo.notify.briefingHour,
                              repo.notify.briefingMinute,
                            ),
                          ),
                          style: const TextStyle(
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      value: repo.notify.briefing,
                      onChanged: (v) => repo.setNotify((n) => n.briefing = v),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.church_outlined),
                      title: Text(
                        t('Holiday & fast alerts'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      value: repo.notify.holidays,
                      onChanged: (v) => repo.setNotify((n) => n.holidays = v),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.ink,
                          ),
                          onPressed: () async {
                            await NotificationService.requestPermission();
                            await NotificationService.showTest(
                              repo.eventsOn(DateTime.now()),
                            );
                          },
                          icon: const Icon(
                            Icons.notifications_rounded,
                            size: 18,
                          ),
                          label: Text(t('Send test notification')),
                        ),
                        OutlinedButton(
                          onPressed: () async {
                            await NotificationService.requestPermission();
                            await repo.setNotify((_) {});
                          },
                          child: Text(t('Turn on notifications')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            _section(t('Sync')),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        granted
                            ? Icons.check_circle
                            : Icons.sync_problem_outlined,
                        color: granted
                            ? const Color(0xFF2E7D32)
                            : AppColors.mute,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          granted
                              ? t('Synced with your phone calendars')
                              : repo.deviceSyncSupported
                              ? t('Calendar access is off')
                              : t('Device calendars unavailable here'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t(
                      'Google, iCloud, Outlook and any other account added to your phone\'s calendar sync automatically — events you create here are written back to them.',
                    ),
                    style: TextStyle(color: AppColors.mute, height: 1.35),
                  ),
                  if (!granted && repo.deviceSyncSupported) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      children: [
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.ink,
                          ),
                          onPressed: repo.connectDeviceCalendars,
                          child: Text(t('Connect calendars')),
                        ),
                        if (repo.permission ==
                                CalendarPermissionStatus.denied ||
                            repo.permission ==
                                CalendarPermissionStatus.restricted)
                          OutlinedButton(
                            onPressed: repo.openSystemSettings,
                            child: Text(t('Open system settings')),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (granted) ...[
              const SizedBox(height: 10),
              for (final c in repo.calendars)
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    c.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    c.accountName ??
                        (c.readOnly ? t('Read only') : t('On device')),
                  ),
                  value: !repo.hiddenCalendarIds.contains(c.id),
                  onChanged: (v) => repo.setCalendarVisible(c.id, v),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: repo.reload,
                  icon: const Icon(Icons.refresh),
                  label: Text(t('Sync now')),
                ),
              ),
            ],
            const SizedBox(height: 14),
            _section(t('Today screen')),
            Row(
              children: [
                Expanded(
                  child: Text(
                    t('Second clock'),
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DropdownButton<String>(
                  value: repo.secondZone,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final e in zoneChoices.entries)
                      DropdownMenuItem(value: e.key, child: Text(t(e.value))),
                  ],
                  onChanged: (v) => v == null ? null : repo.setSecondZone(v),
                ),
              ],
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(
                t('Week starts on Monday'),
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              value: repo.weekStartsMonday,
              onChanged: repo.setWeekStartsMonday,
            ),
            const SizedBox(height: 14),
            _section(t('Home screen widgets')),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final ok = await WidgetSync.pin(glassWidgetName);
                      if (context.mounted && !ok) {
                        showSnack(
                          context,
                          t(
                            'Long-press your home screen → Widgets → Glass Calendar',
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.blur_on),
                    label: Text(t('Glass')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final ok = await WidgetSync.pin(islandWidgetName);
                      if (context.mounted && !ok) {
                        showSnack(
                          context,
                          t(
                            'Long-press your home screen → Widgets → Glass Calendar',
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.view_week_outlined),
                    label: Text(t('Island')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: AppColors.mute,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    ),
  );
}
