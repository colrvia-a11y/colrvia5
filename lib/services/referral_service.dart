import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'deep_link_service.dart';
import 'analytics_service.dart';

class ReferralService {
  ReferralService._();
  static final ReferralService instance = ReferralService._();

  String _codeFor(String uid) => base64Url.encode(utf8.encode(uid)).substring(0, 6);

  Future<void> shareReferral(String uid) async {
    final code = _codeFor(uid);
    final link = await DeepLinkService.instance
        .createLink('app', 'start', params: {'ref': code});
    await Share.share('Try ColorCanvas: $link');
    AnalyticsService.instance.logEvent('ref_link_created');
  }

  Future<int> getBonusRenders(String? uid) async {
    if (uid == null) return 0;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('meta')
        .doc('rewards')
        .get();
    return (doc.data()?['hq_bonus'] as int?) ?? 0;
  }

  Future<void> applyPendingReferral(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final ref = prefs.getString('referrer');
    if (ref != null) {
      await FirebaseFunctions.instance
          .httpsCallable('awardReferral')
          .call({'referrerId': ref, 'referredId': uid});
      await prefs.remove('referrer');
      AnalyticsService.instance.logEvent('ref_attributed');
    }
  }
}
