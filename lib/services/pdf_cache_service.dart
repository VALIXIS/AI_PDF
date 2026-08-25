import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
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
  Future<CachedPdfData> getPdfData(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File does not exist: $filePath');
    }

    final stat = await file.stat();
    final cached = _cache[filePath];

    // Cache hit: return immediately if file has not been modified
    if (cached != null && cached.lastModified.isAtSameMomentAs(stat.modified)) {
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
      clean = clean.replaceAll(RegExp(r'<style[^>]*>.*?<\/style>', caseSensitive: false, dotAll: true), '');
      clean = clean.replaceAll(RegExp(r'<script[^>]*>.*?<\/script>', caseSensitive: false, dotAll: true), '');
      clean = clean.replaceAll(RegExp(r'<head[^>]*>.*?<\/head>', caseSensitive: false, dotAll: true), '');
      text = clean.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
      count = (text.length / 2000).ceil().clamp(1, 1000);
    } else {
      throw Exception('Unsupported file format: .$extension');
    }

    final newData = CachedPdfData(
      pdfPath: filePath,
      pageCount: count,
      textContent: text,
      lastModified: stat.modified,
      cachedAt: DateTime.now(),
    );

    _cache[filePath] = newData;
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
