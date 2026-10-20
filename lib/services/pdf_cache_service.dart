import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/services/pdf_service.dart';

class CachedPdfData {
  final String pdfPath;
  final int pageCount;
  final String textContent;
  final DateTime lastModified;
  final DateTime cachedAt;
  DateTime lastAccessed;

  CachedPdfData({
    required this.pdfPath,
    required this.pageCount,
    required this.textContent,
    required this.lastModified,
    required this.cachedAt,
    DateTime? lastAccessed,
  }) : lastAccessed = lastAccessed ?? cachedAt;
}

/// Represents a cached rasterized PDF page bitmap in RAM
class CachedPageBitmap {
  final String pdfPath;
  final int pageNumber;
  final double scale;
  final Uint8List bytes;
  final int byteSize;
  final int? width;
  final int? height;
  DateTime lastAccessed;
  final DateTime cachedAt;

  CachedPageBitmap({
    required this.pdfPath,
    required this.pageNumber,
    this.scale = 1.0,
    required this.bytes,
    int? byteSize,
    this.width,
    this.height,
    DateTime? lastAccessed,
    DateTime? cachedAt,
  })  : byteSize = byteSize ?? bytes.lengthInBytes,
        lastAccessed = lastAccessed ?? DateTime.now(),
        cachedAt = cachedAt ?? DateTime.now();

  static String generateKey(String pdfPath, int pageNumber, [double scale = 1.0]) {
    final norm = FileService().normalizePath(pdfPath);
    return '$norm:p$pageNumber@${scale.toStringAsFixed(2)}';
  }
}

class PdfCacheService {
  static final PdfCacheService _instance = PdfCacheService._internal();
  factory PdfCacheService() => _instance;
  PdfCacheService._internal();

  final Map<String, CachedPdfData> _cache = {};
  final Map<String, CachedPageBitmap> _bitmapCache = {};
  final PdfService _pdfService = PdfService();
  final FileService _fileService = FileService();

  /// Maximum cache entries allowed in RAM for PDF metadata/text
  static const int _maxCacheEntries = 20;

  /// Default capacity limits for cached page bitmaps
  int _maxBitmapEntries = 50;
  int _maxBitmapBytes = 64 * 1024 * 1024; // 64 MB
  int _currentBitmapBytes = 0;

  int get maxBitmapEntries => _maxBitmapEntries;
  set maxBitmapEntries(int value) {
    _maxBitmapEntries = value > 0 ? value : 1;
    _evictExcessBitmaps();
  }

  int get maxBitmapBytes => _maxBitmapBytes;
  set maxBitmapBytes(int value) {
    _maxBitmapBytes = value > 0 ? value : 1024 * 1024;
    _evictExcessBitmaps();
  }

  int get pageBitmapCacheCount => _bitmapCache.length;
  int get pageBitmapCacheBytes => _currentBitmapBytes;
  List<String> get bitmapCacheKeys => _bitmapCache.keys.toList();

  /// Gets cached PDF data or parses and caches it if missing or stale using LRU policy
  Future<CachedPdfData> getPdfData(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File does not exist: $filePath');
    }

    final stat = await file.stat();
    final cached = _cache[filePath];

    // Cache hit: return immediately if file has not been modified and update LRU position
    if (cached != null && cached.lastModified.isAtSameMomentAs(stat.modified)) {
      cached.lastAccessed = DateTime.now();
      _cache.remove(filePath);
      _cache[filePath] = cached; // re-insert at end (MRU)
      return cached;
    }

    // Cache miss: parse and store in cache depending on extension
    String text;
    int count = 1;
    final extension = filePath.split('.').last.toLowerCase();

    if (extension == 'pdf') {
      text = await _pdfService.extractPdfText(filePath);
      count = await _pdfService.getPdfPageCount(filePath);
    } else if (extension == 'docx') {
      text = await _extractDocxText(filePath);
      count = (text.length / 2000).ceil().clamp(1, 1000);
    } else if (extension == 'txt') {
      text = await _fileService.readTextFile(filePath);
      count = (text.length / 2000).ceil().clamp(1, 1000);
    } else if (extension == 'md' || extension == 'markdown') {
      text = await _fileService.readTextFile(filePath);
      count = (text.length / 2000).ceil().clamp(1, 1000);
    } else if (extension == 'html' || extension == 'htm') {
      final rawHtml = await _fileService.readTextFile(filePath);
      var clean = rawHtml.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
      clean = clean.replaceAll(
          RegExp(r'<style[^>]*>.*?<\/style>',
              caseSensitive: false, dotAll: true),
          '');
      clean = clean.replaceAll(
          RegExp(r'<script[^>]*>.*?<\/script>',
              caseSensitive: false, dotAll: true),
          '');
      clean = clean.replaceAll(
          RegExp(r'<head[^>]*>.*?<\/head>', caseSensitive: false, dotAll: true),
          '');
      text = clean
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      count = (text.length / 2000).ceil().clamp(1, 1000);
    } else {
      throw Exception('Unsupported file format: .$extension');
    }

    final now = DateTime.now();
    final newData = CachedPdfData(
      pdfPath: filePath,
      pageCount: count,
      textContent: text,
      lastModified: stat.modified,
      cachedAt: now,
      lastAccessed: now,
    );

    _cache.remove(filePath);
    _cache[filePath] = newData;
    _evictOldEntriesIfNeeded();

    return newData;
  }

  /// Invalidates a specific cached PDF
  void invalidate(String pdfPath) {
    _cache.remove(pdfPath);
    invalidatePageBitmaps(pdfPath);
  }

  /// Clears the entire in-memory cache including cached bitmaps
  void clearCache() {
    _cache.clear();
    clearPageBitmapCache();
  }

  /// Returns current PDF text cache size
  int get cacheSize => _cache.length;

  /// Evicts oldest (least recently used) PDF entries if cache limit is exceeded
  void _evictOldEntriesIfNeeded() {
    while (_cache.length > _maxCacheEntries && _cache.isNotEmpty) {
      _cache.remove(_cache.keys.first); // remove LRU entry
    }
  }

  // ────────────────── LRU Page Bitmap Cache ──────────────────

  /// Gets cached page bitmap using LRU policy.
  /// On hit, marks entry as Most Recently Used (MRU) and returns bytes.
  Uint8List? getPageBitmap(String pdfPath, int pageNumber, {double scale = 1.0}) {
    final key = CachedPageBitmap.generateKey(pdfPath, pageNumber, scale);
    final entry = _bitmapCache.remove(key);
    if (entry != null) {
      entry.lastAccessed = DateTime.now();
      _bitmapCache[key] = entry; // reinsert at end (MRU)
      return entry.bytes;
    }
    return null;
  }

  /// Gets cached page bitmap entry using LRU policy.
  CachedPageBitmap? getCachedPageBitmap(String pdfPath, int pageNumber, {double scale = 1.0}) {
    final key = CachedPageBitmap.generateKey(pdfPath, pageNumber, scale);
    final entry = _bitmapCache.remove(key);
    if (entry != null) {
      entry.lastAccessed = DateTime.now();
      _bitmapCache[key] = entry; // reinsert at end (MRU)
      return entry;
    }
    return null;
  }

  /// Caches a page bitmap with LRU eviction policy.
  /// Evicts least recently accessed entries if count or byte limits are exceeded.
  void cachePageBitmap({
    required String pdfPath,
    required int pageNumber,
    required Uint8List bytes,
    double scale = 1.0,
    int? width,
    int? height,
  }) {
    if (bytes.isEmpty) return;
    final key = CachedPageBitmap.generateKey(pdfPath, pageNumber, scale);

    // If key already exists, remove it and adjust current byte count
    final existing = _bitmapCache.remove(key);
    if (existing != null) {
      _currentBitmapBytes -= existing.byteSize;
    }

    final entry = CachedPageBitmap(
      pdfPath: pdfPath,
      pageNumber: pageNumber,
      scale: scale,
      bytes: bytes,
      width: width,
      height: height,
    );

    // Evict LRU entries (from front of map) while limits exceeded
    while (_bitmapCache.isNotEmpty &&
        (_bitmapCache.length >= _maxBitmapEntries ||
            (_currentBitmapBytes + entry.byteSize > _maxBitmapBytes))) {
      final lruKey = _bitmapCache.keys.first;
      final evicted = _bitmapCache.remove(lruKey);
      if (evicted != null) {
        _currentBitmapBytes -= evicted.byteSize;
      }
    }

    if (_currentBitmapBytes < 0) _currentBitmapBytes = 0;

    _bitmapCache[key] = entry;
    _currentBitmapBytes += entry.byteSize;
  }

  /// Trims excess bitmaps if limits were updated
  void _evictExcessBitmaps() {
    while (_bitmapCache.isNotEmpty &&
        (_bitmapCache.length > _maxBitmapEntries ||
            _currentBitmapBytes > _maxBitmapBytes)) {
      final lruKey = _bitmapCache.keys.first;
      final evicted = _bitmapCache.remove(lruKey);
      if (evicted != null) {
        _currentBitmapBytes -= evicted.byteSize;
      }
    }
    if (_currentBitmapBytes < 0) _currentBitmapBytes = 0;
  }

  /// Invalidates all cached bitmaps for a specific PDF path
  void invalidatePageBitmaps(String pdfPath) {
    final normPath = _fileService.normalizePath(pdfPath);
    final keysToRemove = _bitmapCache.keys
        .where((k) => k.startsWith('$normPath:') || k.startsWith('$pdfPath:'))
        .toList();
    for (final k in keysToRemove) {
      final entry = _bitmapCache.remove(k);
      if (entry != null) {
        _currentBitmapBytes -= entry.byteSize;
      }
    }
    if (_currentBitmapBytes < 0) _currentBitmapBytes = 0;
  }

  /// Invalidates a specific page bitmap
  void invalidatePageBitmap(String pdfPath, int pageNumber, {double scale = 1.0}) {
    final key = CachedPageBitmap.generateKey(pdfPath, pageNumber, scale);
    final entry = _bitmapCache.remove(key);
    if (entry != null) {
      _currentBitmapBytes -= entry.byteSize;
    }
    if (_currentBitmapBytes < 0) _currentBitmapBytes = 0;
  }

  /// Clears only the cached page bitmaps
  void clearPageBitmapCache() {
    _bitmapCache.clear();
    _currentBitmapBytes = 0;
  }

  /// Hook called whenever a tool or viewer is exited.
  /// Purges scratch export directories via FileService and optionally invalidates bitmaps.
  Future<int> onToolOrViewerExit({String? pdfPath, bool clearBitmaps = false}) async {
    if (pdfPath != null) {
      invalidatePageBitmaps(pdfPath);
    } else if (clearBitmaps) {
      clearPageBitmapCache();
    }
    return await _fileService.purgeScratchExportDirectories();
  }

  Future<String> _extractDocxText(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final documentXml = archive.findFile('word/document.xml');
    if (documentXml == null) {
      throw Exception('Not a valid DOCX file (missing word/document.xml)');
    }
    final content = utf8.decode(documentXml.content);

    final StringBuffer textBuffer = StringBuffer();
    final pRegExp = RegExp(r'<w:p\b[^>]*>(.*?)</w:p>');
    final tRegExp = RegExp(r'<w:t\b[^>]*>(.*?)</w:t>');

    final pMatches = pRegExp.allMatches(content);
    for (final pMatch in pMatches) {
      final pContent = pMatch.group(1) ?? '';
      final tMatches = tRegExp.allMatches(pContent);
      final pText =
          tMatches.map((m) => _decodeXmlEntities(m.group(1) ?? '')).join('');
      if (pText.isNotEmpty) {
        textBuffer.writeln(pText);
      }
    }

    if (textBuffer.isEmpty) {
      final tMatches = tRegExp.allMatches(content);
      for (final m in tMatches) {
        textBuffer.write(_decodeXmlEntities(m.group(1) ?? ''));
      }
    }

    return textBuffer.toString();
  }

  String _decodeXmlEntities(String xml) {
    return xml
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
  }
}
