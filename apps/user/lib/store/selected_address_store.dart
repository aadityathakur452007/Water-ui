import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the selected delivery address id across Home/Cart/Addresses.
/// ChangeNotifier (no new state lib); backed by SharedPreferences.
class SelectedAddressStore extends ChangeNotifier {
  static const key = 'selected_address_id';

  String? _selectedId;
  String? get selectedId => _selectedId;

  /// Loads the persisted id. Call once at startup.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(key);
    if (id != _selectedId) {
      _selectedId = (id == null || id.isEmpty) ? null : id;
      notifyListeners();
    }
  }

  /// Persists + notifies. Null clears the selection.
  Future<void> select(String? id) async {
    if (id == _selectedId) return;
    _selectedId = (id == null || id.isEmpty) ? null : id;
    final prefs = await SharedPreferences.getInstance();
    if (_selectedId == null) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, _selectedId!);
    }
    notifyListeners();
  }

  /// Resolves a valid selection against [ids]: persisted id when present,
  /// else the first id, else null. Persists the resolved value.
  Future<String?> syncWith(List<String> ids) async {
    final valid =
        (_selectedId != null && ids.contains(_selectedId)) ? _selectedId : ids.firstOrNull;
    await select(valid);
    return _selectedId;
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
