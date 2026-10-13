# Glass Calendar on Google Play

Everything the Play Console asks for, in the order it asks. Signing and
building the upload are in [RELEASING.md](../RELEASING.md).

## Store listing

The text, icon (512 × 512), feature graphic (1024 × 500) and screenshots are
in `fastlane/metadata/android/en-US/` (English) and `am/` (Amharic). Copy them into **Grow → Store presence → Main store
listing**, or upload them with `fastlane supply` if you use fastlane.

| Field | Answer |
| --- | --- |
| App or game | App |
| Category | Productivity |
| Tags | Calendar, Productivity |
| Free or paid | Free |
| Privacy policy | https://kidus.pro.et/privacy/glass-calendar/ |

The privacy policy is a page on the portfolio site (`frontend/` in the
Kstore repo). The URL above works once the portfolio is deployed at
kidus.pro.et; if it's hosted elsewhere, use that address with
`/privacy/glass-calendar/`.

## Data safety

**Does your app collect or share any of the required user data types?** No.

Glass Calendar has no internet permission. It reads and writes the phone's
own calendars (Android's calendar provider) only to show and edit events on
the device. Google counts data as *collected* only when it leaves the device,
so nothing here is collected or shared. Syncing those calendars with Google,
Outlook and so on is done by Android and those accounts, not by the app.

## Permissions

| Permission | Why | Console |
| --- | --- | --- |
| `READ_CALENDAR`, `WRITE_CALENDAR` | Show and edit the phone's events | Not restricted; no form |
| `POST_NOTIFICATIONS` | Reminders | Not restricted |
| `SCHEDULE_EXACT_ALARM` | Reminders on the minute; the person allows it under "Alarms & reminders" | If asked about exact alarms: it's a calendar app and reminders are core functionality |
| `RECEIVE_BOOT_COMPLETED` | Reschedule reminders after a restart | Not restricted |

## Content rating (IARC questionnaire)

Category **Utility, Productivity, Communication or other**. Answer **No** to every question (no violence, sexual content, language, controlled substances, gambling, user interaction, sharing location or purchases). Expected rating: **Everyone / PEGI 3**.

## Target audience

**18 and over** (or 13 and over). It's a general calendar, not made for children; picking ages under 13 brings in the Families policy for no benefit.

## Store settings

| Field | Answer |
| --- | --- |
| Contact email | kidyoh789@gmail.com |
| Website | https://kidus.pro.et |
| Ads | No, the app has no ads |
| App access | All functionality is available without special access (no login) |
| Government app | No |
| Financial features | None |
| Health | None |

## Notes

- The Amharic listing (`am`) uses the same screenshots without captions.
