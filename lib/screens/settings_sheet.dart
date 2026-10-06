import 'package:device_calendar_plus/device_calendar_plus.dart';
import 'package:flutter/material.dart';

import '../core/locale.dart';

import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../services/calendar_repository.dart';
import '../services/widget_sync.dart';
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
