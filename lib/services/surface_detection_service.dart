// 🔍 INTELLIGENT SURFACE DETECTION
// Computer vision for paintable surface identification

import 'dart:typed_data';
import '../services/gemini_ai_service.dart';

enum SpaceType { living, kitchen, bathroom, bedroom, exterior, office }
enum SurfaceType { walls, cabinets, trim, ceiling, shutters, doors }

class SurfaceDetectionService {
  
  // 🧠 SPACE TYPE MAPPING
  static const Map<String, SpaceType> _spaceTypeMap = {
    'living_room': SpaceType.living,
    'kitchen': SpaceType.kitchen,
    'bathroom': SpaceType.bathroom,
    'bedroom': SpaceType.bedroom,
    'exterior': SpaceType.exterior,
    'office': SpaceType.office,
  };
  
  // 🎯 SURFACE AVAILABILITY BY SPACE TYPE
  static const Map<SpaceType, List<SurfaceType>> _availableSurfaces = {
    SpaceType.living: [SurfaceType.walls, SurfaceType.trim, SurfaceType.ceiling],
    SpaceType.kitchen: [SurfaceType.walls, SurfaceType.cabinets, SurfaceType.trim],
    SpaceType.bathroom: [SurfaceType.walls, SurfaceType.cabinets, SurfaceType.trim],
    SpaceType.bedroom: [SurfaceType.walls, SurfaceType.trim, SurfaceType.ceiling],
    SpaceType.exterior: [SurfaceType.walls, SurfaceType.shutters, SurfaceType.doors, SurfaceType.trim],
    SpaceType.office: [SurfaceType.walls, SurfaceType.trim, SurfaceType.ceiling],
  };
  
  // 🏠 SURFACE ICONS
  static const Map<SurfaceType, String> _surfaceIcons = {
    SurfaceType.walls: '🏠',
    SurfaceType.cabinets: '🗄️',
    SurfaceType.trim: '📐',
    SurfaceType.ceiling: '⬆️',
    SurfaceType.shutters: '🪟',
    SurfaceType.doors: '🚪',
  };
  
  // 🎨 SURFACE DISPLAY NAMES
  static const Map<SurfaceType, String> _surfaceNames = {
    SurfaceType.walls: 'Walls',
    SurfaceType.cabinets: 'Cabinets',
    SurfaceType.trim: 'Trim & Molding',
    SurfaceType.ceiling: 'Ceiling',
    SurfaceType.shutters: 'Shutters',
    SurfaceType.doors: 'Doors',
  };
  
  // 🔬 ANALYZE UPLOADED IMAGE
  static Future<ImageAnalysisResult> analyzeImage(Uint8List imageBytes) async {
    try {
      final analysis = await GeminiAIService.analyzeSpace(imageBytes);
      
      final spaceType = _spaceTypeMap[analysis['space_type']] ?? SpaceType.living;
      final availableSurfaces = _getAvailableSurfaces(spaceType, analysis);
      final confidence = (analysis['quality_score'] as num?)?.toDouble() ?? 0.8;
      
      return ImageAnalysisResult(
        spaceType: spaceType,
        availableSurfaces: availableSurfaces,
        lightingConditions: analysis['lighting_conditions'] ?? 'natural',
        style: analysis['style'] ?? 'modern',
        dominantColors: List<String>.from(analysis['dominant_colors'] ?? ['#FFFFFF']),
        confidence: confidence,
        rawAnalysis: analysis,
      );
    } catch (e) {
      // Fallback to default analysis
      return ImageAnalysisResult(
        spaceType: SpaceType.living,
        availableSurfaces: [SurfaceType.walls],
        lightingConditions: 'natural',
        style: 'modern',
        dominantColors: ['#FFFFFF'],
        confidence: 0.5,
        rawAnalysis: {},
      );
    }
  }
  
  // 📋 GET AVAILABLE SURFACES
  static List<SurfaceType> _getAvailableSurfaces(
    SpaceType spaceType, 
    Map<String, dynamic> analysis
  ) {
    final baseSurfaces = _availableSurfaces[spaceType] ?? [SurfaceType.walls];
    final detectedSurfaces = List<String>.from(analysis['paintable_surfaces'] ?? []);
    
    // Filter based on actual detection
    return baseSurfaces.where((surface) {
      final surfaceName = _surfaceNames[surface]!.toLowerCase();
      return detectedSurfaces.any((detected) => 
          detected.toLowerCase().contains(surfaceName.split(' ')[0]));
    }).toList();
  }
  
  // 🎯 HELPER METHODS
  static String getSurfaceIcon(SurfaceType surface) => _surfaceIcons[surface] ?? '🏠';
  static String getSurfaceName(SurfaceType surface) => _surfaceNames[surface] ?? 'Unknown';
  static List<SurfaceType> getDefaultSurfaces(SpaceType spaceType) => 
      _availableSurfaces[spaceType] ?? [SurfaceType.walls];
  
  // 🔮 GENERATE MOCKUP RECOMMENDATION
  static MockupRecommendation generateMockupRecommendation(SpaceType spaceType) {
    switch (spaceType) {
      case SpaceType.kitchen:
        return MockupRecommendation(
          style: 'modern contemporary',
          description: 'Bright, airy kitchen with clean lines and natural light',
          defaultSurfaces: [SurfaceType.walls, SurfaceType.cabinets],
          recommendedColors: ['#F8F9FA', '#E9ECEF', '#ADB5BD'],
        );
      
      case SpaceType.living:
        return MockupRecommendation(
          style: 'cozy modern',
          description: 'Comfortable living space perfect for relaxation',
          defaultSurfaces: [SurfaceType.walls],
          recommendedColors: ['#F1F3F4', '#E8EAED', '#DADCE0'],
        );
      
      case SpaceType.bedroom:
        return MockupRecommendation(
          style: 'serene minimalist',
          description: 'Peaceful bedroom retreat with calming tones',
          defaultSurfaces: [SurfaceType.walls],
          recommendedColors: ['#FFF8E1', '#F3E5F5', '#E8F5E8'],
        );
      
      case SpaceType.bathroom:
        return MockupRecommendation(
          style: 'spa-like modern',
          description: 'Clean, refreshing bathroom with luxury finishes',
          defaultSurfaces: [SurfaceType.walls],
          recommendedColors: ['#F0F9FF', '#F0FDF4', '#FFFBEB'],
        );
      
      case SpaceType.exterior:
        return MockupRecommendation(
          style: 'classic contemporary',
          description: 'Beautiful home exterior with timeless appeal',
          defaultSurfaces: [SurfaceType.walls, SurfaceType.shutters, SurfaceType.doors],
          recommendedColors: ['#F5F5F5', '#2D3748', '#4A5568'],
        );
      
      case SpaceType.office:
        return MockupRecommendation(
          style: 'productive modern',
          description: 'Inspiring workspace designed for focus and creativity',
          defaultSurfaces: [SurfaceType.walls],
          recommendedColors: ['#F7FAFC', '#EDF2F7', '#E2E8F0'],
        );
    }
  }
}

// 📊 DATA MODELS
class ImageAnalysisResult {
  final SpaceType spaceType;
  final List<SurfaceType> availableSurfaces;
  final String lightingConditions;
  final String style;
  final List<String> dominantColors;
  final double confidence;
  final Map<String, dynamic> rawAnalysis;
  
  ImageAnalysisResult({
    required this.spaceType,
    required this.availableSurfaces,
    required this.lightingConditions,
    required this.style,
    required this.dominantColors,
    required this.confidence,
    required this.rawAnalysis,
  });
}

class MockupRecommendation {
  final String style;
  final String description;
  final List<SurfaceType> defaultSurfaces;
  final List<String> recommendedColors;
  
  MockupRecommendation({
    required this.style,
    required this.description,
    required this.defaultSurfaces,
    required this.recommendedColors,
  });
}
