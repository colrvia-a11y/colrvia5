// lib/models/color_filters.dart
import 'package:flutter/material.dart';

/// High-level filters for the All Colors grid and Explore rails.
class ColorFilters {
  String? colorFamily; // e.g., Red, Orange, Yellow, Green, Blue, Purple, Neutral, White, Black, Gray, Brown
  String? undertone; // e.g., green, blue, violet, yellow, red, neutral
  String? temperature; // Warm, Cool, Neutral
  RangeValues? lrvRange; // 0..100
  String? brandName; // Sherwin-Williams, Benjamin Moore, Behr, etc.
  bool? interior; // reserved for later
  bool? exterior; // reserved for later

  ColorFilters({
    this.colorFamily,
    this.undertone,
    this.temperature,
    this.lrvRange,
    this.brandName,
    this.interior,
    this.exterior,
  });

  ColorFilters copyWith({
    String? colorFamily,
    String? undertone,
    String? temperature,
    RangeValues? lrvRange,
    String? brandName,
    bool? interior,
    bool? exterior,
  }) {
    return ColorFilters(
      colorFamily: colorFamily ?? this.colorFamily,
      undertone: undertone ?? this.undertone,
      temperature: temperature ?? this.temperature,
      lrvRange: lrvRange ?? this.lrvRange,
      brandName: brandName ?? this.brandName,
      interior: interior ?? this.interior,
      exterior: exterior ?? this.exterior,
    );
  }

  bool get isEmpty =>
      colorFamily == null &&
      undertone == null &&
      temperature == null &&
      lrvRange == null &&
      brandName == null &&
      interior == null &&
      exterior == null;

  void clear() {
    colorFamily = null;
    undertone = null;
    temperature = null;
    lrvRange = null;
    brandName = null;
    interior = null;
    exterior = null;
  }

  @override
  String toString() => 'ColorFilters(colorFamily: $colorFamily, undertone: $undertone, temperature: $temperature, lrvRange: $lrvRange, brandName: $brandName)';
}
