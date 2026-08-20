import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Annotation types supported by the PDF Editor
enum AnnotationKind { text, image }

/// Represents an annotation (text or image overlay) placed on a PDF page
class Annotation {
  final String id;
  AnnotationKind kind;
  double x, y, width, height;
  String text;
  double fontSize;
  Color color;
  bool bold;
  Uint8List? imageBytes;

  Annotation.text({
    required this.id,
    required this.x,
    required this.y,
    this.text = 'Text',
    this.fontSize = 16,
    this.color = Colors.black,
    this.bold = false,
    this.width = 0.4,
    this.height = 0.06,
    this.imageBytes,
    this.kind = AnnotationKind.text,
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
    this.kind = AnnotationKind.image,
  });
}
