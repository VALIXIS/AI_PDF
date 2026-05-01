import 'package:hive/hive.dart';

part 'history_entry.g.dart';

@HiveType(typeId: 0)
class HistoryEntry {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final DateTime date;

  @HiveField(3)
  final String filePath;

  @HiveField(4)
  final String toolType; // e.g., 'ai_to_pdf', 'text_to_pdf', etc.

  HistoryEntry({
    required this.id,
    required this.title,
    required this.date,
    required this.filePath,
    required this.toolType,
  });

  /// Create a copy with modified fields
  HistoryEntry copyWith({
    String? id,
    String? title,
    DateTime? date,
    String? filePath,
    String? toolType,
  }) {
    return HistoryEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      filePath: filePath ?? this.filePath,
      toolType: toolType ?? this.toolType,
    );
  }

  @override
  String toString() => 'HistoryEntry(id: $id, title: $title, date: $date)';
}
