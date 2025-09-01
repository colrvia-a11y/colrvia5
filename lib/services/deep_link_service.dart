import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  static const _refKey = 'referrerId';

  Future<void> init() async {
    FirebaseDynamicLinks.instance.onLink.listen((data) {
      final ref = data.link.queryParameters['ref'];
      if (ref != null) _saveRef(ref);
    });
    final initial = await FirebaseDynamicLinks.instance.getInitialLink();
    final ref = initial?.link.queryParameters['ref'];
    if (ref != null) _saveRef(ref);
  }

  Future<void> _saveRef(String ref) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_refKey, ref);
  }

  Future<String?> getReferrerId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refKey);
  }
}
