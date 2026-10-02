import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart' show Canvas, Paint, Rect;
import 'package:hive/hive.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pdf_ai_toolkit/models/saved_signature.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';

class SignatureStorageService {
  static const String _boxName = 'savedSignaturesBox';
  Box? _cachedBox;

  Future<Box?> _getBox() async {
    try {
      if (_cachedBox != null && _cachedBox!.isOpen) {
        return _cachedBox;
      }
      if (Hive.isBoxOpen(_boxName)) {
        _cachedBox = Hive.box(_boxName);
        return _cachedBox;
      }
      _cachedBox = await Hive.openBox(_boxName);
      return _cachedBox;
    } catch (_) {
      return null;
    }
  }

  /// Saves or updates a signature in local Hive storage
  Future<void> saveSignature(SavedSignature signature) async {
    try {
      if (signature.id.isEmpty || signature.pngBytes.isEmpty) return;
      final box = await _getBox();
      if (box == null) return;
      await box.put(signature.id, signature.toMap());
    } catch (_) {}
  }

  /// Retrieves all saved signatures ordered by creation date descending
  Future<List<SavedSignature>> getAllSignatures() async {
    try {
      final box = await _getBox();
      if (box == null) return [];

      final list = <SavedSignature>[];
      for (final key in box.keys) {
        final val = box.get(key);
        if (val is Map) {
          try {
            list.add(SavedSignature.fromMap(val));
          } catch (_) {}
        }
      }
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (_) {
      return [];
    }
  }

  /// Gets a single signature by id
  Future<SavedSignature?> getSignature(String id) async {
    try {
      final box = await _getBox();
      if (box == null) return null;
      final val = box.get(id);
      if (val is Map) {
        return SavedSignature.fromMap(val);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Deletes a signature from storage
  Future<bool> deleteSignature(String id) async {
    try {
      final box = await _getBox();
      if (box == null) return false;
      await box.delete(id);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Clears all saved signatures
  Future<void> clearAllSignatures() async {
    try {
      final box = await _getBox();
      if (box == null) return;
      await box.clear();
    } catch (_) {}
  }

  /// Adds a solid white background behind a transparent PNG image
  static Future<Uint8List> addWhiteBackgroundToPng(
      Uint8List transparentPngBytes) async {
    try {
      final codec = await ui.instantiateImageCodec(transparentPngBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
        recorder,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      );

      // Draw solid white background
      canvas.drawRect(
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Paint()..color = const ui.Color(0xFFFFFFFF),
      );

      // Draw original transparent PNG over white background
      canvas.drawImage(image, ui.Offset.zero, Paint());

      final picture = recorder.endRecording();
      final bgImg = await picture.toImage(image.width, image.height);
      final byteData = await bgImg.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List() ?? transparentPngBytes;
    } catch (_) {
      return transparentPngBytes;
    }
  }

  /// Exports the signature PNG to disk (with optional white background for gallery viewing)
  Future<String> exportSignatureToFile(
    SavedSignature signature, {
    bool withWhiteBackground = false,
    String? customPath,
  }) async {
    final String dirPath =
        customPath ?? (await getApplicationDocumentsDirectory()).path;
    final cleanTitle = signature.title
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_')
        .toLowerCase();
    final fileName = FileService().formatOutputFileName(
      baseName: cleanTitle.isEmpty ? 'signature' : cleanTitle,
      suffix: '${signature.createdAt.millisecondsSinceEpoch}',
      extension: 'png',
    );
    final targetPath = path.join(dirPath, fileName);

    Uint8List exportBytes = signature.pngBytes;
    if (withWhiteBackground) {
      exportBytes = await addWhiteBackgroundToPng(signature.pngBytes);
    }

    final filePath =
        await FileService().safeWriteBytes(targetPath, exportBytes);
    return filePath;
  }
}
