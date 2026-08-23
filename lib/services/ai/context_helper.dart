class ContextHelper {
  /// Safely limits the document text to avoid exceeding token limits,
  /// while preserving the introduction/head and conclusion/tail.
  static String limitText(String text, {int maxChars = 32000}) {
    if (text.length <= maxChars) return text;

    final headSize = (maxChars * 0.75).round();
    final tailSize = maxChars - headSize - 100;

    final head = text.substring(0, headSize);
    final tail = text.substring(text.length - tailSize);

    return '$head\n\n... [Content Truncated for token limit optimization] ...\n\n$tail';
  }
}
