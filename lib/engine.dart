import 'dart:math';

import 'data.dart';
import 'models.dart';

// ============================================================
//  LUẬT CHƠI - muốn chỉnh game thì đổi các con số ở đây
// ============================================================
const int kBotCount = 50;
const int kQuestionsPerRound = 12;

/// Điểm: 30 giây = 300 điểm. 1 giây = 100 khắc, cứ 10 khắc trừ 1 điểm.
const int kMaxPoints = 300;
const int kTimeLimitKhac = 3000; // 30 giây

/// Chuỗi: đúng liên tiếp, mỗi câu từ 250 điểm trở lên (tức trả lời trong 5 giây).
/// Từ câu thứ 6 của chuỗi trở đi, mỗi câu được cộng 10 x (độ dài chuỗi - 5).
const int kComboMinPoints = 250;
const int kComboFrom = 5;
const int kComboStep = 10;

/// Số câu đúng tối thiểu: Hương -> Hội, Hội -> Đình, Đình -> được xét bảng vàng.
const List<int> kPassMark = <int>[10, 8, 6];

const List<String> kRoundNames = <String>['Hương thí', 'Hội thí', 'Đình thí'];
const List<String> kRoundKeys = <String>['huong', 'hoi', 'dinh'];
const List<String> kLevelNames = <String>['Dễ', 'Trung bình', 'Khó'];
const List<String> kPodiumTitles = <String>['Trạng Nguyên', 'Bảng Nhãn', 'Thám Hoa'];
const List<String> kPodiumKeys = <String>['trangnguyen', 'bangnhan', 'thamhoa'];

// ---- Độ mạnh của bot (đã chỉnh bằng mô phỏng) ----
// Mỗi ván khoảng 6 bot qua Hương, 3-4 bot qua Hội, 2 bot qua Đình.
const List<double> kBotLevelShift = <double>[0.0, -0.14, -0.30];
const List<double> kBotPaceFactor = <double>[0.85, 1.0, 1.3];
const double kBotTimeoutChance = 0.02;

const List<String> kBotNames = <String>[
  'Nguyễn Văn Chăm', 'Trần Đức Học', 'Lê Minh Trí', 'Phạm Quang Vinh',
  'Hoàng Gia Bảo', 'Vũ Đình Thi', 'Đặng Thanh Tùng', 'Bùi Văn Khoa',
  'Đỗ Công Danh', 'Phan Hữu Nghĩa', 'Ngô Bá Kiên', 'Dương Văn Tài',
  'Lý Thế Anh', 'Đinh Văn Thông', 'Mai Xuân Lộc', 'Hồ Đắc Tâm',
  'Tạ Quốc Bảo', 'Lương Văn Sáng', 'Trịnh Văn Hiền', 'Cao Minh Đạt',
  'Đoàn Văn Lý', 'Tô Ngọc Hải', 'Kiều Văn Dũng', 'La Đình Chương',
  'Chu Văn Thịnh', 'Võ Thành Công', 'Nguyễn Đăng Khoa', 'Trần Thanh Liêm',
  'Lê Văn Thiện', 'Phạm Văn Mẫn', 'Hoàng Đức Hạnh', 'Vũ Công Bằng',
  'Đặng Văn Tín', 'Bùi Quang Minh', 'Đỗ Thế Hiển', 'Phan Văn Trực',
  'Ngô Đình Lễ', 'Dương Hồng Phúc', 'Lý Văn Hòa', 'Đinh Công Chính',
  'Mai Văn Đạo', 'Hồ Văn Kỳ', 'Tạ Văn Nhân', 'Lương Đình Sơn',
  'Trịnh Quốc Việt', 'Cao Văn Thắng', 'Đoàn Minh Triết', 'Tô Văn Hậu',
  'Kiều Anh Tuấn', 'La Văn Thành',
];

// ============================================================
//  Điểm số và chuỗi
// ============================================================

/// Điểm gốc theo số khắc đã trôi (0 khắc = 300 điểm, từ 30 giây trở đi = 0).
/// Làm tròn lên: đúng 5,00 giây (500 khắc) còn 250 điểm, chậm hơn một khắc là dưới 250.
int pointsForKhac(int khac) {
  if (khac >= kTimeLimitKhac) {
    return 0;
  }
  final int p = kMaxPoints - (khac + 9) ~/ 10;
  return p < 0 ? 0 : p;
}

class AnswerRecord {
  final bool correct;
  final int khac;
  final int base;
  final int bonus;
  final int streakAfter;

  const AnswerRecord({
    required this.correct,
    required this.khac,
    required this.base,
    required this.bonus,
    required this.streakAfter,
  });

  int get points => base + bonus;
}

/// Kết quả của một kỳ thi (12 câu) của một sĩ tử.
class RoundTally {
  int correct = 0;
  int score = 0;
  int bonusTotal = 0;
  int totalKhac = 0;
  int streak = 0;
  int bestStreak = 0;
  final List<AnswerRecord> log = <AnswerRecord>[];

  AnswerRecord add({required bool isCorrect, required int khac}) {
    final int used = min(max(khac, 0), kTimeLimitKhac);
    final int base = isCorrect ? pointsForKhac(used) : 0;
    int bonus = 0;
    if (isCorrect && base >= kComboMinPoints) {
      streak += 1;
      if (streak > kComboFrom) {
        bonus = kComboStep * (streak - kComboFrom);
      }
    } else {
      streak = 0; // sai, hết giờ hoặc chậm quá 5 giây: đứt chuỗi
    }
    if (streak > bestStreak) {
      bestStreak = streak;
    }
    if (isCorrect) {
      correct += 1;
    }
    score += base + bonus;
    bonusTotal += bonus;
    totalKhac += used;
    final AnswerRecord rec = AnswerRecord(
      correct: isCorrect,
      khac: used,
      base: base,
      bonus: bonus,
      streakAfter: streak,
    );
    log.add(rec);
    return rec;
  }
}

// ============================================================
//  Sĩ tử (người chơi và bot)
// ============================================================
class Competitor {
  final int id; // 0 = người chơi, 1..50 = bot
  final String name;
  final bool isPlayer;
  final double skill; // độ giỏi cơ bản của bot (xác suất đúng ở bậc dễ)
  final double pace; // số giây trung bình bot cần để trả lời

  /// Kết quả 3 kỳ; null nghĩa là không được dự kỳ đó.
  final List<RoundTally?> rounds = List<RoundTally?>.filled(3, null);

  Competitor({
    required this.id,
    required this.name,
    required this.isPlayer,
    this.skill = 0,
    this.pace = 0,
  });

  bool passedRound(int r) {
    final RoundTally? t = rounds[r];
    return t != null && t.correct >= kPassMark[r];
  }

  int get totalScore {
    int s = 0;
    for (final RoundTally? t in rounds) {
      if (t != null) {
        s += t.score;
      }
    }
    return s;
  }

  int get totalKhac {
    int k = 0;
    for (final RoundTally? t in rounds) {
      if (t != null) {
        k += t.totalKhac;
      }
    }
    return k;
  }
}

double _gauss(Random rnd) {
  final double u1 = max(1e-9, rnd.nextDouble());
  final double u2 = rnd.nextDouble();
  return sqrt(-2.0 * log(u1)) * cos(2.0 * pi * u2);
}

double _drawSkill(Random rnd) => 0.30 + 0.62 * pow(rnd.nextDouble(), 2.0);

double _drawPace(Random rnd) => 2.2 + 11.0 * pow(rnd.nextDouble(), 1.2);

RoundTally _simulateBotRound(Competitor bot, int round, Random rnd) {
  final RoundTally tally = RoundTally();
  final double p = min(0.99, max(0.05, bot.skill + kBotLevelShift[round]));
  for (int i = 0; i < kQuestionsPerRound; i++) {
    bool isCorrect = rnd.nextDouble() < p;
    double seconds =
        bot.pace * kBotPaceFactor[round] * exp(_gauss(rnd) * 0.45);
    seconds = min(29.9, max(0.8, seconds));
    int khac = (seconds * 100).round();
    if (rnd.nextDouble() < kBotTimeoutChance) {
      isCorrect = false;
      khac = kTimeLimitKhac;
    }
    tally.add(isCorrect: isCorrect, khac: khac);
  }
  return tally;
}

// ============================================================
//  Một khoa thi
// ============================================================
enum Outcome {
  failHuong,
  failHoi,
  failDinh,
  tuTai,
  thamHoa,
  bangNhan,
  trangNguyen,
}

class GameSession {
  final Random rnd;
  final Competitor player;
  final List<Competitor> bots;
  final List<List<PlayQuestion>> questions;
  final Messages messages;

  GameSession._(
    this.rnd,
    this.player,
    this.bots,
    this.questions,
    this.messages,
  );

  factory GameSession.start(GameData data, String playerName) {
    final Random rnd = Random();

    // 12 câu bốc ngẫu nhiên từ 20 câu của mỗi bậc, đáp án xáo lại.
    final List<List<PlayQuestion>> rounds = <List<PlayQuestion>>[];
    for (int level = 0; level < 3; level++) {
      final List<Question> pool = List<Question>.of(data.byLevel[level]);
      pool.shuffle(rnd);
      final List<PlayQuestion> picked = <PlayQuestion>[];
      for (final Question q in pool.take(kQuestionsPerRound)) {
        picked.add(PlayQuestion.from(q, rnd));
      }
      rounds.add(picked);
    }

    final Competitor player = Competitor(
      id: 0,
      name: playerName,
      isPlayer: true,
    );

    // 50 bot với độ giỏi và tốc độ ngẫu nhiên, thi trước toàn bộ.
    final List<String> names = List<String>.of(kBotNames);
    names.shuffle(rnd);
    final List<Competitor> bots = <Competitor>[];
    for (int i = 0; i < kBotCount; i++) {
      final Competitor bot = Competitor(
        id: i + 1,
        name: names[i % names.length],
        isPlayer: false,
        skill: _drawSkill(rnd),
        pace: _drawPace(rnd),
      );
      for (int r = 0; r < 3; r++) {
        if (r > 0 && !bot.passedRound(r - 1)) {
          break;
        }
        bot.rounds[r] = _simulateBotRound(bot, r, rnd);
      }
      bots.add(bot);
    }

    return GameSession._(rnd, player, bots, rounds, data.messages);
  }

  List<Competitor> get everyone => <Competitor>[player, ...bots];

  /// Số bot được dự kỳ r (bot qua kỳ trước mới được thi kỳ sau).
  int botsInRound(int r) {
    int n = 0;
    for (final Competitor b in bots) {
      if (b.rounds[r] != null) {
        n += 1;
      }
    }
    return n;
  }

  /// Xếp hạng trong riêng kỳ r: điểm cao hơn, rồi đúng nhiều hơn, rồi nhanh hơn.
  List<Competitor> rankedInRound(int r) {
    final List<Competitor> list =
        everyone.where((Competitor c) => c.rounds[r] != null).toList();
    list.sort((Competitor a, Competitor b) {
      final RoundTally x = a.rounds[r]!;
      final RoundTally y = b.rounds[r]!;
      if (x.score != y.score) {
        return y.score.compareTo(x.score);
      }
      if (x.correct != y.correct) {
        return y.correct.compareTo(x.correct);
      }
      if (x.totalKhac != y.totalKhac) {
        return x.totalKhac.compareTo(y.totalKhac);
      }
      return a.id.compareTo(b.id);
    });
    return list;
  }

  int playerRankInRound(int r) => rankedInRound(r).indexOf(player) + 1;

  int participantsInRound(int r) =>
      everyone.where((Competitor c) => c.rounds[r] != null).length;

  /// Những người đủ điều kiện xét bảng vàng (đúng từ 6/12 câu Đình), đã xếp hạng:
  /// điểm Đình cao hơn thắng; bằng nhau thì xét tổng điểm 3 kỳ; rồi tổng thời gian ít hơn.
  List<Competitor> get finalists {
    final List<Competitor> list =
        everyone.where((Competitor c) => c.passedRound(2)).toList();
    list.sort((Competitor a, Competitor b) {
      final RoundTally x = a.rounds[2]!;
      final RoundTally y = b.rounds[2]!;
      if (x.score != y.score) {
        return y.score.compareTo(x.score);
      }
      if (a.totalScore != b.totalScore) {
        return b.totalScore.compareTo(a.totalScore);
      }
      if (a.totalKhac != b.totalKhac) {
        return a.totalKhac.compareTo(b.totalKhac);
      }
      return a.id.compareTo(b.id);
    });
    return list;
  }

  Outcome get outcome {
    if (!player.passedRound(0)) {
      return Outcome.failHuong;
    }
    if (!player.passedRound(1)) {
      return Outcome.failHoi;
    }
    if (!player.passedRound(2)) {
      return Outcome.failDinh;
    }
    final int rank = finalists.indexOf(player);
    if (rank == 0) {
      return Outcome.trangNguyen;
    }
    if (rank == 1) {
      return Outcome.bangNhan;
    }
    if (rank == 2) {
      return Outcome.thamHoa;
    }
    return Outcome.tuTai;
  }
}
