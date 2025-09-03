class Ad {
  final String id;
  final String imageUrl;
  final String title;
  final String description;
  final String link;

  Ad({
    required this.id,
    required this.imageUrl,
    required this.title,
    required this.description,
    required this.link,
  });

  // Factory constructor for creating from JSON if needed later
  factory Ad.fromJson(Map<String, dynamic> json) {
    return Ad(
      id: json['id'],
      imageUrl: json['imageUrl'],
      title: json['title'],
      description: json['description'],
      link: json['link'],
    );
  }

  // To JSON if needed
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'imageUrl': imageUrl,
      'title': title,
      'description': description,
      'link': link,
    };
  }
}
