import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'analytics_service.dart';

class ReferralService {
  ReferralService._();
  static final ReferralService instance = ReferralService._();

  String _codeFromUid(String uid) => uid.substring(0, 6);

  Future<void> createAndShareLink() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final code = _codeFromUid(uid);
    final params = DynamicLinkParameters(
      uriPrefix: 'https://example.page.link',
      link: Uri.parse('https://example.com/?ref=$code'),
      androidParameters: const AndroidParameters(packageName: 'com.example'),
      iosParameters: const IOSParameters(bundleId: 'com.example'),
    );
    final shortLink = await FirebaseDynamicLinks.instance.buildShortLink(params);
    await Share.share(shortLink.shortUrl.toString());
    AnalyticsService.instance.logEvent('ref_link_created');
  }

  Future<void> awardReferral(String referrerId) async {
    final callable = FirebaseFunctions.instance.httpsCallable('awardReferral');
    await callable.call({'referrerId': referrerId});
  }
}
