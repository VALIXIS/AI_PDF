import 'dart:developer' as developer;

/// Base exception class for all AI PDF Maker domain errors.
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic details;

  AppException(this.message, {this.code, this.details}) {
    developer.log(
      '[$code] $message',
      name: 'AppException',
      error: details,
    );
  }

  @override
  String toString() => message;
}

/// Thrown when PDF processing, vector creation, or manipulation fails.
class PdfServiceException extends AppException {
  PdfServiceException(String message, {String? code, dynamic details})
      : super(message, code: code ?? 'PDF_SERVICE_ERROR', details: details);
}

/// Thrown when file access, storage initialization, or path resolution fails.
class FileStorageException extends AppException {
  FileStorageException(String message, {String? code, dynamic details})
      : super(message, code: code ?? 'FILE_STORAGE_ERROR', details: details);
}

/// Thrown when AI document processing, Q&A, or action dispatching fails.
class AiServiceException extends AppException {
  AiServiceException(String message, {String? code, dynamic details})
      : super(message, code: code ?? 'AI_SERVICE_ERROR', details: details);
}
