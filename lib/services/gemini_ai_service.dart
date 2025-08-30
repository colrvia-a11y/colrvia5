// 🤖 GEMINI 2.5 FLASH AI SERVICE
// Award-winning AI integration for photorealistic space transformation

import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiAIService {
  static const String _apiKey =
      'YOUR_GEMINI_API_KEY'; // Configure in environment
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta';

  // 🧠 INTELLIGENT SPACE ANALYSIS
  static Future<Map<String, dynamic>> analyzeSpace(Uint8List imageBytes) async {
    final response = await http.post(
      Uri.parse(
          '$_baseUrl/models/gemini-2.5-flash:generateContent?key=$_apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {
                'text':
                    '''Analyze this interior/exterior space image and provide a JSON response with:
              {
                "space_type": "living_room|kitchen|bathroom|bedroom|exterior|office",
                "paintable_surfaces": ["walls", "cabinets", "trim", "ceiling", "shutters", "doors"],
                "lighting_conditions": "natural|artificial|mixed",
                "style": "modern|traditional|contemporary|rustic|industrial",
                "dominant_colors": ["#hex1", "#hex2"],
                "surface_areas": {
                  "walls": "large|medium|small",
                  "cabinets": "none|present"
                },
                "perspective": "straight_on|angled|wide_shot|close_up",
                "quality_score": 0.95
              }'''
              },
              {
                'inline_data': {
                  'mime_type': 'image/jpeg',
                  'data': base64Encode(imageBytes)
                }
              }
            ]
          }
        ]
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final text = data['candidates'][0]['content']['parts'][0]['text'];
      return jsonDecode(text);
    }
    throw Exception('Failed to analyze space: ${response.statusCode}');
  }

  // 🎨 PHOTOREALISTIC COLOR TRANSFORMATION
  static Future<Uint8List> transformSpace({
    required Uint8List originalImage,
    required String spaceType,
    required Map<String, String> surfaceColors, // surface -> hex
    required String style,
  }) async {
    final prompt = _buildTransformPrompt(spaceType, surfaceColors, style);

    final response = await http.post(
      Uri.parse(
          '$_baseUrl/models/gemini-2.5-flash:generateContent?key=$_apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
              {
                'inline_data': {
                  'mime_type': 'image/jpeg',
                  'data': base64Encode(originalImage)
                }
              }
            ]
          }
        ],
        'generationConfig': {'response_mime_type': 'image/jpeg'}
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final imageData =
          data['candidates'][0]['content']['parts'][0]['inline_data']['data'];
      return base64Decode(imageData);
    }
    throw Exception('Failed to transform space: ${response.statusCode}');
  }

  // 🏗️ SMART PROMPT BUILDING
  static String _buildTransformPrompt(
      String spaceType, Map<String, String> surfaceColors, String style) {
    final colorInstructions = surfaceColors.entries
        .map((e) => 'Change the ${e.key} to color ${e.value}')
        .join(', ');

    switch (spaceType) {
      case 'kitchen':
        return '''Using the provided kitchen image, $colorInstructions while preserving all appliances, countertops, backsplash tiles, fixtures, and lighting exactly as they appear. Maintain the original photographic style, shadows, and reflections. The result should look completely realistic and professionally photographed.''';

      case 'bathroom':
        return '''Using the provided bathroom image, $colorInstructions while keeping all fixtures, tiles, mirrors, hardware, and accessories exactly the same. Preserve the original lighting, reflections, and photographic quality.''';

      case 'exterior':
        return '''Using the provided house exterior image, $colorInstructions while keeping the roof, windows, landscaping, driveway, and all architectural details exactly the same. Maintain the original lighting conditions and photographic style.''';

      default: // living room, bedroom, office
        return '''Using the provided $spaceType image, $colorInstructions while preserving all furniture, flooring, windows, lighting fixtures, artwork, and decorative elements exactly as they appear. Keep the original lighting, shadows, and photographic style completely intact.''';
    }
  }

  // 🖼️ GENERATE MOCKUP (NO PHOTO)
  static Future<Uint8List> generateMockup({
    required String spaceType,
    required String style,
    required Map<String, String> surfaceColors,
  }) async {
    final prompt = _buildMockupPrompt(spaceType, style, surfaceColors);

    final response = await http.post(
      Uri.parse(
          '$_baseUrl/models/gemini-2.5-flash:generateContent?key=$_apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {'response_mime_type': 'image/jpeg'}
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final imageData =
          data['candidates'][0]['content']['parts'][0]['inline_data']['data'];
      return base64Decode(imageData);
    }
    throw Exception('Failed to generate mockup: ${response.statusCode}');
  }

  static String _buildMockupPrompt(
      String spaceType, String style, Map<String, String> surfaceColors) {
    final wallColor = surfaceColors['walls'] ?? '#F5F5F5';

    switch (spaceType) {
      case 'kitchen':
        return '''Create a photorealistic $style kitchen interior with walls painted in $wallColor. Include modern appliances, countertops, and cabinetry. The scene should be illuminated by natural light from windows and under-cabinet lighting. Shot with professional interior photography, 24mm wide-angle lens, emphasizing the space and color harmony. Ultra-realistic, magazine-quality result.''';

      case 'living_room':
        return '''Create a photorealistic $style living room with walls painted in $wallColor. Include comfortable seating, coffee table, and tasteful decor. Natural light streaming through large windows creates warm, inviting atmosphere. Professional interior photography with 35mm lens, perfect lighting and composition.''';

      case 'bedroom':
        return '''Create a photorealistic $style bedroom with walls painted in $wallColor. Include a bed, nightstands, and minimal furniture. Soft, natural lighting creates a serene atmosphere. Professional interior photography emphasizing comfort and style.''';

      case 'bathroom':
        return '''Create a photorealistic $style bathroom with walls painted in $wallColor. Include modern fixtures, vanity, and mirror. Clean, bright lighting showcases the space beautifully. Professional architectural photography.''';

      case 'exterior':
        return '''Create a photorealistic $style house exterior with siding painted in $wallColor. Include landscaping, windows, and architectural details. Natural daylight with soft shadows. Professional architectural photography with 50mm lens.''';

      default:
        return '''Create a photorealistic $style interior space with walls painted in $wallColor. Professional interior photography with excellent lighting and composition.''';
    }
  }
}
