import 'package:shared_preferences/shared_preferences.dart';

/// Device-local vendor settings. There is no settings endpoint in the
/// backend, so nothing here hits the network — all values persist via
/// shared_preferences on this device only.
class VendorSettingsStore {
  const VendorSettingsStore();

  static const profileNameKey = 'vendor_profile_name';
  static const profilePhoneKey = 'vendor_profile_phone';
  static const profileAddressKey = 'vendor_profile_address';
  static const profileHoursKey = 'vendor_profile_hours';

  static const notifNewOrderKey = 'vendor_notif_new_order';
  static const notifCancelKey = 'vendor_notif_cancellation';
  static const notifSummaryKey = 'vendor_notif_summary';

  static String slotKey(String slot) => 'vendor_slot_$slot';
  static String dayKey(String day) => 'vendor_day_$day';

  static const defaultSlots = [
    'Morning \u2022 8:00 AM',
    'Noon \u2022 12:00 PM',
    'Evening \u2022 6:00 PM',
  ];
  static const defaultDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  Future<Map<String, String>> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString(profileNameKey) ?? '',
      'phone': prefs.getString(profilePhoneKey) ?? '',
      'address': prefs.getString(profileAddressKey) ?? '',
      'hours': prefs.getString(profileHoursKey) ?? '',
    };
  }

  Future<void> saveProfile(
      {required String name,
      required String phone,
      required String address,
      required String hours}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(profileNameKey, name);
    await prefs.setString(profilePhoneKey, phone);
    await prefs.setString(profileAddressKey, address);
    await prefs.setString(profileHoursKey, hours);
  }

  Future<Map<String, bool>> loadSlots({List<String>? slots}) async {
    final prefs = await SharedPreferences.getInstance();
    final out = <String, bool>{};
    for (final s in slots ?? defaultSlots) {
      out[s] = prefs.getBool(slotKey(s)) ?? true;
    }
    return out;
  }

  Future<void> saveSlot(String slot, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(slotKey(slot), value);
  }

  Future<Map<String, bool>> loadDays({List<String>? days}) async {
    final prefs = await SharedPreferences.getInstance();
    final out = <String, bool>{};
    for (final d in days ?? defaultDays) {
      out[d] = prefs.getBool(dayKey(d)) ?? true;
    }
    return out;
  }

  Future<void> saveDay(String day, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(dayKey(day), value);
  }

  Future<Map<String, bool>> loadNotifs() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'newOrder': prefs.getBool(notifNewOrderKey) ?? true,
      'cancellation': prefs.getBool(notifCancelKey) ?? true,
      'summary': prefs.getBool(notifSummaryKey) ?? false,
    };
  }

  Future<void> saveNotif(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    switch (key) {
      case 'newOrder':
        await prefs.setBool(notifNewOrderKey, value);
      case 'cancellation':
        await prefs.setBool(notifCancelKey, value);
      case 'summary':
        await prefs.setBool(notifSummaryKey, value);
    }
  }
}
