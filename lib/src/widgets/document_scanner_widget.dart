import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import '../config/document_scanner_config.dart';
import '../detection/document_detector.dart';
import '../processing/image_processor.dart';

/// Main widget that provides document scanning functionality
class DocumentScannerWidget extends StatefulWidget {
  final DocumentScannerConfig config;
  final Function(CapturedDocumentResult) onDocumentCaptured;
  final VoidCallback? onError;

  const DocumentScannerWidget({
    Key? key,
    required this.config,
    required this.onDocumentCaptured,
    this.onError,
  }) : super(key: key);

  @override
  State<DocumentScannerWidget> createState() => _DocumentScannerWidgetState();
}

class _DocumentScannerWidgetState extends State<DocumentScannerWidget>
    with TickerProviderStateMixin {
  CameraController? _cameraController;
  DocumentDetector? _detector;
  ImageProcessor? _imageProcessor;
  
  // Detection state
  DocumentDetectionResult? _currentDetection;
  Timer? _stabilityTimer;
  DateTime? _detectionStartTime;
  bool _isDocumentStable = false;
  bool _isCameraPaused = false;
  
  // Animation controllers
  late AnimationController _frameColorController;
  late Animation<Color?> _frameColorAnimation;
  
  // Processing state
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeCamera();
    _detector = DocumentDetector(widget.config);
    _imageProcessor = ImageProcessor(widget.config);
  }

  void _initializeAnimations() {
    _frameColorController = AnimationController(
      duration: widget.config.frameColorAnimationDuration,
      vsync: this,
    );
    
    _frameColorAnimation = ColorTween(
      begin: widget.config.frameColorIdle,
      end: widget.config.frameColorDetected,
    ).animate(CurvedAnimation(
      parent: _frameColorController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == widget.config.cameraLensDirection,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        camera,
        widget.config.resolutionPreset,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      
      if (mounted) {
        setState(() {});
        _startImageStream();
      }
    } catch (e) {
      debugPrint('Camera initialization error: $e');
      widget.onError?.call();
    }
  }

  void _startImageStream() {
    if (_cameraController?.value.isInitialized != true || _isCameraPaused) return;
    
    _cameraController!.startImageStream(_processImage);
  }

  void _stopImageStream() {
    _cameraController?.stopImageStream();
  }

  Future<void> _processImage(CameraImage image) async {
    if (_detector == null || _isCameraPaused) return;

    try {
      // Convert CameraImage to Uint8List (simplified - you may need platform-specific conversion)
      final bytes = await _convertCameraImage(image);
      final size = Size(image.width.toDouble(), image.height.toDouble());
      
      final detection = await _detector!.detectDocument(bytes, size);
      
      if (mounted) {
        setState(() {
          _currentDetection = detection;
        });
        
        _handleDetectionResult(detection);
      }
    } catch (e) {
      debugPrint('Image processing error: $e');
    }
  }

  void _handleDetectionResult(DocumentDetectionResult detection) {
    if (detection.isDetected) {
      // Document detected
      if (_detectionStartTime == null) {
        _detectionStartTime = DateTime.now();
        _frameColorController.forward();
        
        if (widget.config.enableHapticFeedback) {
          HapticFeedback.lightImpact();
        }
      }
      
      // Check if document has been stable for required duration
      final stableDuration = DateTime.now().difference(_detectionStartTime!);
      if (stableDuration >= widget.config.documentStabilityDuration && !_isDocumentStable) {
        _isDocumentStable = true;
        _captureDocument();
      }
    } else {
      // Document not detected - reset state
      _resetDetectionState();
    }
  }

  void _resetDetectionState() {
    if (_detectionStartTime != null) {
      _detectionStartTime = null;
      _isDocumentStable = false;
      _frameColorController.reverse();
      
      _stabilityTimer?.cancel();
      _stabilityTimer = null;
    }
  }

  Future<void> _captureDocument() async {
    if (_cameraController?.value.isInitialized != true || _currentDetection?.corners == null) {
      return;
    }

    try {
      // Pause camera
      setState(() {
        _isCameraPaused = true;
      });
      _stopImageStream();
      
      // Provide haptic feedback
      if (widget.config.enableHapticFeedback) {
        HapticFeedback.mediumImpact();
      }

      // Capture image
      final XFile imageFile = await _cameraController!.takePicture();
      final imageBytes = await imageFile.readAsBytes();
      
      // Process and crop the image (this will be implemented in the image processor)
      final result = await _processAndCropImage(
        imageBytes,
        _currentDetection!.corners!,
      );
      
      widget.onDocumentCaptured(result);
      
    } catch (e) {
      debugPrint('Document capture error: $e');
      widget.onError?.call();
      // Resume camera on error
      _resumeCamera();
    }
  }

  Future<CapturedDocumentResult> _processAndCropImage(
    Uint8List imageBytes,
    List<Offset> corners,
  ) async {
    if (_imageProcessor == null) {
      throw Exception('Image processor not initialized');
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await _imageProcessor!.processImageWithDartImage(
        imageBytes,
        corners,
      );
      return result;
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _resumeCamera() {
    if (!_isCameraPaused) return;
    
    setState(() {
      _isCameraPaused = false;
    });
    _resetDetectionState();
    _startImageStream();
  }

  Future<Uint8List> _convertCameraImage(CameraImage image) async {
    // Simplified conversion - in production, use proper YUV to RGB conversion
    // This is platform-specific and requires proper implementation
    const int bufferSize = 1024 * 1024; // 1MB placeholder
    return Uint8List(bufferSize);
  }

  Widget _buildOverlay() {
    return AnimatedBuilder(
      animation: _frameColorAnimation,
      builder: (context, child) {
        return CustomPaint(
          painter: DocumentOverlayPainter(
            config: widget.config,
            frameColor: _frameColorAnimation.value ?? widget.config.frameColorIdle,
            detection: _currentDetection,
            isStable: _isDocumentStable,
          ),
          size: Size.infinite,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController?.value.isInitialized != true) {
      return const Center(child: CircularProgressIndicator());
    }

    Widget cameraWidget = CameraPreview(_cameraController!);
    
    // Apply custom preview size if configured
    if (widget.config.previewSize != null) {
      cameraWidget = SizedBox(
        width: widget.config.previewSize!.width,
        height: widget.config.previewSize!.height,
        child: ClipRect(child: cameraWidget),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview with configured size
        Center(child: cameraWidget),
        
        // Detection overlay
        _buildOverlay(),
        
        // Status indicators
        if (_isCameraPaused || _isProcessing)
          Container(
            color: Colors.black54,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    _isProcessing ? 'Processing image...' : 'Camera paused',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _frameColorController.dispose();
    _stopImageStream();
    _cameraController?.dispose();
    _stabilityTimer?.cancel();
    super.dispose();
  }
}

/// Custom painter for document detection overlay
class DocumentOverlayPainter extends CustomPainter {
  final DocumentScannerConfig config;
  final Color frameColor;
  final DocumentDetectionResult? detection;
  final bool isStable;

  DocumentOverlayPainter({
    required this.config,
    required this.frameColor,
    this.detection,
    this.isStable = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = frameColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = config.frameThickness;

    // Calculate frame bounds with ID card aspect ratio (1.588:1)
    const double idCardAspectRatio = 1.588;
    final availableWidth = size.width - (config.framePadding * 2);
    final availableHeight = size.height - (config.framePadding * 2);
    
    double frameWidth, frameHeight;
    
    // Calculate frame size based on ID card aspect ratio
    if (availableWidth / availableHeight > idCardAspectRatio) {
      // Constrained by height
      frameHeight = availableHeight;
      frameWidth = frameHeight * idCardAspectRatio;
    } else {
      // Constrained by width
      frameWidth = availableWidth;
      frameHeight = frameWidth / idCardAspectRatio;
    }
    
    // Center the frame
    final frameLeft = (size.width - frameWidth) / 2;
    final frameTop = (size.height - frameHeight) / 2;
    
    final frameRect = Rect.fromLTWH(
      frameLeft,
      frameTop,
      frameWidth,
      frameHeight,
    );

    // Draw main frame
    final rrect = RRect.fromRectAndRadius(
      frameRect,
      Radius.circular(config.frameBorderRadius),
    );
    canvas.drawRRect(rrect, paint);

    // Draw detected document outline if available
    if (detection?.isDetected == true && detection?.corners != null) {
      final detectedPaint = Paint()
        ..color = frameColor.withOpacity(0.3)
        ..style = PaintingStyle.fill;
      
      final strokePaint = Paint()
        ..color = frameColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      final path = Path();
      final corners = detection!.corners!;
      
      if (corners.isNotEmpty) {
        path.moveTo(corners[0].dx, corners[0].dy);
        for (int i = 1; i < corners.length; i++) {
          path.lineTo(corners[i].dx, corners[i].dy);
        }
        path.close();
        
        canvas.drawPath(path, detectedPaint);
        canvas.drawPath(path, strokePaint);
      }
    }

    // Draw corner indicators
    _drawCornerIndicators(canvas, frameRect, paint);
  }

  void _drawCornerIndicators(Canvas canvas, Rect frameRect, Paint paint) {
    const cornerLength = 20.0;
    
    // Top-left corner
    canvas.drawLine(
      Offset(frameRect.left, frameRect.top + cornerLength),
      Offset(frameRect.left, frameRect.top),
      paint,
    );
    canvas.drawLine(
      Offset(frameRect.left, frameRect.top),
      Offset(frameRect.left + cornerLength, frameRect.top),
      paint,
    );
    
    // Top-right corner
    canvas.drawLine(
      Offset(frameRect.right - cornerLength, frameRect.top),
      Offset(frameRect.right, frameRect.top),
      paint,
    );
    canvas.drawLine(
      Offset(frameRect.right, frameRect.top),
      Offset(frameRect.right, frameRect.top + cornerLength),
      paint,
    );
    
    // Bottom-right corner
    canvas.drawLine(
      Offset(frameRect.right, frameRect.bottom - cornerLength),
      Offset(frameRect.right, frameRect.bottom),
      paint,
    );
    canvas.drawLine(
      Offset(frameRect.right, frameRect.bottom),
      Offset(frameRect.right - cornerLength, frameRect.bottom),
      paint,
    );
    
    // Bottom-left corner
    canvas.drawLine(
      Offset(frameRect.left + cornerLength, frameRect.bottom),
      Offset(frameRect.left, frameRect.bottom),
      paint,
    );
    canvas.drawLine(
      Offset(frameRect.left, frameRect.bottom),
      Offset(frameRect.left, frameRect.bottom - cornerLength),
      paint,
    );
  }

  @override
  bool shouldRepaint(DocumentOverlayPainter oldDelegate) {
    return oldDelegate.frameColor != frameColor ||
           oldDelegate.detection != detection ||
           oldDelegate.isStable != isStable;
  }
}
