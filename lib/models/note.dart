import 'package:easy_localization/easy_localization.dart';

class Note {
  final String id;
  final String title;
  final String content;
  final String label;
  final DateTime date;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.label,
    required this.date,
  });

  // Get a clean plain-text snippet of the content without Markdown syntax
  String get plainTextSnippet {
    if (content.trim().isEmpty) return '';

    String cleaned = content;

    // 1. Remove Code blocks
    cleaned = cleaned.replaceAll(RegExp(r'```[\s\S]*?```'), '');

    // 2. Remove HTML tags (if any)
    cleaned = cleaned.replaceAll(RegExp(r'<[^>]*>'), '');

    // 3. Remove markdown headers (e.g. # Heading)
    cleaned = cleaned.replaceAll(RegExp(r'^#+\s+', multiLine: true), '');

    // 4. Remove blockquotes (e.g. > Quote)
    cleaned = cleaned.replaceAll(RegExp(r'^>\s+', multiLine: true), '');

    // 5. Remove task lists / checkboxes (e.g. - [ ] task)
    cleaned = cleaned.replaceAll(RegExp(r'^-\s+\[[ xX]\]\s+', multiLine: true), '');

    // 6. Remove list bullets (e.g. - list item, 1. list item)
    cleaned = cleaned.replaceAll(RegExp(r'^[-*+]\s+', multiLine: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'^\d+\.\s+', multiLine: true), '');

    // 7. Remove bold / italic markers
    cleaned = cleaned.replaceAll(RegExp(r'\*\*|__|\*|_|`'), '');

    // 8. Simplify links [text](url) -> text
    cleaned = cleaned.replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]+\)'), (match) => match.group(1) ?? '');

    // 9. Remove image links ![alt](url) -> ''
    cleaned = cleaned.replaceAll(RegExp(r'!\[[^\]]*\]\([^)]+\)'), '');

    // 10. Collapse multiple whitespaces and newlines
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    return cleaned;
  }

  // Calculate word count dynamically
  int get wordCount {
    if (content.trim().isEmpty) return 0;
    return content.trim().split(RegExp(r'\s+')).length;
  }

  // Create a copy of the note with updated fields
  Note copyWith({
    String? id,
    String? title,
    String? content,
    String? label,
    DateTime? date,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      label: label ?? this.label,
      date: date ?? this.date,
    );
  }

  // Formatted date string (e.g. OCTOBER 24, 2023)
  String get formattedDate {
    final monthsKeys = [
      'january', 'february', 'march', 'april', 'may', 'june',
      'july', 'august', 'september', 'october', 'november', 'december'
    ];
    final monthName = 'months.${monthsKeys[date.month - 1]}'.tr();
    return 'date_format'.tr(namedArgs: {
      'month': monthName,
      'day': date.day.toString().padLeft(2, '0'),
      'year': date.year.toString(),
    });
  }

  // Readable relative time for summary list (e.g. "2 HOURS AGO")
  String get relativeTime {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      if (minutes <= 1) {
        return "relative_time.minute_ago".tr();
      }
      return "relative_time.minutes_ago".tr(args: [minutes.toString()]);
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      if (hours <= 1) {
        return "relative_time.hour_ago".tr();
      }
      return "relative_time.hours_ago".tr(args: [hours.toString()]);
    } else if (difference.inDays == 1) {
      return "relative_time.yesterday".tr();
    } else if (difference.inDays < 7) {
      return "relative_time.days_ago".tr(args: [difference.inDays.toString()]);
    } else {
      final monthsAbbr = [
        'jan', 'feb', 'mar', 'apr', 'may', 'jun',
        'jul', 'aug', 'sep', 'oct', 'nov', 'dec'
      ];
      final monthStr = 'months_abbr.${monthsAbbr[date.month - 1]}'.tr();
      return "$monthStr ${date.day}";
    }
  }

  // Convert Note to a Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'label': label,
      'date': date.toIso8601String(),
    };
  }

  // Create a Note from a database Map
  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      label: map['label'] as String,
      date: DateTime.parse(map['date'] as String),
    );
  }
}
