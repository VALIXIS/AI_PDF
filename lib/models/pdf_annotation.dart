import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Annotation types supported by the PDF Editor & Form Filler
enum AnnotationKind { text, image, checkmark, dateStamp, highlight }

/// Represents an annotation placed on a PDF page
class Annotation {
  final String id;
  AnnotationKind kind;
  double x, y, width, height;
  String text;
  double fontSize;
  Color color;
  bool bold;
  double opacity;
  Color? backgroundColor;
  Uint8List? imageBytes;
  bool isLocked;

  Annotation.text({
    required this.id,
    required this.x,
    required this.y,
    this.text = 'Text',
    this.fontSize = 16,
    this.color = Colors.black,
    this.bold = false,
    this.width = 0.3,
    this.height = 0.05,
    this.opacity = 1.0,
    this.backgroundColor,
    this.imageBytes,
    this.isLocked = false,
    this.kind = AnnotationKind.text,
  });

  Annotation.checkmark({
    required this.id,
    required this.x,
    required this.y,
    this.text = '✓',
    this.fontSize = 20,
    this.color = const Color(0xFF10B981), // Emerald green default
    this.bold = true,
    this.width = 0.06,
    this.height = 0.04,
    this.opacity = 1.0,
    this.backgroundColor,
    this.isLocked = false,
    this.kind = AnnotationKind.checkmark,
  });

  Annotation.dateStamp({
    required this.id,
    required this.x,
    required this.y,
    required this.text,
    this.fontSize = 14,
    this.color = const Color(0xFF1E293B),
    this.bold = false,
    this.width = 0.25,
    this.height = 0.05,
    this.opacity = 1.0,
    this.backgroundColor,
    this.isLocked = false,
    this.kind = AnnotationKind.dateStamp,
  });

  Annotation.highlight({
    required this.id,
    required this.x,
    required this.y,
    this.width = 0.35,
    this.height = 0.04,
    this.color = const Color(0xFFFFEB3B), // Yellow highlight default
    this.opacity = 0.4,
    this.text = '',
    this.fontSize = 14,
    this.bold = false,
    this.backgroundColor,
    this.isLocked = false,
    this.kind = AnnotationKind.highlight,
  });

  Annotation.image({
    required this.id,
    required this.x,
    required this.y,
    required this.imageBytes,
    this.width = 0.4,
    this.height = 0.3,
    this.text = '',
    this.fontSize = 16,
    this.color = Colors.black,
    this.bold = false,
    this.opacity = 1.0,
    this.backgroundColor,
    this.isLocked = false,
    this.kind = AnnotationKind.image,
  });

  Annotation copyWith({
    String? id,
    AnnotationKind? kind,
    double? x,
    double? y,
    double? width,
    double? height,
    String? text,
    double? fontSize,
    Color? color,
    bool? bold,
    double? opacity,
    Color? backgroundColor,
    Uint8List? imageBytes,
    bool? isLocked,
  }) {
    final newKind = kind ?? this.kind;
    return Annotation.text(
      id: id ?? this.id,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      text: text ?? this.text,
      fontSize: fontSize ?? this.fontSize,
      color: color ?? this.color,
      bold: bold ?? this.bold,
      opacity: opacity ?? this.opacity,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      imageBytes: imageBytes ?? this.imageBytes,
      isLocked: isLocked ?? this.isLocked,
      kind: newKind,
    );
  }
}

/// Represents an interactive signature or stamp overlay placed on a PDF page
class PdfOverlayPlacement {
  final String id;
  final int pageIndex; // 0-indexed
  double x; // Normalized 0.0 to 1.0 (relative to page width)
  double y; // Normalized 0.0 to 1.0 (relative to page height)
  double width; // Normalized relative to page width (e.g. 0.35)
  double height; // Normalized relative to page height (e.g. 0.15)
  double rotation; // In radians (-pi to pi)
  double opacity; // 0.1 to 1.0
  final Uint8List imageBytes;
  final String label;

  PdfOverlayPlacement({
    required this.id,
    required this.pageIndex,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.rotation = 0.0,
    this.opacity = 1.0,
    required this.imageBytes,
    this.label = 'Signature',
  });

  PdfOverlayPlacement copyWith({
    String? id,
    int? pageIndex,
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    double? opacity,
    Uint8List? imageBytes,
    String? label,
  }) {
    return PdfOverlayPlacement(
      id: id ?? this.id,
      pageIndex: pageIndex ?? this.pageIndex,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      rotation: rotation ?? this.rotation,
      opacity: opacity ?? this.opacity,
      imageBytes: imageBytes ?? this.imageBytes,
      label: label ?? this.label,
    );
  }
}

