import 'package:flutter/material.dart';

import '../data.dart';
import '../engine.dart';
import '../theme.dart';
import '../widgets.dart';
import 'game_screen.dart';

class _Laureate {
  final String title;
  final Competitor who;
  final String text;

  const _Laureate(this.title, this.who, this.text);
}

class ResultScreen extends StatefulWidget {
  final GameSession session;
  final GameData data;

  const ResultScreen({super.key, required this.session, required this.data});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late final Outcome _outcome;
  late final List<_Laureate> _podium;
  late final List<Competitor> _hoangGiap;
  late final String _personal;
  late final String _noWinner;

  @override
  void initState() {
    super.initState();
    final GameSession s = widget.session;
    final String name = s.player.name;
    _outcome = s.outcome;

    final List<Competitor> finalists = s.finalists;
    final List<_Laureate> podium = <_Laureate>[];
    for (int i = 0; i < finalists.length && i < 3; i++) {
      final Competitor who = finalists[i];
      podium.add(
        _Laureate(
          kPodiumTitles[i],
          who,
          s.messages.pick(kPodiumKeys[i], s.rnd, who.name),
        ),
      );
    }
    _podium = podium;
    _hoangGiap = finalists.length > 3 ? finalists.sublist(3) : <Competitor>[];

    String key = '';
    switch (_outcome) {
      case Outcome.failHuong:
        key = 'fail_huong';
        break;
      case Outcome.failHoi:
        key = 'fail_hoi';
        break;
      case Outcome.failDinh:
        key = 'fail_dinh';
        break;
      case Outcome.hoangGiap:
        key = 'hoanggiap';
        break;
      case Outcome.thamHoa:
      case Outcome.bangNhan:
      case Outcome.trangNguyen:
        key = ''; // đã có thánh chỉ trong bảng vàng
        break;
    }
    _personal = key.isEmpty ? '' : s.messages.pick(key, s.rnd, name);
    _noWinner =
        podium.isEmpty ? s.messages.pick('khongai', s.rnd, name) : '';
  }

  String get _headline {
    switch (_outcome) {
      case Outcome.trangNguyen:
        return 'TRẠNG NGUYÊN';
      case Outcome.bangNhan:
        return 'BẢNG NHÃN';
      case Outcome.thamHoa:
        return 'THÁM HOA';
      case Outcome.hoangGiap:
        return 'HOÀNG GIÁP';
      case Outcome.failDinh:
        return 'Dừng bước ở Đình thí';
      case Outcome.failHoi:
        return 'Dừng bước ở Hội thí';
      case Outcome.failHuong:
        return 'Dừng bước ở Hương thí';
    }
  }

  bool get _isLaureate =>
      _outcome == Outcome.trangNguyen ||
      _outcome == Outcome.bangNhan ||
      _outcome == Outcome.thamHoa;

  void _again() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => GameScreen(
          data: widget.data,
          playerName: widget.session.player.name,
        ),
      ),
    );
  }

  void _home() {
    Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
  }

  Widget _headlineCard() {
    final bool good = _outcome == Outcome.hoangGiap || _isLaureate;
    final Color color = _isLaureate
        ? AppColors.gold
        : (good ? AppColors.green : AppColors.inkSoft);
    return Panel(
      borderColor: color,
      borderWidth: 2.4,
      child: Column(
        children: <Widget>[
          Icon(
            _isLaureate ? Icons.emoji_events : (good ? Icons.workspace_premium : Icons.menu_book),
            size: 48,
            color: color,
          ),
          const SizedBox(height: 6),
          Text(
            _headline,
            textAlign: TextAlign.center,
            style: serif(
              size: good ? 32 : 24,
              weight: FontWeight.w900,
              color: _isLaureate ? AppColors.red : AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            widget.session.player.name,
            textAlign: TextAlign.center,
            style: serif(size: 17, color: AppColors.inkSoft),
          ),
          if (widget.session.fallenTitle != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              'Danh xưng: ${widget.session.fallenTitle}',
              textAlign: TextAlign.center,
              style: serif(
                size: 18,
                weight: FontWeight.w900,
                color: AppColors.goldDark,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _laureateCard(_Laureate l) {
    final bool me = l.who.isPlayer;
    final int dinhScore = l.who.rounds[2]!.score;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Panel(
        borderColor: me ? AppColors.red : AppColors.gold,
        borderWidth: me ? 2.4 : 1.4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${l.title}: ${l.who.name}${me ? ' (bạn)' : ''}',
                    style: serif(
                      size: 17,
                      weight: FontWeight.w900,
                      color: AppColors.red,
                    ),
                  ),
                ),
                Text(
                  '$dinhScore điểm',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l.text,
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

  Widget _journey() {
    final GameSession s = widget.session;
    final List<Widget> rows = <Widget>[];
    for (int r = 0; r < 3; r++) {
      final RoundTally? t = s.player.rounds[r];
      if (t == null) {
        continue;
      }
      final int rank = s.playerRankInRound(r);
      final int total = s.participantsInRound(r);
      final bool passed = s.player.passedRound(r);
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: <Widget>[
              Expanded(
                flex: 3,
                child: Text(
                  kRoundNames[r],
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '${t.correct}/12 câu',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: passed ? AppColors.green : AppColors.wrong,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text('${t.score} điểm', textAlign: TextAlign.right),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'hạng $rank/$total',
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: AppColors.inkSoft, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Hành trình của bạn',
            style: serif(size: 17, weight: FontWeight.w800, color: AppColors.red),
          ),
          const SizedBox(height: 6),
          ...rows,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = <Widget>[
      Text(
        'Kết quả khoa thi',
        textAlign: TextAlign.center,
        style: serif(size: 15, color: AppColors.inkSoft, letterSpacing: 2),
      ),
      const SizedBox(height: 10),
      _headlineCard(),
    ];

    if (_personal.isNotEmpty) {
      children.add(const SizedBox(height: 12));
      children.add(
        Panel(
          child: Text(
            _personal,
            textAlign: TextAlign.center,
            style: serif(
              size: 16.5,
              weight: FontWeight.w500,
              height: 1.5,
              style: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    children.add(const SizedBox(height: 22));
    children.add(
      Text(
        'BẢNG VÀNG KHOA NÀY',
        textAlign: TextAlign.center,
        style: serif(
          size: 18,
          weight: FontWeight.w900,
          color: AppColors.goldDark,
          letterSpacing: 2,
        ),
      ),
    );
    children.add(const SizedBox(height: 10));

    if (_podium.isEmpty) {
      children.add(
        Panel(
          child: Text(
            _noWinner,
            textAlign: TextAlign.center,
            style: serif(
              size: 16.5,
              weight: FontWeight.w500,
              height: 1.5,
              style: FontStyle.italic,
            ),
          ),
        ),
      );
    } else {
      for (final _Laureate l in _podium) {
        children.add(_laureateCard(l));
      }
      if (_hoangGiap.isNotEmpty) {
        final String names = _hoangGiap
            .map((Competitor c) => c.isPlayer ? '${c.name} (bạn)' : c.name)
            .join(', ');
        children.add(
          Panel(
            child: Text(
              'Hoàng Giáp (${_hoangGiap.length} vị): $names',
              style: const TextStyle(fontSize: 14.5, height: 1.4),
            ),
          ),
        );
      }
    }

    children.add(const SizedBox(height: 14));
    children.add(_journey());
    children.add(const SizedBox(height: 22));
    children.add(
      PrimaryButton(
        label: 'Thi khoa mới',
        icon: Icons.replay,
        onPressed: _again,
      ),
    );
    children.add(const SizedBox(height: 10));
    children.add(SecondaryButton(label: 'Về trang chủ', onPressed: _home));

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}
