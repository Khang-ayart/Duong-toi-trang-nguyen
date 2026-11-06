import 'dart:math';

/// Một câu hỏi đọc từ assets/data/questions.json.
class Question {
  final String id;
  final int level; // 0 = dễ (Hương), 1 = trung bình (Hội), 2 = khó (Đình)
  final String topic;
  final String text;
  final List<String> options;
  final int answer; // vị trí đáp án đúng trong options

  const Question({
    required this.id,
    required this.level,
    required this.topic,
    required this.text,
    required this.options,
    required this.answer,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] as String,
      level: json['level'] as int,
      topic: json['topic'] as String,
      text: json['q'] as String,
      options: List<String>.from(json['options'] as List<dynamic>),
      answer: json['answer'] as int,
    );
  }
}

/// Câu hỏi đã xáo thứ tự 4 đáp án cho một lượt chơi.
class PlayQuestion {
  final Question source;
  final List<String> options;
  final int correctIndex;

  const PlayQuestion(this.source, this.options, this.correctIndex);

  factory PlayQuestion.from(Question q, Random rnd) {
    final List<int> order = List<int>.generate(q.options.length, (int i) => i);
    order.shuffle(rnd);
    final List<String> shuffled = <String>[];
    for (final int i in order) {
      shuffled.add(q.options[i]);
    }
    return PlayQuestion(q, shuffled, order.indexOf(q.answer));
  }

  String get text => source.text;
  String get topic => source.topic;
}
