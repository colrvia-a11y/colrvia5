import 'package:flutter/material.dart';

import '../models/lighting_profile.dart';

/// Simple bottom sheet for choosing a lighting profile during photo import.
Future<LightingProfile?> showLightingProfilePicker(
  BuildContext context, {
  required LightingProfile current,
}) {
  LightingProfile temp = current;
  return showModalBottomSheet<LightingProfile>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Lighting Profile',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                ...LightingProfile.values.map(
                  (p) => ListTile(
                    title: Text(p.label),
                    leading: Radio<LightingProfile>(
                      value: p,
                      groupValue: temp,
                      onChanged: (v) => setState(() => temp = v ?? temp),
                    ),
                    onTap: () {
                      if (p != temp) {
                        setState(() => temp = p);
                      }
                    },
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(temp),
                  child: const Text('Done'),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}