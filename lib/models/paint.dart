// lib/models/paint.dart
class PaintColor {
  final String id; final String brand; final String name; final double lrv; final String undertone;
  final List<String> similarIds; final List<String> companionIds;
  const PaintColor({
    required this.id, required this.brand, required this.name, required this.lrv, required this.undertone,
    this.similarIds = const [], this.companionIds = const [],
  });
  factory PaintColor.fromJson(Map<String, dynamic> j) => PaintColor(
    id: j['id'], brand: j['brand'], name: j['name'], lrv: (j['lrv'] ?? 0).toDouble(), undertone: j['undertone'] ?? 'neutral',
    similarIds: (j['similarIds'] as List<dynamic>? ?? []).cast<String>(),
    companionIds: (j['companionIds'] as List<dynamic>? ?? []).cast<String>(),
  );
  Map<String, dynamic> toJson() => {
    'id': id, 'brand': brand, 'name': name, 'lrv': lrv, 'undertone': undertone,
    'similarIds': similarIds, 'companionIds': companionIds,
  };
}
