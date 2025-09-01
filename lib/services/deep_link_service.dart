// lib/services/deep_link_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import 'analytics_service.dart';

/// Handles creation and routing of shareable deep links.
class DeepLinkService {
  DeepLinkService._() {
    _initDynamicLinks();
  }

  static final DeepLinkService instance = DeepLinkService._();

  final _dynamicLinks = FirebaseDynamicLinks.instance;

  Future<Uri> createLink(String type, String id,
      {Map<String, String>? params}) async {
    final uri = Uri.https('colorcanvas.app', '/$type/$id', params);
    final link = DynamicLinkParameters(
      link: uri,
      uriPrefix: 'https://colorcanvas.page.link',
      androidParameters:
          const AndroidParameters(packageName: 'app.colorcanvas', minimumVersion: 0),
      iosParameters:
          const IOSParameters(bundleId: 'app.colorcanvas', minimumVersion: '0'),
    );
    final shortLink = await _dynamicLinks.buildShortLink(link);
    AnalyticsService.instance
        .logEvent('share_link_created', {'type': type});
    return shortLink.shortUrl;
  }

  Future<bool> ensureProjectShareable(
      BuildContext context, String projectId) async {
    final doc = await FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .get();
    final shareable = (doc.data()?['shareable'] as bool?) ?? false;
    if (shareable) return true;

    final enable = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enable Sharing?'),
        content: const Text(
            'This project is private. Enable sharing to generate a link?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Enable'),
          ),
        ],
      ),
    );

    if (enable == true) {
      await doc.reference.update({'shareable': true});
      return true;
    }
    return false;
  }

  void _initDynamicLinks() {
    _dynamicLinks.onLink.listen((data) {
      _handleLink(data.link);
    });
    _dynamicLinks.getInitialLink().then((data) {
      final link = data?.link;
      if (link != null) {
        _handleLink(link);
      }
    });
  }

  void _handleLink(Uri link) {
    final segments = link.pathSegments;
    if (segments.isEmpty) return;
    final type = segments.first;
    final id = segments.length > 1 ? segments[1] : null;
    final ref = link.queryParameters['ref'];
    if (ref != null) {
      SharedPreferences.getInstance().then((p) => p.setString('referrer', ref));
    }
    final navigator = MyApp.navigatorKey.currentState;
    switch (type) {
      case 'palette':
        navigator?.pushNamed('/roller', arguments: {
          'seedPaletteId': id,
        });
        break;
      case 'plan':
        if (id != null) {
          navigator?.pushNamed('/colorPlanDetail', arguments: id);
        }
        break;
      case 'viz':
        navigator?.pushNamed('/visualizer', arguments: {
          'jobId': id,
        });
        break;
    }
    AnalyticsService.instance
        .logEvent('share_link_opened', {'type': type});
  }
}
