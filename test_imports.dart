// Test file to verify package imports
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

void testImports() {
  final logger = Logger('Test');
  logger.info('Packages are working correctly');
  
  // Test rootBundle access (verify it's accessible)
  try {
    final bundle = rootBundle;
    logger.info('rootBundle is available and accessible: ${bundle.runtimeType}');
  } catch (e) {
    logger.warning('rootBundle access failed: $e');
  }
}
