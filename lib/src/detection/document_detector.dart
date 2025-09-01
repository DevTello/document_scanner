import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;
import '../config/document_scanner_config.dart';

/// Document detection engine using OpenCV
class DocumentDetector {
  final DocumentScannerConfig config;
  
  DocumentDetector(this.config);

  /// Detect document in the given image bytes
  Future<DocumentDetectionResult> detectDocument(Uint8List imageBytes, Size imageSize) async {
    try {
      // Create OpenCV Mat from image bytes
      final mat = cv.imdecode(imageBytes, cv.IMREAD_COLOR);
      if (mat.isEmpty) {
        return DocumentDetectionResult.notDetected();
      }

      // Convert to grayscale for processing
      final gray = cv.cvtColor(mat, cv.COLOR_BGR2GRAY);
      
      // Apply Gaussian blur to reduce noise
      final blurred = cv.gaussianBlur(gray, (5, 5), 0);
      
      // Apply adaptive threshold
      final thresh = cv.adaptiveThreshold(
        blurred,
        255,
        cv.ADAPTIVE_THRESH_GAUSSIAN_C,
        cv.THRESH_BINARY,
        11,
        2,
      );
      
      // Find contours
      final contoursResult = cv.findContours(
        thresh,
        cv.RETR_EXTERNAL,
        cv.CHAIN_APPROX_SIMPLE,
      );
      
      final contours = contoursResult.$1; // Extract contours from tuple
      
      if (contours.length == 0) {
        return DocumentDetectionResult.notDetected();
      }
      
      // Find the largest contour that could be a document
      cv.VecPoint? bestContour;
      double maxArea = 0;
      
      for (int i = 0; i < contours.length; i++) {
        final contour = contours[i];
        final area = cv.contourArea(contour);
        final imageArea = imageSize.width * imageSize.height;
        
        // Check if contour is large enough to be a document
        if (area > maxArea && area > imageArea * config.minimumDocumentArea) {
          // Approximate contour to polygon
          final epsilon = 0.02 * cv.arcLength(contour, true);
          final approx = cv.approxPolyDP(contour, epsilon, true);
          
          // Check if approximated contour has 4 vertices (quadrilateral)
          if (approx.length == 4) {
            maxArea = area;
            bestContour = approx;
          }
        }
      }
      
      if (bestContour == null) {
        return DocumentDetectionResult.notDetected();
      }
      
      // Convert contour points to Flutter Offset
      final corners = <Offset>[];
      for (int i = 0; i < bestContour.length; i++) {
        final point = bestContour[i];
        corners.add(Offset(point.x.toDouble(), point.y.toDouble()));
      }
      
      // Order corners: top-left, top-right, bottom-right, bottom-left
      final orderedCorners = _orderCorners(corners);
      
      // Calculate confidence based on area and shape regularity
      final confidence = _calculateConfidence(orderedCorners, imageSize);
      
      // Calculate bounding rectangle
      final boundingRect = _getBoundingRect(orderedCorners);
      
      // Dispose OpenCV resources
      mat.dispose();
      gray.dispose();
      blurred.dispose();
      thresh.dispose();
      
      return DocumentDetectionResult(
        isDetected: confidence >= config.documentDetectionSensitivity,
        corners: orderedCorners,
        confidence: confidence,
        boundingRect: boundingRect,
      );
    } catch (e) {
      debugPrint('Document detection error: $e');
      return DocumentDetectionResult.notDetected();
    }
  }

  /// Order corners in clockwise order: top-left, top-right, bottom-right, bottom-left
  List<Offset> _orderCorners(List<Offset> corners) {
    if (corners.length != 4) return corners;
    
    // Sort by x + y (top-left will have smallest sum)
    corners.sort((a, b) => (a.dx + a.dy).compareTo(b.dx + b.dy));
    final topLeft = corners[0];
    final bottomRight = corners[3];
    
    // Sort remaining points by x - y (top-right will have largest difference)
    final remaining = [corners[1], corners[2]];
    remaining.sort((a, b) => (a.dx - a.dy).compareTo(b.dx - b.dy));
    final bottomLeft = remaining[0];
    final topRight = remaining[1];
    
    return [topLeft, topRight, bottomRight, bottomLeft];
  }

  /// Calculate detection confidence based on shape and size
  double _calculateConfidence(List<Offset> corners, Size imageSize) {
    if (corners.length != 4) return 0.0;
    
    // Calculate area
    final area = _calculatePolygonArea(corners);
    final imageArea = imageSize.width * imageSize.height;
    final areaRatio = area / imageArea;
    
    // Calculate aspect ratio similarity to typical document ratios
    final rect = _getBoundingRect(corners);
    final aspectRatio = rect.width / rect.height;
    final aspectScore = _getAspectRatioScore(aspectRatio);
    
    // Calculate corner angles (should be close to 90 degrees for documents)
    final angleScore = _getCornerAngleScore(corners);
    
    // Combine scores
    final confidence = (areaRatio * 0.4 + aspectScore * 0.3 + angleScore * 0.3)
        .clamp(0.0, 1.0);
    
    return confidence;
  }

  /// Calculate polygon area using shoelace formula
  double _calculatePolygonArea(List<Offset> corners) {
    double area = 0.0;
    for (int i = 0; i < corners.length; i++) {
      final j = (i + 1) % corners.length;
      area += corners[i].dx * corners[j].dy;
      area -= corners[j].dx * corners[i].dy;
    }
    return area.abs() / 2.0;
  }

  /// Get bounding rectangle from corners
  Rect _getBoundingRect(List<Offset> corners) {
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

  /// Score aspect ratio similarity to common document ratios
  double _getAspectRatioScore(double aspectRatio) {
    const commonRatios = [
      1.0 / 1.4142, // A4 portrait
      1.4142,       // A4 landscape
      1.0 / 1.2941, // Letter portrait
      1.2941,       // Letter landscape
      1.0,          // Square
    ];
    
    double bestScore = 0.0;
    for (final ratio in commonRatios) {
      final similarity = 1.0 - (aspectRatio - ratio).abs() / max(aspectRatio, ratio);
      bestScore = max(bestScore, similarity.clamp(0.0, 1.0));
    }
    
    return bestScore;
  }

  /// Score corner angles (should be close to 90 degrees for documents)
  double _getCornerAngleScore(List<Offset> corners) {
    if (corners.length != 4) return 0.0;
    
    double totalScore = 0.0;
    for (int i = 0; i < 4; i++) {
      final prev = corners[(i - 1 + 4) % 4];
      final current = corners[i];
      final next = corners[(i + 1) % 4];
      
      final angle = _calculateAngle(prev, current, next);
      final angleScore = 1.0 - (angle - pi / 2).abs() / (pi / 2);
      totalScore += angleScore.clamp(0.0, 1.0);
    }
    
    return totalScore / 4.0;
  }

  /// Calculate angle between three points
  double _calculateAngle(Offset a, Offset b, Offset c) {
    final ba = Offset(a.dx - b.dx, a.dy - b.dy);
    final bc = Offset(c.dx - b.dx, c.dy - b.dy);
    
    final dot = ba.dx * bc.dx + ba.dy * bc.dy;
    final cross = ba.dx * bc.dy - ba.dy * bc.dx;
    
    return atan2(cross.abs(), dot);
  }
}
