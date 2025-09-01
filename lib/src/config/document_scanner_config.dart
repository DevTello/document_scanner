import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

/// Configuration class for DocumentScanner with all customizable options
class DocumentScannerConfig {
  /// Camera preview configuration
  final Size? previewSize;
  final ResolutionPreset resolutionPreset;
  final CameraLensDirection cameraLensDirection;

  /// Frame appearance configuration
  final double frameThickness;
  final double frameBorderRadius;
  final double framePadding;
  final Color frameColorIdle;
  final Color frameColorDetected;
  final Duration frameColorAnimationDuration;

  /// Detection configuration
  final Duration documentStabilityDuration;
  final double documentDetectionSensitivity;
  final double minimumDocumentArea;

  /// Output configuration
  final int? outputLongSide;
  final double? outputAspectRatio;
  final ColorMode colorMode;
  final double documentPadding;

  /// Callback configuration
  final bool enableHapticFeedback;
  final bool enableAudioFeedback;

  const DocumentScannerConfig({
    // Camera configuration
    this.previewSize,
    this.resolutionPreset = ResolutionPreset.high,
    this.cameraLensDirection = CameraLensDirection.back,

    // Frame configuration
    this.frameThickness = 4.0,
    this.frameBorderRadius = 12.0,
    this.framePadding = 24.0,
    this.frameColorIdle = Colors.white,
    this.frameColorDetected = Colors.green,
    this.frameColorAnimationDuration = const Duration(milliseconds: 300),

    // Detection configuration
    this.documentStabilityDuration = const Duration(seconds: 1),
    this.documentDetectionSensitivity = 0.7,
    this.minimumDocumentArea = 0.1,

    // Output configuration
    this.outputLongSide,
    this.outputAspectRatio,
    this.colorMode = ColorMode.color,
    this.documentPadding = 0.05,

    // Feedback configuration
    this.enableHapticFeedback = true,
    this.enableAudioFeedback = false,
  });

  DocumentScannerConfig copyWith({
    Size? previewSize,
    ResolutionPreset? resolutionPreset,
    CameraLensDirection? cameraLensDirection,
    double? frameThickness,
    double? frameBorderRadius,
    double? framePadding,
    Color? frameColorIdle,
    Color? frameColorDetected,
    Duration? frameColorAnimationDuration,
    Duration? documentStabilityDuration,
    double? documentDetectionSensitivity,
    double? minimumDocumentArea,
    int? outputLongSide,
    double? outputAspectRatio,
    ColorMode? colorMode,
    double? documentPadding,
    bool? enableHapticFeedback,
    bool? enableAudioFeedback,
  }) {
    return DocumentScannerConfig(
      previewSize: previewSize ?? this.previewSize,
      resolutionPreset: resolutionPreset ?? this.resolutionPreset,
      cameraLensDirection: cameraLensDirection ?? this.cameraLensDirection,
      frameThickness: frameThickness ?? this.frameThickness,
      frameBorderRadius: frameBorderRadius ?? this.frameBorderRadius,
      framePadding: framePadding ?? this.framePadding,
      frameColorIdle: frameColorIdle ?? this.frameColorIdle,
      frameColorDetected: frameColorDetected ?? this.frameColorDetected,
      frameColorAnimationDuration: frameColorAnimationDuration ?? this.frameColorAnimationDuration,
      documentStabilityDuration: documentStabilityDuration ?? this.documentStabilityDuration,
      documentDetectionSensitivity: documentDetectionSensitivity ?? this.documentDetectionSensitivity,
      minimumDocumentArea: minimumDocumentArea ?? this.minimumDocumentArea,
      outputLongSide: outputLongSide ?? this.outputLongSide,
      outputAspectRatio: outputAspectRatio ?? this.outputAspectRatio,
      colorMode: colorMode ?? this.colorMode,
      documentPadding: documentPadding ?? this.documentPadding,
      enableHapticFeedback: enableHapticFeedback ?? this.enableHapticFeedback,
      enableAudioFeedback: enableAudioFeedback ?? this.enableAudioFeedback,
    );
  }
}

/// Color mode for output image processing
enum ColorMode {
  color,
  grayscale,
}

/// Document detection result
class DocumentDetectionResult {
  final bool isDetected;
  final List<Offset>? corners;
  final double confidence;
  final Rect? boundingRect;

  const DocumentDetectionResult({
    required this.isDetected,
    this.corners,
    required this.confidence,
    this.boundingRect,
  });

  DocumentDetectionResult.notDetected()
      : isDetected = false,
        corners = null,
        confidence = 0.0,
        boundingRect = null;
}

/// Captured document result
class CapturedDocumentResult {
  final String imagePath;
  final List<Offset> originalCorners;
  final List<Offset> croppedCorners;
  final Size originalSize;
  final Size croppedSize;
  final DateTime timestamp;

  const CapturedDocumentResult({
    required this.imagePath,
    required this.originalCorners,
    required this.croppedCorners,
    required this.originalSize,
    required this.croppedSize,
    required this.timestamp,
  });
}
