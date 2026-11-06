import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;

import 'models.dart';

/// Kho lời thoại cổ phong (assets/data/messages.json).
/// Chỗ có {ten} sẽ được thay bằng tên sĩ tử.
class Messages {
  final Map<String, List<String>> _table;

  const Messages(this._table);

  factory Messages.fromJson(Map<String, dynamic> json) {
    final Map<String, List<String>> table = <String, List<String>>{};
    json.forEach((String key, dynamic value) {
      table[key] = List<String>.from(value as List<dynamic>);
    });
    return Messages(table);
  }

  String pick(String key, Random rnd, String name) {
    final List<String>? list = _table[key];
    if (list == null || list.isEmpty) {
      return '';
    }
    return list[rnd.nextInt(list.length)].replaceAll('{ten}', name);
  }
}

/// Toàn bộ dữ liệu game đọc từ assets (hoàn toàn offline).
class GameData {
  final List<List<Question>> byLevel;
  final Messages messages;

  const GameData(this.byLevel, this.messages);

  static Future<GameData> load() async {
    final String questionsRaw =
        await rootBundle.loadString('assets/data/questions.json');
    final String messagesRaw =
        await rootBundle.loadString('assets/data/messages.json');

    final List<dynamic> list = jsonDecode(questionsRaw) as List<dynamic>;
    final List<List<Question>> byLevel = <List<Question>>[
      <Question>[],
      <Question>[],
      <Question>[],
    ];
    for (final dynamic item in list) {
      final Question q = Question.fromJson(item as Map<String, dynamic>);
      if (q.level >= 0 && q.level < 3) {
        byLevel[q.level].add(q);
      }
    }

    final Messages messages =
        Messages.fromJson(jsonDecode(messagesRaw) as Map<String, dynamic>);
    return GameData(byLevel, messages);
  }
}
