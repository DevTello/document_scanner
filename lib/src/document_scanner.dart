import 'package:flutter/material.dart';
import 'config/document_scanner_config.dart';
import 'widgets/document_scanner_widget.dart';

/// Main DocumentScanner class providing the public API
class DocumentScanner {
  /// Create a document scanner widget with the given configuration
  static Widget create({
    required DocumentScannerConfig config,
    required Function(CapturedDocumentResult) onDocumentCaptured,
    VoidCallback? onError,
    Key? key,
  }) {
    return DocumentScannerWidget(
      key: key,
      config: config,
      onDocumentCaptured: onDocumentCaptured,
      onError: onError,
    );
  }

  /// Create a document scanner with default configuration
  static Widget createDefault({
    required Function(CapturedDocumentResult) onDocumentCaptured,
    VoidCallback? onError,
    Key? key,
  }) {
    return create(
      config: const DocumentScannerConfig(),
      onDocumentCaptured: onDocumentCaptured,
      onError: onError,
      key: key,
    );
  }

  /// Request camera permissions (handled automatically by camera package)
  static Future<bool> requestPermissions() async {
    // Camera permissions are automatically handled by the camera package
    // Users should add camera permissions to their app's AndroidManifest.xml
    return true;
  }

  /// Check if camera permissions are granted (handled automatically by camera package)
  static Future<bool> hasPermissions() async {
    // Camera permissions are automatically handled by the camera package
    // Users should add camera permissions to their app's AndroidManifest.xml
    return true;
  }
}

/// Extension methods for DocumentScannerConfig for easier configuration
extension DocumentScannerConfigExtensions on DocumentScannerConfig {
  /// Create a copy with modified frame appearance
  DocumentScannerConfig withFrameAppearance({
    double? thickness,
    double? borderRadius,
    double? padding,
    Color? idleColor,
    Color? detectedColor,
  }) {
    return copyWith(
      frameThickness: thickness ?? frameThickness,
      frameBorderRadius: borderRadius ?? frameBorderRadius,
      framePadding: padding ?? framePadding,
      frameColorIdle: idleColor ?? frameColorIdle,
      frameColorDetected: detectedColor ?? frameColorDetected,
    );
  }

  /// Create a copy with modified detection settings
  DocumentScannerConfig withDetectionSettings({
    Duration? stabilityDuration,
    double? sensitivity,
    double? minimumArea,
  }) {
    return copyWith(
      documentStabilityDuration: stabilityDuration ?? documentStabilityDuration,
      documentDetectionSensitivity: sensitivity ?? documentDetectionSensitivity,
      minimumDocumentArea: minimumArea ?? minimumDocumentArea,
    );
  }

  /// Create a copy with modified output settings
  DocumentScannerConfig withOutputSettings({
    int? longSide,
    double? aspectRatio,
    ColorMode? colorMode,
    double? padding,
  }) {
    return copyWith(
      outputLongSide: longSide ?? outputLongSide,
      outputAspectRatio: aspectRatio ?? outputAspectRatio,
      colorMode: colorMode ?? this.colorMode,
      documentPadding: padding ?? documentPadding,
    );
  }
}
