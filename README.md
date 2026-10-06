# Glass Calendar

<p align="center">
  <img src="assets/banners/glass/readme-hero-1280x640.png" alt="Glass Calendar: your days, beautifully" width="100%">
</p>

<p align="center">
  <a href="assets/video/glass-calendar-promo.mp4"><img src="assets/video/poster.jpg" alt="Watch the 53-second promo (with voiceover)" width="70%"></a><br>
  <sub>▶ <a href="assets/video/glass-calendar-promo.mp4">Watch the 53-second promo</a> · voiceover by Kokoro (Apache-2.0), voice <code>af_heart</code></sub>
</p>


A Flutter calendar that combines three design directions:

- **Today / Calendar** (pastel cards): big `06.10 OCT` date, two world clocks, coloured task cards with start / end / duration, and a month switcher with colour-coded day cards, hour columns and `+` slots.
- **Six customizable widgets**: each can be glass, dark or light, and each keeps its own calendar and view.
  - **Calendar** (frosted glass): Week / Month / Agenda, a big month + day, *Add Reminder* and *New Event*.
  - **Week strip** (black pill): week or a compact month, with the event count.
  - **Date tile**: today, big, in any calendar, with holidays.
  - **Progress**: how much of the day, week, month or year has passed. Month and year follow the widget's calendar, so the Ethiopian year has 13 dots.
  - **Next up**: a countdown to the next event, or an agenda.
  - **Feasts & fasts**: today's fast and the next holidays.

## Ethiopian calendar & Amharic

*Settings → Calendar & language* (or the last onboarding page) switches between the
**Gregorian** and **Ethiopian (ዓ.ም)** calendars, and between **English** and **አማርኛ**.

- Ethiopian mode regroups everything by Ethiopian months, including the 13th month
  ጳጉሜ (5 days, 6 in leap years): the month grid, day cards, glass and island
  widgets, the date picker and the Android home-screen widgets.
- The Today screen always shows the same day in the other calendar next to the weekday.
- Conversion lives in `lib/core/ethiopian.dart` (Julian Day Number based) and is
  tested against known dates (Enkutatash, Genna, Timket, Meskel, Pagume 6, Adwa).
- Phones set to Amharic start in Amharic + Ethiopian by default.

## Holidays & fasting

Toggle each group in *Settings → Holidays*:

- **Ethiopian public holidays**: Enkutatash, Meskel, Genna, Timket, Adwa, Labour Day,
  Patriots' Victory Day, Ginbot 20, Siklet and Fasika.
- **Orthodox feasts & fasts**: Demera, Ketera, Kana Zegelila, Hidar Tsion, Kulubi Gabriel,
  Debre Zeit, Hosanna, Erget, Peraklitos, Buhe, Filseta; fasting seasons Abiy Tsom (55 days),
  Nenewe, Hawaryat, Filseta, Nebiyat (Advent), Gahad, and the Wednesday/Friday fasts
  (lifted for the 50 days after Fasika). Fasika uses the Julian computus that Bahire Hasab follows.
- **Islamic holidays**: Mawlid, Eid al-Fitr, Eid al-Adha, from the tabular Hijri calendar;
  the observed date can move by a day with the moon sighting.
- **Monthly saints' days** (off by default): Selassie, Mikael, Kidane Mihret, Gabriel,
  Mariam, Giorgis, Medhane Alem, Bale Wold.

Logic and tests: `lib/core/holidays.dart`, `test/holidays_test.dart`.

## Calendar faces on the widgets

Swipe the glass widget (or the island) between **Gregorian · Ethiopian · Islamic (Hijri) ·
Orthodox**. Each face shows its own month, year and day numbers plus what matters today:
week number, evangelist year (ዘመነ ሉቃስ), the Hijri date with the next Ramadan/Eid
countdown, or today's feast, saint and fast with the next major feast.

Every widget is its own instance: add as many widgets as you like
(Widgets tab → **Add widget**, or several on the home screen). Each keeps its own
calendar, view and style. Tap ⚙ on a widget to customize it with a live preview. On the Android home screen a picker asks which calendar a new widget shows
(long-press → Reconfigure to change it later on Android 12+), and the ⇄ chip cycles only
that widget.

## Reminders & notifications

- Reminders with quick times (in 1 hour · this evening · tomorrow 9:00 · pick), repeat
  daily/weekly, a progress ring, swipe to complete/delete and one-tap snooze.
- Phone notifications: alerts before events (5–60 min), reminders with **Done** and
  **Snooze 10 min** actions (work while the app is closed), and a morning briefing with
  today's events, holiday and fast. Exact alarms are used when allowed; everything is
  rescheduled automatically and after a reboot.

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
| Android | Six providers live in `android/.../CalendarWidgets.kt` and are fed by `home_widget`: `GlassWidgetProvider` (calendar), `IslandWidgetProvider` (week strip), `DateWidgetProvider`, `ProgressWidgetProvider`, `NextWidgetProvider` and `FeastsWidgetProvider`. When you add a widget, a picker sets its calendar, view and style (Android 12+ can reconfigure later). The calendar widget's **Auto** view opens up into a month when you resize it taller. Pin widgets from *Widgets → Home screen* in the app, or long-press the home screen. |
| iOS | Permissions and App Group id are set up (`group.com.kidyoh.glass_calendar`), but a WidgetKit extension target still has to be added in Xcode. |

Android widgets can't blur the wallpaper behind them (a platform limit), so the glass look
is a translucent tinted gradient with a luminous edge. The in-app glass widget uses a real
`BackdropFilter` blur.

## Store & social assets

- **Google Play listing** (fastlane `supply` layout, English + Amharic): `fastlane/metadata/android/{en-US,am}/`:
  feature graphic, icon, 7–8 phone screenshots, title and descriptions.
- **Banners**, three art directions (glass · pastel · night) × five sizes: `assets/banners/`.
- **GitHub social preview**: `.github/social-preview.png` (upload under Settings → Social preview).
- **Posters**, a numbered series (01 Today · 02 Calendar · 03 Widgets · 04 Ethiopian time · 05 Feasts & fasts) in square, portrait and wide: `assets/posters/`.
- **Promo video** 1920×1080, 53 s, real app interactions (taps, typing, live language switch) with narration: `assets/video/glass-calendar-promo.mp4`.
- Sources to regenerate all of it: `promo/`.

## Run

```bash
flutter pub get
flutter run            # Android / iOS device or emulator
flutter test
```
