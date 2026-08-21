import 'dart:io';
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/services/pdf_service.dart';

class CachedPdfData {
  final String pdfPath;
  final int pageCount;
  final String textContent;
  final DateTime lastModified;
  final DateTime cachedAt;

  CachedPdfData({
    required this.pdfPath,
    required this.pageCount,
    required this.textContent,
    required this.lastModified,
    required this.cachedAt,
  });
}

class PdfCacheService {
  static final PdfCacheService _instance = PdfCacheService._internal();
  factory PdfCacheService() => _instance;
  PdfCacheService._internal();

  final Map<String, CachedPdfData> _cache = {};
  final PdfService _pdfService = PdfService();
  final FileService _fileService = FileService();

  /// Maximum cache entries allowed in RAM
  static const int _maxCacheEntries = 20;

  /// Gets cached PDF data or parses and caches it if missing or stale
  Future<CachedPdfData> getPdfData(String pdfPath) async {
    final file = File(pdfPath);
    if (!await file.exists()) {
      throw Exception('File does not exist: $pdfPath');
    }

    final stat = await file.stat();
    final cached = _cache[pdfPath];

    // Cache hit: return immediately if file has not been modified
    if (cached != null && cached.lastModified.isAtSameMomentAs(stat.modified)) {
      return cached;
    }

    // Cache miss: parse and store in cache
    final text = await _fileService.readPdfInfo(pdfPath);
    final count = await _pdfService.getPdfPageCount(pdfPath);

    final newData = CachedPdfData(
      pdfPath: pdfPath,
      pageCount: count,
      textContent: text,
      lastModified: stat.modified,
      cachedAt: DateTime.now(),
    );

    _cache[pdfPath] = newData;
    _evictOldEntriesIfNeeded();

    return newData;
  }

  /// Invalidates a specific cached PDF
  void invalidate(String pdfPath) {
    _cache.remove(pdfPath);
  }

  /// Clears the entire in-memory cache
  void clearCache() {
    _cache.clear();
  }

  /// Returns current cache size
  int get cacheSize => _cache.length;

  /// Evicts oldest entries if cache limit is exceeded
  void _evictOldEntriesIfNeeded() {
    if (_cache.length > _maxCacheEntries) {
      final sortedKeys = _cache.keys.toList()
        ..sort((a, b) => _cache[a]!.cachedAt.compareTo(_cache[b]!.cachedAt));
      
      while (_cache.length > _maxCacheEntries && sortedKeys.isNotEmpty) {
        _cache.remove(sortedKeys.removeAt(0));
      }
    }
  }
}
