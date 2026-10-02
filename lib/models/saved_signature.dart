import 'dart:typed_data';

/// Represents a digital e-signature saved in local storage.
class SavedSignature {
  final String id;
  final String title;
  final DateTime createdAt;
  final Uint8List pngBytes;
  final int colorValue;
  final double strokeWidth;
  final double? width;
  final double? height;

  SavedSignature({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.pngBytes,
    this.colorValue = 0xFF000000,
    this.strokeWidth = 3.0,
    this.width,
    this.height,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'pngBytes': pngBytes,
        'colorValue': colorValue,
        'strokeWidth': strokeWidth,
        'width': width,
        'height': height,
      };

  factory SavedSignature.fromMap(Map<dynamic, dynamic> map) => SavedSignature(
        id: map['id'] as String? ?? '',
        title: map['title'] as String? ?? 'Signature',
        createdAt: map['createdAt'] != null
            ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
            : DateTime.now(),
        pngBytes: map['pngBytes'] is Uint8List
            ? map['pngBytes'] as Uint8List
            : Uint8List.fromList(List<int>.from(map['pngBytes'] as List)),
        colorValue: map['colorValue'] as int? ?? 0xFF000000,
        strokeWidth: (map['strokeWidth'] as num?)?.toDouble() ?? 3.0,
        width: (map['width'] as num?)?.toDouble(),
        height: (map['height'] as num?)?.toDouble(),
      );

  SavedSignature copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    Uint8List? pngBytes,
    int? colorValue,
    double? strokeWidth,
    double? width,
    double? height,
  }) {
    return SavedSignature(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      pngBytes: pngBytes ?? this.pngBytes,
      colorValue: colorValue ?? this.colorValue,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }
}
