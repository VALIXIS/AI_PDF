import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

/// Represents page geometry including MediaBox, CropBox, and page rotation (0, 90, 180, 270 degrees).
class PdfPageGeometry {
  final Rect mediaBox;
  final Rect cropBox;
  final int rotation; // 0, 90, 180, or 270 degrees clockwise

  const PdfPageGeometry({
    required this.mediaBox,
    required this.cropBox,
    required this.rotation,
  });

  /// Horizontal crop offset relative to MediaBox (in PDF points)
  double get cropOffsetX => cropBox.left - mediaBox.left;

  /// Vertical crop offset relative to MediaBox (top-down origin, in PDF points)
  double get cropOffsetY => cropBox.top - mediaBox.top;

  /// Width of the visible crop box
  double get cropWidth => cropBox.width;

  /// Height of the visible crop box
  double get cropHeight => cropBox.height;

  /// Center X of the visible crop box (in PDF unrotated page coordinates)
  double get visibleCenterX => cropOffsetX + cropWidth / 2.0;

  /// Center Y of the visible crop box (in PDF unrotated page coordinates)
  double get visibleCenterY => cropOffsetY + cropHeight / 2.0;

  /// Visual width as viewed upright on screen
  double get visualWidth =>
      (rotation == 90 || rotation == 270) ? cropHeight : cropWidth;

  /// Visual height as viewed upright on screen
  double get visualHeight =>
      (rotation == 90 || rotation == 270) ? cropWidth : cropHeight;

  /// Whether page has non-zero crop offset or custom crop box
  bool get hasCropOffset =>
      cropOffsetX.abs() > 0.01 ||
      cropOffsetY.abs() > 0.01 ||
      (cropWidth - mediaBox.width).abs() > 0.01 ||
      (cropHeight - mediaBox.height).abs() > 0.01;

  /// Maps visual normalized Rect [0..1] on screen to unrotated PDF page canvas coordinates
  Rect mapNormalizedVisualRectToPage(Rect visualNorm) {
    final u1 = visualNorm.left.clamp(0.0, 1.0);
    final v1 = visualNorm.top.clamp(0.0, 1.0);
    final u2 = visualNorm.right.clamp(0.0, 1.0);
    final v2 = visualNorm.bottom.clamp(0.0, 1.0);

    double x1, y1, x2, y2;
    switch (rotation) {
      case 90:
        x1 = v1 * cropWidth;
        x2 = v2 * cropWidth;
        y1 = (1.0 - u2) * cropHeight;
        y2 = (1.0 - u1) * cropHeight;
        break;
      case 180:
        x1 = (1.0 - u2) * cropWidth;
        x2 = (1.0 - u1) * cropWidth;
        y1 = (1.0 - v2) * cropHeight;
        y2 = (1.0 - v1) * cropHeight;
        break;
      case 270:
        x1 = (1.0 - v2) * cropWidth;
        x2 = (1.0 - v1) * cropWidth;
        y1 = u1 * cropHeight;
        y2 = u2 * cropHeight;
        break;
      case 0:
      default:
        x1 = u1 * cropWidth;
        x2 = u2 * cropWidth;
        y1 = v1 * cropHeight;
        y2 = v2 * cropHeight;
        break;
    }

    final l = cropOffsetX + math.min(x1, x2);
    final t = cropOffsetY + math.min(y1, y2);
    final w = (x2 - x1).abs();
    final h = (y2 - y1).abs();

    return Rect.fromLTWH(l, t, w, h);
  }

  /// Extracts page geometry for all pages in a PDF document
  static List<PdfPageGeometry> extractPageGeometries(
      Uint8List pdfBytes, sf.PdfDocument document) {
    final latin1Str = latin1.decode(pdfBytes);
    final List<PdfPageGeometry> geometries = [];

    // Document-level default MediaBox / CropBox in /Pages
    Rect? defaultMediaBox;
    Rect? defaultCropBox;
    int defaultRotation = 0;

    final pagesMatch =
        RegExp(r'/Type\s*/Pages\b[\s\S]*?>>').firstMatch(latin1Str);
    if (pagesMatch != null) {
      final pagesDict = pagesMatch.group(0)!;
      defaultMediaBox = _parseBox(pagesDict, 'MediaBox');
      defaultCropBox = _parseBox(pagesDict, 'CropBox');
      defaultRotation = _parseRotation(pagesDict) ?? 0;
    }

    // Extract each page's specific dictionary
    final pageRegex =
        RegExp(r'(\d+)\s+(\d+)\s+obj\b[\s\S]*?/Type\s*/Page\b[\s\S]*?>>');
    final pageMatches = pageRegex.allMatches(latin1Str).toList();

    for (int i = 0; i < document.pages.count; i++) {
      final sf.PdfPage sfPage = document.pages[i];
      final sfSize = sfPage.size;

      int rotation = 0;
      switch (sfPage.rotation) {
        case sf.PdfPageRotateAngle.rotateAngle90:
          rotation = 90;
          break;
        case sf.PdfPageRotateAngle.rotateAngle180:
          rotation = 180;
          break;
        case sf.PdfPageRotateAngle.rotateAngle270:
          rotation = 270;
          break;
        case sf.PdfPageRotateAngle.rotateAngle0:
          rotation = 0;
          break;
      }

      Rect mediaBox = Rect.fromLTWH(0, 0, sfSize.width, sfSize.height);
      Rect cropBox = mediaBox;

      if (i < pageMatches.length) {
        final pageDict = pageMatches[i].group(0)!;
        final parsedMedia = _parseBox(pageDict, 'MediaBox') ?? defaultMediaBox;
        if (parsedMedia != null) {
          mediaBox = parsedMedia;
        }
        final parsedCrop = _parseBox(pageDict, 'CropBox') ?? defaultCropBox;
        if (parsedCrop != null) {
          cropBox = parsedCrop;
        } else {
          cropBox = mediaBox;
        }
        final parsedRot = _parseRotation(pageDict) ?? defaultRotation;
        if (rotation == 0) {
          rotation = parsedRot;
        }
      }

      geometries.add(PdfPageGeometry(
        mediaBox: mediaBox,
        cropBox: cropBox,
        rotation: rotation,
      ));
    }

    return geometries;
  }

  static Rect? _parseBox(String dict, String boxName) {
    final match = RegExp(
            '/$boxName\\s*\\[\\s*([-\\d.]+)\\s+([-\\d.]+)\\s+([-\\d.]+)\\s+([-\\d.]+)\\s*\\]')
        .firstMatch(dict);
    if (match == null) return null;
    final x1 = double.tryParse(match.group(1)!) ?? 0;
    final y1 = double.tryParse(match.group(2)!) ?? 0;
    final x2 = double.tryParse(match.group(3)!) ?? 0;
    final y2 = double.tryParse(match.group(4)!) ?? 0;

    final left = math.min(x1, x2);
    final top = math.min(y1, y2);
    final width = (x2 - x1).abs();
    final height = (y2 - y1).abs();
    return Rect.fromLTWH(left, top, width, height);
  }

  static int? _parseRotation(String dict) {
    final match = RegExp(r'/Rotate\s*(\d+)').firstMatch(dict);
    if (match == null) return null;
    final angle = int.tryParse(match.group(1)!);
    if (angle != null && [0, 90, 180, 270].contains(angle % 360)) {
      return angle % 360;
    }
    return null;
  }
}
