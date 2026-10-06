/// App-wide language + calendar system. Set by [CalendarRepository]; the UI
/// is rebuilt (home remounted) whenever either changes.
class AppLocale {
  static String lang = 'en'; // 'en' | 'am'
  static bool ethiopian = false;

  static bool get am => lang == 'am';
}

/// Translate an English UI string. Unknown strings fall back to English.
String t(String en) => AppLocale.am ? (_am[en] ?? en) : en;

const _am = <String, String>{
  // navigation / shell
  'Today': 'ዛሬ',
  'Tomorrow': 'ነገ',
  'Calendar': 'ቀን መቁጠሪያ',
  'Widgets': 'ዊጅቶች',
  'Settings': 'ቅንብሮች',
  'New event': 'አዲስ ክስተት',
  // today
  'Todays tasks': 'የዛሬ ተግባራት',
  'Reminders': 'ማስታወሻዎች',
  'A clear day. Enjoy it.': 'ነጻ ቀን ነው። ይደሰቱበት።',
  'Nothing planned.': 'ምንም የታቀደ ነገር የለም።',
  'Tap + to add an event': 'ክስተት ለመጨመር + ን ይንኩ',
  'Sync Google, iCloud & Outlook events':
      'የGoogle፣ iCloud እና Outlook ክስተቶችን ያመሳስሉ',
  'Connect': 'አገናኝ',
  'Start': 'መጀመሪያ',
  'End': 'መጨረሻ',
  'All day': 'ሙሉ ቀን',
  'Nothing to remember. Tap + to add one.': 'የሚታወስ ነገር የለም። ለመጨመር + ን ይንኩ።',
  'Add reminder': 'ማስታወሻ ጨምር',
  // calendar
  'No events this month': 'በዚህ ወር ምንም ክስተት የለም',
  'more': 'ተጨማሪ',
  // widgets
  'Glass': 'መስታወት',
  'Island': 'ደሴት',
  'Add glass widget to home screen': 'የመስታወት ዊጅቱን ወደ መነሻ ገጽ ጨምር',
  'Add island widget to home screen': 'የደሴት ዊጅቱን ወደ መነሻ ገጽ ጨምር',
  'Long-press your home screen → Widgets → Glass Calendar':
      'የመነሻ ገጽዎን ተጭነው ይያዙ → ዊጅቶች → Glass Calendar',
  'Weekly': 'ሳምንታዊ',
  'Monthly': 'ወርሃዊ',
  'Add Reminder': 'ማስታወሻ ጨምር',
  'New Event': 'አዲስ ክስተት',
  'Day': 'ቀን',
  'event': 'ክስተት',
  'events': 'ክስተቶች',
  'Next up': 'ቀጣይ',
  'happening now': 'አሁን እየተካሄደ',
  'All clear — nothing coming up': 'ሁሉም ነጻ ነው — የሚመጣ ነገር የለም',
  'No upcoming events': 'የሚመጣ ክስተት የለም',
  // editor
  'New': 'አዲስ',
  'Edit event': 'ክስተት አስተካክል',
  'Edit reminder': 'ማስታወሻ አስተካክል',
  'Event': 'ክስተት',
  'Reminder': 'ማስታወሻ',
  'Remind me to…': 'አስታውሰኝ…',
  'Event title': 'የክስተቱ ርዕስ',
  'Location': 'ቦታ',
  'This app only': 'በዚህ መተግበሪያ ብቻ',
  'Save changes': 'ለውጦችን አስቀምጥ',
  'Add event': 'ክስተት ጨምር',
  'Give it a title first': 'መጀመሪያ ርዕስ ይስጡት',
  'Delete': 'ሰርዝ',
  'Cancel': 'ተው',
  'OK': 'እሺ',
  // settings
  'Sync': 'ማመሳሰል',
  'Synced with your phone calendars': 'ከስልክዎ ቀን መቁጠሪያዎች ጋር ተመሳስሏል',
  'Calendar access is off': 'የቀን መቁጠሪያ ፈቃድ ጠፍቷል',
  'Device calendars unavailable here': 'እዚህ የመሣሪያ ቀን መቁጠሪያዎች አይገኙም',
  'Google, iCloud, Outlook and any other account added to your phone\'s calendar sync automatically — events you create here are written back to them.': 'Google፣ iCloud፣ Outlook እና በስልክዎ ቀን መቁጠሪያ ላይ የተጨመሩ ሌሎች መለያዎች በራስ-ሰር ይመሳሰላሉ — እዚህ የሚፈጥሯቸው ክስተቶችም ወደ እነሱ ይጻፋሉ።',
  'Connect calendars': 'ቀን መቁጠሪያዎችን አገናኝ',
  'Open system settings': 'የስርዓት ቅንብሮችን ክፈት',
  'Read only': 'ለንባብ ብቻ',
  'On device': 'በመሣሪያ ላይ',
  'Sync now': 'አሁን አመሳስል',
  'Today screen': 'የዛሬ ገጽ',
  'Second clock': 'ሁለተኛ ሰዓት',
  'Week starts on Monday': 'ሳምንቱ ሰኞ ይጀምራል',
  'Home screen widgets': 'የመነሻ ገጽ ዊጅቶች',
  'Calendar & language': 'የቀን አቆጣጠር እና ቋንቋ',
  'Calendar system': 'የቀን አቆጣጠር',
  'Ethiopian': 'ኢትዮጵያዊ',
  'Gregorian': 'ግሪጎሪያን',
  'Language': 'ቋንቋ',
  'Could not save to that calendar. Saved on this phone only.':
      'ወደዚያ ቀን መቁጠሪያ ማስቀመጥ አልተቻለም። በዚህ ስልክ ብቻ ተቀምጧል።',
  // onboarding
  'Skip': 'ዝለል',
  'Maybe later': 'በኋላ',
  'Connect my calendars': 'ቀን መቁጠሪያዎቼን አገናኝ',
  'WELCOME': 'እንኳን ደህና መጡ',
  'Your days,\nbeautifully.': 'ቀናትዎ፣\nበውበት።',
  'Tasks, meetings and reminders laid out in calm pastel cards.':
      'ተግባራት፣ ስብሰባዎችና ማስታወሻዎች በተረጋጉ ቀለማት ካርዶች ላይ።',
  'GLASS': 'መስታወት',
  'Frosted glass\nwidgets.': 'የበረዶ መስታወት\nዊጅቶች።',
  'A weekly glance that floats over your wallpaper. Pin it to your home screen.':
      'በግድግዳ ምስልዎ ላይ የሚንሳፈፍ ሳምንታዊ እይታ። ወደ መነሻ ገጽዎ ይሰኩት።',
  'ISLAND': 'ደሴት',
  'Everything\nat a glance.': 'ሁሉም ነገር\nበአንድ እይታ።',
  'Your week, how much of the day is left, and what\'s next. All in one black pill.':
      'ሳምንትዎ፣ ከቀኑ የቀረው ጊዜ እና ቀጣዩ ክስተት — በአንድ ጥቁር ሳጥን።',
  'SYNC': 'ማመሳሰል',
  'Bring all your\ncalendars.': 'ሁሉንም ቀን\nመቁጠሪያዎችዎን ያምጡ።',
  'Google, iCloud, Outlook. Anything on your phone shows up here, and stays in sync.':
      'Google፣ iCloud፣ Outlook። በስልክዎ ያለው ሁሉ እዚህ ይታያል፣ ተመሳስሎም ይቆያል።',
  'Design review': 'የዲዛይን ግምገማ',
  'You have\na meeting': 'ስብሰባ\nአለዎት',
  'Call Wiz': 'ዊዝን ይደውሉ',
};
