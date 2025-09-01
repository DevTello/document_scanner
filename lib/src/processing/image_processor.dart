import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../config/document_scanner_config.dart';

/// Image processing engine for perspective correction and cropping
class ImageProcessor {
  final DocumentScannerConfig config;

  ImageProcessor(this.config);

  /// Process captured image with perspective correction and cropping
  Future<CapturedDocumentResult> processImage(
    Uint8List imageBytes,
    List<Offset> detectedCorners,
  ) async {
    try {
      // Load image with OpenCV
      final srcMat = cv.imdecode(imageBytes, cv.IMREAD_COLOR);
      if (srcMat.isEmpty) {
        throw Exception('Failed to decode image');
      }

      final originalSize = Size(
        srcMat.cols.toDouble(),
        srcMat.rows.toDouble(),
      );

      // Order corners for perspective transformation
      final orderedCorners = _orderCornersForTransform(detectedCorners);
      
      // Calculate destination size based on config
      final destSize = _calculateDestinationSize(orderedCorners);
      
      // Create destination corners for rectangular output
      final destCorners = [
        const Offset(0, 0),
        Offset(destSize.width, 0),
        Offset(destSize.width, destSize.height),
        Offset(0, destSize.height),
      ];

      // Perform perspective transformation
      final transformedMat = await _warpPerspectiveFallback(
        srcMat,
        orderedCorners,
        destSize,
      );

      // Apply color mode processing
      final processedMat = _applyColorMode(transformedMat);

      // Add padding if configured
      final finalMat = _addPadding(processedMat, destSize);

      // Save processed image
      final imagePath = await _saveProcessedImage(finalMat);

      // Dispose OpenCV resources
      srcMat.dispose();
      transformedMat.dispose();
      processedMat.dispose();
      finalMat.dispose();

      return CapturedDocumentResult(
        imagePath: imagePath,
        originalCorners: detectedCorners,
        croppedCorners: destCorners,
        originalSize: originalSize,
        croppedSize: Size(finalMat.cols.toDouble(), finalMat.rows.toDouble()),
        timestamp: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Image processing error: $e');
      rethrow;
    }
  }

  /// Order corners for perspective transformation (clockwise from top-left)
  List<Offset> _orderCornersForTransform(List<Offset> corners) {
    if (corners.length != 4) {
      throw ArgumentError('Expected exactly 4 corners');
    }

    // Create a copy to avoid modifying original
    final List<Offset> orderedCorners = List.from(corners);
    
    // Sort by y-coordinate first
    orderedCorners.sort((a, b) => a.dy.compareTo(b.dy));
    
    // Top two points: sort by x-coordinate
    final topPoints = [orderedCorners[0], orderedCorners[1]];
    topPoints.sort((a, b) => a.dx.compareTo(b.dx));
    
    // Bottom two points: sort by x-coordinate
    final bottomPoints = [orderedCorners[2], orderedCorners[3]];
    bottomPoints.sort((a, b) => a.dx.compareTo(b.dx));
    
    return [
      topPoints[0],    // Top-left
      topPoints[1],    // Top-right
      bottomPoints[1], // Bottom-right
      bottomPoints[0], // Bottom-left
    ];
  }

  /// Calculate destination size based on corner positions and config
  Size _calculateDestinationSize(List<Offset> corners) {
    // Calculate distances between corners
    final topWidth = _distance(corners[0], corners[1]);
    final bottomWidth = _distance(corners[3], corners[2]);
    final leftHeight = _distance(corners[0], corners[3]);
    final rightHeight = _distance(corners[1], corners[2]);

    // Use average dimensions
    final avgWidth = (topWidth + bottomWidth) / 2;
    final avgHeight = (leftHeight + rightHeight) / 2;

    // Apply output configuration
    if (config.outputLongSide != null) {
      final aspectRatio = avgWidth / avgHeight;
      final longSide = config.outputLongSide!.toDouble();
      
      if (avgWidth > avgHeight) {
        // Landscape
        return Size(longSide, longSide / aspectRatio);
      } else {
        // Portrait
        return Size(longSide * aspectRatio, longSide);
      }
    }

    if (config.outputAspectRatio != null) {
      final targetRatio = config.outputAspectRatio!;
      final currentRatio = avgWidth / avgHeight;
      
      if (currentRatio > targetRatio) {
        // Too wide, fit to height
        return Size(avgHeight * targetRatio, avgHeight);
      } else {
        // Too tall, fit to width
        return Size(avgWidth, avgWidth / targetRatio);
      }
    }

    // Use original dimensions
    return Size(avgWidth, avgHeight);
  }

  /// Calculate distance between two points
  double _distance(Offset a, Offset b) {
    return sqrt(pow(a.dx - b.dx, 2) + pow(a.dy - b.dy, 2));
  }

  /// Perform perspective transformation using simple cropping (fallback approach)
  Future<cv.Mat> _warpPerspectiveFallback(
    cv.Mat srcMat,
    List<Offset> srcCorners,
    Size dstSize,
  ) async {
    // For now, use simple cropping based on bounding rectangle
    // This is a fallback until OpenCV API is properly configured
    final boundingRect = _getBoundingRectFromCorners(srcCorners);
    
    final cropRect = cv.Rect(
      boundingRect.left.toInt().clamp(0, srcMat.cols - 1),
      boundingRect.top.toInt().clamp(0, srcMat.rows - 1),
      (boundingRect.width.toInt()).clamp(1, srcMat.cols - boundingRect.left.toInt()),
      (boundingRect.height.toInt()).clamp(1, srcMat.rows - boundingRect.top.toInt()),
    );

    final cropped = srcMat.region(cropRect);
    
    // Resize if needed
    if (dstSize.width > 0 && dstSize.height > 0) {
      final resized = cv.resize(
        cropped,
        (dstSize.width.toInt(), dstSize.height.toInt()),
      );
      cropped.dispose();
      return resized;
    }
    
    return cropped;
  }

  /// Apply color mode processing
  cv.Mat _applyColorMode(cv.Mat srcMat) {
    switch (config.colorMode) {
      case ColorMode.grayscale:
        final grayMat = cv.cvtColor(srcMat, cv.COLOR_BGR2GRAY);
        final rgbMat = cv.cvtColor(grayMat, cv.COLOR_GRAY2BGR);
        grayMat.dispose();
        return rgbMat;
      case ColorMode.color:
        return srcMat.clone();
    }
  }

  /// Add configurable padding around the document
  cv.Mat _addPadding(cv.Mat srcMat, Size originalSize) {
    if (config.documentPadding <= 0) {
      return srcMat.clone();
    }

    final paddingPixels = (originalSize.width * config.documentPadding).toInt();
    final newWidth = srcMat.cols + (paddingPixels * 2);
    final newHeight = srcMat.rows + (paddingPixels * 2);

    // Create padded image with white background
    final paddedMat = cv.Mat.zeros(
      newHeight,
      newWidth,
      srcMat.type,
    );
    
    // Fill with white
    paddedMat.setTo(cv.Scalar.all(255));

    // Copy original image to center
    final roi = cv.Rect(
      paddingPixels,
      paddingPixels,
      srcMat.cols,
      srcMat.rows,
    );
    
    srcMat.copyTo(paddedMat.region(roi));

    return paddedMat;
  }

  /// Save processed image and return file path
  Future<String> _saveProcessedImage(cv.Mat mat) async {
    try {
      // Encode image as JPEG
      final encodeResult = cv.imencode('.jpg', mat);
      final encoded = encodeResult.$2; // Extract bytes from tuple
      
      // Get app documents directory
      final directory = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${directory.path}/document_scanner');
      
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'document_$timestamp.jpg';
      final filePath = '${imagesDir.path}/$fileName';

      // Write file
      final file = File(filePath);
      await file.writeAsBytes(encoded);

      return filePath;
    } catch (e) {
      debugPrint('Error saving image: $e');
      rethrow;
    }
  }

  /// Alternative image processing using the image package (fallback)
  Future<CapturedDocumentResult> processImageWithDartImage(
    Uint8List imageBytes,
    List<Offset> detectedCorners,
  ) async {
    try {
      // Decode image
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      final originalSize = Size(
        image.width.toDouble(),
        image.height.toDouble(),
      );

      // For simple cropping without perspective correction
      final boundingRect = _getBoundingRectFromCorners(detectedCorners);
      
      // Add padding
      final padding = (image.width * config.documentPadding).toInt();
      final cropRect = _expandRect(boundingRect, padding, originalSize);

      // Crop image
      final croppedImage = img.copyCrop(
        image,
        x: cropRect.left.toInt(),
        y: cropRect.top.toInt(),
        width: cropRect.width.toInt(),
        height: cropRect.height.toInt(),
      );

      // Apply color mode
      final processedImage = _applyColorModeToImage(croppedImage);

      // Save image
      final imagePath = await _saveImageWithDartImage(processedImage);

      return CapturedDocumentResult(
        imagePath: imagePath,
        originalCorners: detectedCorners,
        croppedCorners: [
          Offset.zero,
          Offset(croppedImage.width.toDouble(), 0),
          Offset(croppedImage.width.toDouble(), croppedImage.height.toDouble()),
          Offset(0, croppedImage.height.toDouble()),
        ],
        originalSize: originalSize,
        croppedSize: Size(
          croppedImage.width.toDouble(),
          croppedImage.height.toDouble(),
        ),
        timestamp: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Dart image processing error: $e');
      rethrow;
    }
  }

  Rect _getBoundingRectFromCorners(List<Offset> corners) {
    double minX = corners[0].dx;
    double maxX = corners[0].dx;
    double minY = corners[0].dy;
    double maxY = corners[0].dy;

    for (final corner in corners) {
      minX = min(minX, corner.dx);
      maxX = max(maxX, corner.dx);
      minY = min(minY, corner.dy);
      maxY = max(maxY, corner.dy);
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  Rect _expandRect(Rect rect, int padding, Size imageSize) {
    return Rect.fromLTRB(
      max(0, rect.left - padding),
      max(0, rect.top - padding),
      min(imageSize.width, rect.right + padding),
      min(imageSize.height, rect.bottom + padding),
    );
  }

  img.Image _applyColorModeToImage(img.Image image) {
    switch (config.colorMode) {
      case ColorMode.grayscale:
        return img.grayscale(image);
      case ColorMode.color:
        return image;
    }
  }

  Future<String> _saveImageWithDartImage(img.Image image) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${directory.path}/document_scanner');
      
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'document_$timestamp.jpg';
      final filePath = '${imagesDir.path}/$fileName';

      final file = File(filePath);
      await file.writeAsBytes(img.encodeJpg(image));

      return filePath;
    } catch (e) {
      debugPrint('Error saving image with dart:image: $e');
      rethrow;
    }
  }
}
