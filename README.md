# Document Scanner

A powerful Flutter package for detecting documents and cropping images with perspective correction. Designed specifically for Android with configurable camera preview, real-time document detection, and automatic image processing.

## Features

- **Real-time Document Detection**: Uses OpenCV for accurate document boundary detection
- **Configurable Camera Preview**: Customizable resolution, preview size, and camera settings
- **Smart Frame Overlay**: White frame that turns green when document is detected
- **Stability Detection**: Configurable timer ensures document stays in frame before capture
- **Perspective Correction**: Automatic cropping and perspective correction
- **Configurable Output**: Control image size, aspect ratio, and color mode
- **Automatic Processing**: Camera pauses after capture while processing image
- **Callback System**: Event-driven architecture for handling captured documents

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  document_scanner:
    path: ../path/to/document_scanner
```

## Android Setup

Add the following permissions to your `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" android:required="true" />
<uses-feature android:name="android.hardware.camera.autofocus" android:required="false" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

## Usage

### Basic Usage

```dart
import 'package:document_scanner/document_scanner.dart';

class ScannerPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DocumentScanner.createDefault(
        onDocumentCaptured: (result) {
          print('Document captured: ${result.imagePath}');
          // Handle the captured document
        },
        onError: () {
          print('Scanner error occurred');
        },
      ),
    );
  }
}
```

### Advanced Configuration

```dart
import 'package:document_scanner/document_scanner.dart';

class AdvancedScannerPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final config = DocumentScannerConfig(
      // Camera settings
      resolutionPreset: ResolutionPreset.high,
      previewSize: Size(350, 600),
      
      // Frame appearance
      frameThickness: 6.0,
      frameBorderRadius: 16.0,
      framePadding: 32.0,
      frameColorIdle: Colors.white,
      frameColorDetected: Colors.green,
      
      // Detection settings
      documentStabilityDuration: Duration(seconds: 2),
      documentDetectionSensitivity: 0.8,
      minimumDocumentArea: 0.15,
      
      // Output settings
      outputLongSide: 1080,
      outputAspectRatio: 1.4142, // A4 ratio
      colorMode: ColorMode.color,
      documentPadding: 0.05,
      
      // Feedback settings
      enableHapticFeedback: true,
    );

    return Scaffold(
      body: DocumentScanner.create(
        config: config,
        onDocumentCaptured: (result) {
          handleDocument(result);
        },
        onError: () {
          showErrorDialog();
        },
      ),
    );
  }
}
```

## Configuration Options

### Camera Configuration
- `previewSize`: Custom camera preview size
- `resolutionPreset`: Camera resolution quality
- `cameraLensDirection`: Front or back camera

### Frame Appearance
- `frameThickness`: Border thickness in pixels
- `frameBorderRadius`: Corner radius of the frame
- `framePadding`: Space between frame and screen edges
- `frameColorIdle`: Frame color when no document detected
- `frameColorDetected`: Frame color when document is detected

### Detection Settings
- `documentStabilityDuration`: How long document must stay in frame
- `documentDetectionSensitivity`: Detection sensitivity (0.0 - 1.0)
- `minimumDocumentArea`: Minimum document size as ratio of preview

### Output Configuration
- `outputLongSide`: Maximum pixels for the longer side
- `outputAspectRatio`: Force specific aspect ratio
- `colorMode`: Color or grayscale output
- `documentPadding`: Padding around detected document

## Requirements

- Flutter 3.8.1+
- Android API level 21+
- Camera and storage permissions

## Platform Support

Currently supports **Android only**.

## License

This project is licensed under the MIT License.
