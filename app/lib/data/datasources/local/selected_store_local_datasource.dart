import 'package:shared_preferences/shared_preferences.dart';

/// Remembers which store the user last worked in, so a cold start does not
/// drop them into whichever store happens to sort first.
///
/// Only the id is kept. The store list is always re-fetched for the signed-in
/// account, and a remembered id is honoured only if it appears in that list —
/// so an id belonging to a previous account cannot select anything, it simply
/// falls through to the default. That filter is what makes this safe; the
/// explicit clear on StoreResetRequested is a tidy-up, not the guarantee —
/// not every sign-out path dispatches it.
class SelectedStoreLocalDatasource {
  static const _key = 'store.selectedId.v1';

  final SharedPreferences _prefs;

  SelectedStoreLocalDatasource(this._prefs);

  String? read() => _prefs.getString(_key);

  Future<void> save(String id) => _prefs.setString(_key, id);

  Future<void> clear() => _prefs.remove(_key);
}
