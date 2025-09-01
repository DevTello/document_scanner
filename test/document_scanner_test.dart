import 'package:flutter_test/flutter_test.dart';
import 'package:document_scanner/document_scanner.dart';

void main() {
  group('DocumentScanner', () {
    test('creates default config correctly', () {
      const config = DocumentScannerConfig();
      expect(config.frameThickness, 4.0);
      expect(config.frameBorderRadius, 12.0);
      expect(config.framePadding, 24.0);
      expect(config.colorMode, ColorMode.color);
    });

    test('copyWith works correctly', () {
      const config = DocumentScannerConfig();
      final modified = config.copyWith(frameThickness: 6.0);
      
      expect(modified.frameThickness, 6.0);
      expect(modified.frameBorderRadius, 12.0); // unchanged
    });

    test('extension methods work correctly', () {
      const config = DocumentScannerConfig();
      final modified = config.withFrameAppearance(thickness: 8.0);
      
      expect(modified.frameThickness, 8.0);
      expect(modified.frameBorderRadius, 12.0); // unchanged
    });
  });
}
