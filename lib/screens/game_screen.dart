import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../data.dart';
import '../engine.dart';
import '../leaderboard.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'result_screen.dart';

enum GamePhase { intro, question, feedback, roundEnd }

class GameScreen extends StatefulWidget {
  final GameData data;
  final String playerName;

  const GameScreen({super.key, required this.data, required this.playerName});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final GameSession _session;
  final Stopwatch _watch = Stopwatch();
  Timer? _ticker;

  GamePhase _phase = GamePhase.intro;
  int _round = 0; // 0 Hương, 1 Hội, 2 Đình
  int _qIndex = 0;
  int _khac = 0; // số khắc đã trôi ở câu hiện tại
  int? _picked; // đáp án đã chọn; -1 nếu hết giờ
  AnswerRecord? _last;

  String _flavor = '';
  bool _roundPassed = false;
  int _roundRank = 0;
  int _roundTotal = 0;
  String _roundMessage = '';
  List<StandingRow> _rows = <StandingRow>[];
  int _passedCount = 0;
  String _titleName = ''; // danh xưng nếu rớt giữa chừng (Cử Nhân, Phó Bảng)
  String _titleText = '';

  @override
  void initState() {
    super.initState();
    _session = GameSession.start(widget.data, widget.playerName);
    _flavor = _intro(0);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _intro(int round) {
    return _session.messages.pick(
      'intro_${kRoundKeys[round]}',
      _session.rnd,
      widget.playerName,
    );
  }

  List<PlayQuestion> get _questions => _session.questions[_round];
  PlayQuestion get _current => _questions[_qIndex];
  RoundTally get _tally => _session.player.rounds[_round]!;

  // ---------------- Luồng chơi ----------------

  void _startRound() {
    _session.player.rounds[_round] = RoundTally();
    _qIndex = 0;
    _beginQuestion();
  }

  void _beginQuestion() {
    _ticker?.cancel();
    _watch.stop();
    _watch.reset();
    setState(() {
      _picked = null;
      _last = null;
      _khac = 0;
      _phase = GamePhase.question;
    });
    // Đồng hồ chỉ chạy khi câu hỏi đã hiện lên màn hình.
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (!mounted || _phase != GamePhase.question) {
        return;
      }
      _watch.reset();
      _watch.start();
      _ticker = Timer.periodic(const Duration(milliseconds: 40), _onTick);
    });
  }

  void _onTick(Timer timer) {
    if (_phase != GamePhase.question) {
      return;
    }
    final int k = _watch.elapsedMilliseconds ~/ 10;
    if (k >= kTimeLimitKhac) {
      _answer(-1);
    } else {
      setState(() => _khac = k);
    }
  }

  void _answer(int choice) {
    if (_phase != GamePhase.question) {
      return;
    }
    _watch.stop();
    _ticker?.cancel();
    final PlayQuestion pq = _current;
    final int khac = choice < 0
        ? kTimeLimitKhac
        : min(_watch.elapsedMilliseconds ~/ 10, kTimeLimitKhac);
    final bool isCorrect = choice == pq.correctIndex;
    final AnswerRecord rec = _tally.add(isCorrect: isCorrect, khac: khac);
    setState(() {
      _picked = choice;
      _last = rec;
      _khac = khac;
      _phase = GamePhase.feedback;
    });
  }

  void _next() {
    if (_qIndex + 1 < _questions.length) {
      _qIndex += 1;
      _beginQuestion();
    } else {
      _finishRound();
    }
  }

  void _finishRound() {
    _ticker?.cancel();
    final RoundTally t = _tally;
    final bool passed = t.correct >= kPassMark[_round];
    String message = '';
    if (passed && _round < 2) {
      message = _session.messages.pick(
        'pass_${kRoundKeys[_round]}',
        _session.rnd,
        widget.playerName,
      );
    }
    // Rớt Hội thì là Cử Nhân, rớt Đình thì là Phó Bảng.
    String titleName = '';
    String titleText = '';
    if (!passed && _round == 1) {
      titleName = kTitleCuNhan;
      titleText = _session.messages
          .pick('danh_cunhan', _session.rnd, widget.playerName);
    } else if (!passed && _round == 2) {
      titleName = kTitlePhoBang;
      titleText = _session.messages
          .pick('danh_phobang', _session.rnd, widget.playerName);
    }
    setState(() {
      _roundPassed = passed;
      _roundRank = _session.playerRankInRound(_round);
      _roundTotal = _session.participantsInRound(_round);
      _roundMessage = message;
      _rows = _session.standings(_round);
      _passedCount = _session.passedInRound(_round);
      _titleName = titleName;
      _titleText = titleText;
      _phase = GamePhase.roundEnd;
    });
  }

  void _afterRound() {
    if (_roundPassed && _round < 2) {
      setState(() {
        _round += 1;
        _qIndex = 0;
        _flavor = _intro(_round);
        _phase = GamePhase.intro;
      });
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (BuildContext context) =>
              ResultScreen(session: _session, data: widget.data),
        ),
      );
    }
  }

  Future<void> _confirmExit() async {
    final bool wasRunning = _phase == GamePhase.question && _watch.isRunning;
    if (wasRunning) {
      _watch.stop();
    }
    final bool? quit = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Bỏ thi giữa chừng?'),
        content: const Text('Kết quả khoa thi này sẽ không được tính.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Tiếp tục thi'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Bỏ thi'),
          ),
        ],
      ),
    );
    if (!mounted) {
      return;
    }
    if (quit == true) {
      Navigator.of(context).pop();
    } else if (wasRunning && _phase == GamePhase.question) {
      _watch.start();
    }
  }

  // ---------------- Giao diện ----------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop) {
          _confirmExit();
        }
      },
      child: Scaffold(
        body: SafeArea(child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    if (_phase == GamePhase.intro) {
      return _buildIntro();
    }
    if (_phase == GamePhase.roundEnd) {
      return _buildRoundEnd();
    }
    return _buildQuestion();
  }

  Widget _buildIntro() {
    final int r = _round;
    final String rule = r < 2
        ? 'Đúng từ ${kPassMark[r]}/12 câu trở lên để vào ${kRoundNames[r + 1]}.'
        : 'Đúng từ ${kPassMark[r]}/12 câu trở lên mới được xét bảng vàng.';
    return PageScroll(
      children: <Widget>[
        Text(
          kRoundNames[r].toUpperCase(),
          textAlign: TextAlign.center,
          style: serif(size: 36, weight: FontWeight.w900, color: AppColors.red),
        ),
        const SizedBox(height: 4),
        Text(
          'Kỳ ${r + 1}/3  ·  Cấp độ ${kLevelNames[r].toLowerCase()}',
          textAlign: TextAlign.center,
          style: serif(size: 15, color: AppColors.inkSoft),
        ),
        const SizedBox(height: 20),
        Panel(
          child: Text(
            _flavor,
            textAlign: TextAlign.center,
            style: serif(
              size: 17,
              weight: FontWeight.w500,
              height: 1.5,
              style: FontStyle.italic,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Panel(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: <Widget>[
              StatRow(label: 'Số câu hỏi', value: '${_questions.length}'),
              const StatRow(label: 'Thời gian mỗi câu', value: '30 giây'),
              StatRow(
                label: 'Sĩ tử máy cùng dự thi',
                value: '${_session.botsInRound(r)}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          rule,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14.5, color: AppColors.inkSoft),
        ),
        const SizedBox(height: 22),
        PrimaryButton(
          label: 'Vào trường thi',
          icon: Icons.edit,
          onPressed: _startRound,
        ),
      ],
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _optionTile(int i, PlayQuestion pq) {
    final bool answering = _phase == GamePhase.question;
    Color bg = AppColors.card;
    Color border = AppColors.goldDark;
    if (!answering) {
      if (i == pq.correctIndex) {
        bg = AppColors.rightBg;
        border = AppColors.green;
      } else if (i == _picked) {
        bg = AppColors.wrongBg;
        border = AppColors.wrong;
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: answering ? () => _answer(i) : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: 1.6),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.red,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  String.fromCharCode(65 + i),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  pq.options[i],
                  style: const TextStyle(
                    fontSize: 16.5,
                    height: 1.25,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestion() {
    final PlayQuestion pq = _current;
    final bool answering = _phase == GamePhase.question;
    final int remaining = kTimeLimitKhac - _khac;
    final double frac = max(0.0, min(1.0, remaining / kTimeLimitKhac));
    final int pointsNow = pointsForKhac(_khac);
    final bool inComboZone = pointsNow >= kComboMinPoints;
    final Color barColor = inComboZone
        ? AppColors.green
        : (remaining < 500 ? AppColors.wrong : AppColors.gold);
    final int streak = _tally.streak;
    final int nextBonus =
        streak + 1 > kComboFrom ? kComboStep * (streak + 1 - kComboFrom) : 0;

    final List<Widget> chips = <Widget>[
      _chip(pq.topic, AppColors.goldDark),
      _chip('Chuỗi $streak', streak > 0 ? AppColors.red : AppColors.inkSoft),
    ];
    if (answering && nextBonus > 0) {
      chips.add(_chip('Thưởng chuỗi +$nextBonus nếu đáp trong 5 giây', AppColors.green));
    }

    final List<Widget> children = <Widget>[
      Row(
        children: <Widget>[
          Expanded(
            child: Text(
              '${kRoundNames[_round]}  ·  Câu ${_qIndex + 1}/${_questions.length}',
              style: serif(size: 16, weight: FontWeight.w800, color: AppColors.red),
            ),
          ),
          Text(
            'Điểm ${_tally.score}',
            style: serif(size: 16, weight: FontWeight.w800),
          ),
        ],
      ),
      const SizedBox(height: 10),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: frac,
          minHeight: 12,
          color: barColor,
          backgroundColor: const Color(0xFFE3D5B5),
        ),
      ),
      const SizedBox(height: 6),
      Row(
        children: <Widget>[
          Text(
            'Còn ${(remaining / 100).toStringAsFixed(1)} giây',
            style: const TextStyle(fontSize: 14, color: AppColors.inkSoft),
          ),
          const Spacer(),
          Text(
            answering ? 'Đáp lúc này: $pointsNow điểm' : 'Đã chốt đáp án',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: inComboZone && answering ? AppColors.green : AppColors.ink,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 6, children: chips),
      const SizedBox(height: 14),
      Panel(
        padding: const EdgeInsets.all(18),
        child: Text(
          pq.text,
          style: serif(size: 20, weight: FontWeight.w700, height: 1.35),
        ),
      ),
      const SizedBox(height: 14),
    ];

    for (int i = 0; i < pq.options.length; i++) {
      children.add(_optionTile(i, pq));
    }

    if (!answering) {
      children.add(const SizedBox(height: 4));
      children.add(_buildFeedback(pq));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _buildFeedback(PlayQuestion pq) {
    final AnswerRecord rec = _last!;
    final bool timedOut = _picked == -1;
    final bool last = _qIndex + 1 >= _questions.length;

    String title;
    String detail;
    Color color;
    if (rec.correct) {
      title = 'Chính xác!';
      color = AppColors.green;
      detail =
          '+${rec.points} điểm  (${(rec.khac / 100).toStringAsFixed(2)} giây)';
      if (rec.bonus > 0) {
        detail += '\nTrong đó thưởng chuỗi +${rec.bonus}. Chuỗi đang là ${rec.streakAfter}.';
      } else if (rec.base < kComboMinPoints) {
        detail += '\nTrả lời chậm quá 5 giây nên đứt chuỗi.';
      } else if (rec.streakAfter > 0) {
        detail += '\nChuỗi đang là ${rec.streakAfter}.';
      }
    } else {
      title = timedOut ? 'Hết giờ!' : 'Chưa đúng!';
      color = AppColors.wrong;
      detail =
          'Đáp án đúng: ${String.fromCharCode(65 + pq.correctIndex)}. ${pq.options[pq.correctIndex]}\nChuỗi bị đứt.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Panel(
          borderColor: color,
          borderWidth: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: serif(size: 20, weight: FontWeight.w900, color: color),
              ),
              const SizedBox(height: 4),
              Text(
                detail,
                style: const TextStyle(fontSize: 15, height: 1.4, color: AppColors.ink),
              ),
              if (pq.explain.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  'Giải thích: ${pq.explain}',
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    fontStyle: FontStyle.italic,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        PrimaryButton(
          label: last ? 'Xem kết quả kỳ thi' : 'Câu tiếp theo',
          onPressed: _next,
        ),
      ],
    );
  }

  Widget _dot(AnswerRecord rec) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: rec.correct ? AppColors.green : AppColors.wrong,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildRoundEnd() {
    final RoundTally t = _tally;
    final int r = _round;
    final int need = kPassMark[r];

    String status;
    if (_roundPassed && r < 2) {
      status = 'Đạt! Đúng từ $need/12 trở lên, được vào ${kRoundNames[r + 1]}.';
    } else if (_roundPassed) {
      status = 'Đạt! Đã đủ điều kiện xét bảng vàng.';
    } else if (r < 2) {
      status = 'Chưa đạt. Cần đúng từ $need/12 để vào ${kRoundNames[r + 1]}.';
    } else {
      status = 'Chưa đạt. Cần đúng từ $need/12 để được xét bảng vàng.';
    }
    final Color statusColor = _roundPassed ? AppColors.green : AppColors.wrong;

    final List<Widget> children = <Widget>[
      Text(
        'Kết thúc ${kRoundNames[r]}',
        textAlign: TextAlign.center,
        style: serif(size: 26, weight: FontWeight.w900, color: AppColors.red),
      ),
      const SizedBox(height: 14),
      Panel(
        child: Column(
          children: <Widget>[
            Text(
              '${t.correct}/${_questions.length}',
              style: serif(size: 54, weight: FontWeight.w900),
            ),
            const Text('câu đúng', style: TextStyle(color: AppColors.inkSoft)),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[for (final AnswerRecord rec in t.log) _dot(rec)],
            ),
            const SizedBox(height: 12),
            StatRow(label: 'Điểm kỳ này', value: '${t.score}'),
            StatRow(label: 'Trong đó thưởng chuỗi', value: '+${t.bonusTotal}'),
            StatRow(label: 'Chuỗi dài nhất', value: '${t.bestStreak}'),
            StatRow(label: 'Hạng trong kỳ này', value: '$_roundRank/$_roundTotal'),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Panel(
        borderColor: statusColor,
        borderWidth: 2,
        child: Text(
          status,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: statusColor,
          ),
        ),
      ),
    ];

    if (_roundMessage.isNotEmpty) {
      children.add(const SizedBox(height: 12));
      children.add(
        Panel(
          child: Text(
            _roundMessage,
            textAlign: TextAlign.center,
            style: serif(
              size: 16,
              weight: FontWeight.w500,
              height: 1.5,
              style: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    if (_titleName.isNotEmpty) {
      children.add(const SizedBox(height: 12));
      children.add(
        Panel(
          borderColor: AppColors.gold,
          borderWidth: 2.2,
          child: Column(
            children: <Widget>[
              Text(
                'Danh xưng: $_titleName',
                textAlign: TextAlign.center,
                style: serif(
                  size: 20,
                  weight: FontWeight.w900,
                  color: AppColors.goldDark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _titleText,
                textAlign: TextAlign.center,
                style: serif(
                  size: 15.5,
                  weight: FontWeight.w500,
                  height: 1.5,
                  style: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      );
    }

    children.add(const SizedBox(height: 14));
    children.add(
      StandingsPanel(
        title: r == 2
            ? 'Bảng xếp hạng Đình thí'
            : 'Bảng xếp hạng sau ${kRoundNames[r]}',
        round: r,
        rows: _rows,
        passedCount: _passedCount,
        participantCount: _roundTotal,
      ),
    );

    children.add(const SizedBox(height: 20));
    children.add(
      PrimaryButton(
        label: (_roundPassed && r < 2)
            ? 'Vào ${kRoundNames[r + 1]}'
            : 'Xem bảng vàng',
        onPressed: _afterRound,
      ),
    );

    return PageScroll(children: children);
  }
}
