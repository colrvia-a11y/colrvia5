import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/ad.dart';

class AdsScreen extends StatefulWidget {
  const AdsScreen({super.key});

  @override
  State<AdsScreen> createState() => _AdsScreenState();
}

class _AdsScreenState extends State<AdsScreen> {
  // Sample ads data
  final List<Ad> ads = [
    Ad(
      id: '1',
      imageUrl: 'https://via.placeholder.com/150', // Placeholder image
      title: 'Special Offer on Paints',
      description: 'Get 20% off on all Sherwin-Williams paints this week!',
      link: 'https://www.sherwin-williams.com',
    ),
    Ad(
      id: '2',
      imageUrl: 'https://via.placeholder.com/150',
      title: 'New Color Trends',
      description: 'Discover the latest color trends for your home.',
      link: 'https://www.benjaminmoore.com',
    ),
    Ad(
      id: '3',
      imageUrl: 'https://via.placeholder.com/150',
      title: 'Interior Design Tips',
      description: 'Free tips to transform your space with colors.',
      link: 'https://www.behr.com',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ads'),
      ),
      body: ListView.builder(
        itemCount: ads.length,
        itemBuilder: (context, index) {
          final ad = ads[index];
          return Card(
            margin: const EdgeInsets.all(8.0),
            child: InkWell(
              onTap: () async {
                final url = Uri.parse(ad.link);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                } else {
                  // Handle error
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not launch link')),
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Image.network(
                      ad.imageUrl,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.image),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ad.title,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(ad.description),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
