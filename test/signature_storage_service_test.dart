import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pdf_ai_toolkit/models/saved_signature.dart';
import 'package:pdf_ai_toolkit/services/signature_storage_service.dart';

void main() {
  late Directory tempDir;
  late SignatureStorageService signatureService;

  final dummyPngBytes = Uint8List.fromList([
    137, 80, 78, 71, 13, 10, 26, 10, // PNG magic header
    0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137,
    0, 0, 0, 10, 73, 68, 65, 84, 120, 156, 99, 0, 1, 0, 0, 5, 0, 1, 13, 10, 45, 180,
    0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130
  ]);

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_sig_test_');
    Hive.init(tempDir.path);
  });

  setUp(() async {
    signatureService = SignatureStorageService();
    await signatureService.clearAllSignatures();
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('SignatureStorageService Hive CRUD & Export Tests', () {
    test('saveSignature persists and retrieves signature from Hive', () async {
      final sig = SavedSignature(
        id: 'sig_1',
        title: 'Official Signature',
        createdAt: DateTime(2026, 9, 29, 10, 0),
        pngBytes: dummyPngBytes,
        colorValue: 0xFF2563EB,
        strokeWidth: 3.5,
      );

      await signatureService.saveSignature(sig);

      final retrieved = await signatureService.getSignature('sig_1');
      expect(retrieved, isNotNull);
      expect(retrieved!.id, equals('sig_1'));
      expect(retrieved.title, equals('Official Signature'));
      expect(retrieved.colorValue, equals(0xFF2563EB));
      expect(retrieved.strokeWidth, equals(3.5));
      expect(retrieved.pngBytes, equals(dummyPngBytes));
    });

    test('getAllSignatures returns all signatures sorted descending by date', () async {
      final sigOld = SavedSignature(
        id: 'sig_old',
        title: 'Old Signature',
        createdAt: DateTime(2026, 9, 20),
        pngBytes: dummyPngBytes,
      );
      final sigNew = SavedSignature(
        id: 'sig_new',
        title: 'New Signature',
        createdAt: DateTime(2026, 9, 29),
        pngBytes: dummyPngBytes,
      );

      await signatureService.saveSignature(sigOld);
      await signatureService.saveSignature(sigNew);

      final list = await signatureService.getAllSignatures();
      expect(list.length, equals(2));
      expect(list.first.id, equals('sig_new'));
      expect(list.last.id, equals('sig_old'));
    });

    test('deleteSignature removes signature from Hive', () async {
      final sig = SavedSignature(
        id: 'sig_to_delete',
        title: 'To Delete',
        createdAt: DateTime.now(),
        pngBytes: dummyPngBytes,
      );

      await signatureService.saveSignature(sig);
      expect(await signatureService.getSignature('sig_to_delete'), isNotNull);

      final deleted = await signatureService.deleteSignature('sig_to_delete');
      expect(deleted, isTrue);

      final after = await signatureService.getSignature('sig_to_delete');
      expect(after, isNull);
    });

    test('exportSignatureToFile writes valid transparent PNG file to disk', () async {
      final sig = SavedSignature(
        id: 'sig_export',
        title: 'Export Test',
        createdAt: DateTime(2026, 9, 29, 12, 0),
        pngBytes: dummyPngBytes,
      );

      final filePath = await signatureService.exportSignatureToFile(
        sig,
        customPath: tempDir.path,
      );

      final file = File(filePath);
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), equals(dummyPngBytes.length));

      final header = await file.openRead(0, 8).first;
      expect(header.take(4).toList(), equals([137, 80, 78, 71])); // PNG header
    });
  });

  group('SavedSignature Model Unit Tests', () {
    test('toMap and fromMap serialization roundtrip', () {
      final sig = SavedSignature(
        id: 'model_1',
        title: 'My Custom Stamp',
        createdAt: DateTime(2026, 9, 29, 14, 30),
        pngBytes: dummyPngBytes,
        colorValue: 0xFF1E3A8A,
        strokeWidth: 4.0,
        width: 300,
        height: 150,
      );

      final map = sig.toMap();
      final reconstructed = SavedSignature.fromMap(map);

      expect(reconstructed.id, equals(sig.id));
      expect(reconstructed.title, equals(sig.title));
      expect(reconstructed.colorValue, equals(sig.colorValue));
      expect(reconstructed.strokeWidth, equals(sig.strokeWidth));
      expect(reconstructed.width, equals(sig.width));
      expect(reconstructed.height, equals(sig.height));
      expect(reconstructed.pngBytes, equals(sig.pngBytes));
    });

    test('copyWith produces updated copy without mutating original', () {
      final sig = SavedSignature(
        id: 'orig',
        title: 'Original',
        createdAt: DateTime.now(),
        pngBytes: dummyPngBytes,
      );

      final modified = sig.copyWith(title: 'Updated Title', strokeWidth: 5.0);
      expect(modified.title, equals('Updated Title'));
      expect(modified.strokeWidth, equals(5.0));
      expect(modified.id, equals(sig.id));
      expect(sig.title, equals('Original'));
    });
  });
}
