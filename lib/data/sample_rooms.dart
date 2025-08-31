// lib/data/sample_rooms.dart
class SampleRoom {
  final String id;
  final String title;
  final String assetPath;
  const SampleRoom(this.id, this.title, this.assetPath);
}

const sampleRooms = [
  SampleRoom('living1', 'Modern Living', 'assets/sample_rooms/living1.jpg'),
  SampleRoom('kitchen1', 'Bright Kitchen', 'assets/sample_rooms/kitchen1.jpg'),
  SampleRoom('bed1', 'Cozy Bedroom', 'assets/sample_rooms/bed1.jpg'),
];

