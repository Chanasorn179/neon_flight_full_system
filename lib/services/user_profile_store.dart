import 'firebase_service.dart';

/// Personal details and passport kept on `users/{uid}` (firestore.rules lets
/// only the owner read or write that document). Without Firebase (mock mode)
/// the data lives in memory for the session.
class ProfileStore {
  static final Map<String, Map<String, dynamic>> _memory = {};

  static Future<Map<String, dynamic>> load(String uid) async {
    if (!FirebaseService.enabled) return Map.of(_memory[uid] ?? const {});
    final doc = await FirebaseService.firestore.collection('users').doc(uid).get();
    return doc.data() ?? {};
  }

  /// Merges [data] into the user's document.
  static Future<void> save(String uid, Map<String, dynamic> data) async {
    if (!FirebaseService.enabled) {
      _memory[uid] = {...?_memory[uid], ...data};
      return;
    }
    await FirebaseService.saveProfile(uid, data);
  }
}
