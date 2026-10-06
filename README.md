# Glass Calendar

A Flutter calendar that combines three design directions:

- **Today / Calendar** (pastel cards): big `06.10 OCT` date, two world clocks, coloured task cards with start / end / duration, and a month switcher with colour-coded day cards, hour columns and `+` slots.
- **Glass widget** (frosted glassmorphism): Weekly / Monthly toggle, big month + day, week strip with event dots, *Add Reminder* and *New Event* actions.
- **Island widgets** (black pills): week strip with event count, "Day 67%" hourly dot grid, and a *Next up* countdown card.

## Sync with other apps

Events are read from, and written to, the phone's calendar database via
[`device_calendar_plus`](https://pub.dev/packages/device_calendar_plus). Anything
that syncs to the OS calendar (Google Calendar, iCloud, Outlook/Exchange, Samsung, …)
shows up automatically, and events created in the app can be saved straight into any
writable account. Calendars can be toggled on/off in *Settings*. Without permission
the app still works with local-only events and reminders.

## Home-screen widgets

| Platform | Status |
| --- | --- |
| Android | `GlassWidgetProvider` (frosted glass) and `IslandWidgetProvider` (black) in `android/.../CalendarWidgets.kt`, fed by `home_widget`. Use *Widgets → Add to home screen* in the app, or long-press the home screen. |
| iOS | Permissions and App Group id are set up (`group.com.kidyoh.glass_calendar`), but a WidgetKit extension target still has to be added in Xcode. |

Android widgets can't blur the wallpaper behind them (a platform limit), so the glass look
is a translucent tinted gradient with a luminous edge. The in-app glass widget uses a real
`BackdropFilter` blur.

## Run

```bash
flutter pub get
flutter run            # Android / iOS device or emulator
flutter test
```
