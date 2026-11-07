import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../data.dart';
import '../engine.dart';
import '../lan/lan_client.dart';
import '../lan/lan_host.dart';
import '../lan/lan_net.dart';
import '../lan/lan_rules.dart';
import '../leaderboard.dart';
import '../theme.dart';
import '../widgets.dart';

/// Phòng thi So tài: một màn hình đổi nội dung theo giai đoạn
/// (sảnh chờ, đang làm bài, xem đáp án, bảng vàng cuối khoa).
class LanRoomScreen extends StatefulWidget {
  final LanClient client;
  final LanHost? host; // chỉ có ở máy chủ phòng
  final GameData data;

  const LanRoomScreen({
    super.key,
    required this.client,
    required this.host,
    required this.data,
  });

  @override
  State<LanRoomScreen> createState() => _LanRoomScreenState();
}

class _LanRoomScreenState extends State<LanRoomScreen> {
  final Random _rnd = Random();
  Timer? _ticker;
  Future<List<String>>? _ipFuture;
  String _finalMsg = '';
  String _noWinnerMsg = '';

  LanClient get _c => widget.client;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onChange);
    if (widget.host != null) {
      _ipFuture = localIPv4s();
    }
    // làm mới giao diện mỗi 0,1 giây để đồng hồ đếm ngược chạy mượt
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (Timer t) {
      if (!mounted) {
        return;
      }
      if (_c.phase == LanPhase.question || _c.phase == LanPhase.reveal) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _c.removeListener(_onChange);
    _c.dispose();
    widget.host?.close();
    super.dispose();
  }

  void _onChange() {
    if (!mounted) {
      return;
    }
    if (_c.phase == LanPhase.finished && _finalMsg.isEmpty) {
      _prepareFinalMessages();
    }
    setState(() {});
  }

  void _prepareFinalMessages() {
    final LanFinalEntry? me = _c.myFinal;
    if (me == null) {
      return;
    }
    _finalMsg = widget.data.messages.pick(lanTitleMessageKey(me.title), _rnd, me.name);
    final bool anyPassed = _c.finalBoard.any(
      (LanFinalEntry e) => e.title.index >= LanTitle.hoangGiap.index,
    );
    if (!anyPassed) {
      _noWinnerMsg = widget.data.messages.pick('khongai', _rnd, me.name);
    }
  }

  void _leave() {
    Navigator.of(context).pop();
  }

  Competitor _who(int id, String name) {
    return Competitor(id: id, name: name, isPlayer: id == _c.myId);
  }

  // ------------------------------------------------------------
  //  Khung chung
  // ------------------------------------------------------------

  Widget _scroll(List<Widget> children) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  String _titleForPhase() {
    switch (_c.phase) {
      case LanPhase.connecting:
        return 'Đang vào phòng';
      case LanPhase.lobby:
        return 'Phòng ${_c.room}';
      case LanPhase.question:
      case LanPhase.reveal:
        return 'So tài · Phòng ${_c.room}';
      case LanPhase.finished:
        return 'Bảng vàng';
      case LanPhase.closed:
        return 'So tài';
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    switch (_c.phase) {
      case LanPhase.connecting:
        body = const Center(child: CircularProgressIndicator());
        break;
      case LanPhase.lobby:
        body = _buildLobby();
        break;
      case LanPhase.question:
        body = _buildQuestion();
        break;
      case LanPhase.reveal:
        body = _buildReveal();
        break;
      case LanPhase.finished:
        body = _buildFinal();
        break;
      case LanPhase.closed:
        body = _buildClosed();
        break;
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(_titleForPhase()),
        backgroundColor: AppColors.paper,
        foregroundColor: AppColors.red,
        elevation: 0,
      ),
      body: SafeArea(child: body),
    );
  }

  // ------------------------------------------------------------
  //  Sảnh chờ
  // ------------------------------------------------------------

  Widget _buildLobby() {
    final List<Widget> children = <Widget>[
      Panel(
        child: Column(
          children: <Widget>[
            Text('Mã phòng', style: serif(size: 15, color: AppColors.inkSoft)),
            Text(
              _c.room,
              style: serif(
                size: 56,
                weight: FontWeight.w900,
                color: AppColors.red,
                letterSpacing: 8,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Đọc mã này cho mọi người, họ vào So tài rồi bấm Tìm phòng.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.35, color: AppColors.inkSoft),
            ),
          ],
        ),
      ),
    ];

    if (_ipFuture != null) {
      children.add(const SizedBox(height: 8));
      children.add(
        FutureBuilder<List<String>>(
          future: _ipFuture,
          builder: (BuildContext context, AsyncSnapshot<List<String>> snap) {
            final List<String> ips = snap.data ?? <String>[];
            if (ips.isEmpty) {
              return const SizedBox.shrink();
            }
            final String shown = ips.take(2).join('  hoặc  ');
            return Text(
              'Nếu ai đó không tìm thấy phòng, hãy bảo họ nhập địa chỉ IP: $shown',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, height: 1.35, color: AppColors.inkSoft),
            );
          },
        ),
      );
    }

    children.add(const SizedBox(height: 14));
    children.add(
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Sĩ tử trong phòng (${_c.members.length}/$kLanMaxPlayers)',
              style: serif(size: 17, weight: FontWeight.w800, color: AppColors.red),
            ),
            const SizedBox(height: 8),
            ..._c.members.map(_memberRow),
          ],
        ),
      ),
    );
    children.add(const SizedBox(height: 16));

    if (_c.startingSoon) {
      children.add(
        Text(
          'Sắp vào Hương thí, chuẩn bị tinh thần!',
          textAlign: TextAlign.center,
          style: serif(size: 18, weight: FontWeight.w800, color: AppColors.green),
        ),
      );
    } else if (_c.isHost) {
      children.add(
        PrimaryButton(
          label: 'Bắt đầu thi (${_c.members.length} người)',
          icon: Icons.play_arrow,
          onPressed: _c.startGame,
        ),
      );
      if (_c.members.length < 2) {
        children.add(const SizedBox(height: 8));
        children.add(
          const Text(
            'Mới có một người. Bạn vẫn có thể bắt đầu để chơi thử.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
          ),
        );
      }
    } else {
      children.add(
        Text(
          'Đang chờ chủ phòng bắt đầu...',
          textAlign: TextAlign.center,
          style: serif(size: 16, color: AppColors.inkSoft),
        ),
      );
    }
    children.add(const SizedBox(height: 12));
    children.add(SecondaryButton(label: 'Rời phòng', onPressed: _leave));
    return _scroll(children);
  }

  Widget _memberRow(LanMember m) {
    final bool me = m.id == _c.myId;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          CompetitorAvatar(who: _who(m.id, m.name), size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              me ? '${m.name} (bạn)' : m.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: me ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          if (m.isHost) _chip('Chủ phòng', AppColors.goldDark),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  //  Đang làm bài
  // ------------------------------------------------------------

  Widget _optionTile(int i) {
    final bool answering = !_c.hasAnswered;
    final bool picked = _c.myPick == i;
    final Color bg = picked ? const Color(0xFFF6E3B4) : AppColors.card;
    final Color border = picked ? AppColors.gold : AppColors.goldDark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: answering ? () => _c.sendAnswer(i) : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: picked ? 2.4 : 1.6),
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
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _c.qOptions[i],
                  style: const TextStyle(fontSize: 16.5, height: 1.25, color: AppColors.ink),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestion() {
    final int remainingMs = _c.remainingMs;
    final double frac = max(0.0, min(1.0, remainingMs / _c.qDurationMs));
    final int khacUsed = (_c.qDurationMs - remainingMs) ~/ 10;
    final int pointsNow = pointsForKhac(khacUsed);
    final bool inCombo = pointsNow >= kComboMinPoints;
    final bool answering = !_c.hasAnswered;
    final Color barColor = inCombo
        ? AppColors.green
        : (remainingMs < 5000 ? AppColors.wrong : AppColors.gold);

    final bool firstOfRound = _c.qIndex % kLanPerRound == 0;
    final LanRevealEntry? last = _c.myReveal;
    final int streak = firstOfRound ? 0 : (last?.streak ?? 0);
    final int nextBonus =
        streak + 1 > kComboFrom ? kComboStep * (streak + 1 - kComboFrom) : 0;
    final int myTotal = last?.total ?? 0;
    final int numberInRound = (_c.qIndex % kLanPerRound) + 1;

    final List<Widget> chips = <Widget>[
      _chip(_c.qTopic, AppColors.goldDark),
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
              '${kRoundNames[_c.qLevel]}  ·  Câu $numberInRound/$kLanPerRound',
              style: serif(size: 16, weight: FontWeight.w800, color: AppColors.red),
            ),
          ),
          Text('Điểm $myTotal', style: serif(size: 16, weight: FontWeight.w800)),
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
            'Còn ${(remainingMs / 1000).toStringAsFixed(1)} giây',
            style: const TextStyle(fontSize: 14, color: AppColors.inkSoft),
          ),
          const Spacer(),
          Text(
            answering ? 'Đáp lúc này: $pointsNow điểm' : 'Đã chốt đáp án',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: inCombo && answering ? AppColors.green : AppColors.ink,
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
          _c.qText,
          style: serif(size: 20, weight: FontWeight.w700, height: 1.35),
        ),
      ),
      const SizedBox(height: 14),
    ];

    for (int i = 0; i < _c.qOptions.length; i++) {
      children.add(_optionTile(i));
    }

    if (!answering) {
      children.add(const SizedBox(height: 4));
      children.add(
        Text(
          'Chờ các sĩ tử khác... (${_c.answeredCount}/${_c.onlineCount} đã đáp)',
          textAlign: TextAlign.center,
          style: serif(size: 15, color: AppColors.inkSoft),
        ),
      );
    }
    return _scroll(children);
  }

  // ------------------------------------------------------------
  //  Xem đáp án và bảng xếp hạng sau mỗi câu
  // ------------------------------------------------------------

  Widget _changeChip(int change) {
    if (change == 0) {
      return const Text(
        '–',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.inkSoft, fontWeight: FontWeight.w700),
      );
    }
    final bool up = change > 0;
    return Text(
      '${up ? '▲' : '▼'}${change.abs()}',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w800,
        color: up ? AppColors.green : AppColors.wrong,
      ),
    );
  }

  Widget _boardRow(LanRevealEntry e) {
    final bool me = e.id == _c.myId;
    final Color mark = e.ok ? AppColors.green : AppColors.wrong;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: me ? const Color(0xFFF6E3B4) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: me ? Border.all(color: AppColors.gold, width: 1.2) : null,
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 26,
            child: Text(
              '${e.rank}',
              textAlign: TextAlign.center,
              style: serif(
                size: 16,
                weight: FontWeight.w900,
                color: e.rank <= 3 ? AppColors.red : AppColors.ink,
              ),
            ),
          ),
          const SizedBox(width: 4),
          CompetitorAvatar(who: _who(e.id, e.name), size: 32),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  me ? '${e.name} (bạn)' : e.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: me ? FontWeight.w800 : FontWeight.w600,
                    color: e.online ? AppColors.ink : AppColors.inkSoft,
                  ),
                ),
                Row(
                  children: <Widget>[
                    Icon(e.ok ? Icons.check_circle : Icons.cancel, size: 13, color: mark),
                    const SizedBox(width: 3),
                    Text(
                      e.streak >= 2 ? 'Chuỗi ${e.streak}' : (e.ok ? 'Đúng' : (e.pick == -1 ? 'Không đáp' : 'Sai')),
                      style: TextStyle(fontSize: 11.5, color: mark),
                    ),
                    if (e.roundPass != null) ...<Widget>[
                      const SizedBox(width: 6),
                      Text(
                        e.roundPass! ? 'Đạt' : 'Dừng bước',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: e.roundPass! ? AppColors.green : AppColors.wrong,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 36, child: _changeChip(e.change)),
          SizedBox(
            width: 58,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  '${e.total}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                Text(
                  '+${e.pts}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: e.pts > 0 ? AppColors.green : AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReveal() {
    final LanRevealEntry? me = _c.myReveal;
    final bool ok = me?.ok ?? false;
    final bool noAnswer = (me?.pick ?? -1) == -1;
    final Color color = ok ? AppColors.green : AppColors.wrong;

    String title;
    if (me == null) {
      title = 'Kết quả câu này';
    } else if (ok) {
      title = 'Chính xác! +${me.pts} điểm';
    } else if (noAnswer) {
      title = 'Hết giờ, không được điểm';
    } else {
      title = 'Chưa đúng';
    }
    String detail = '';
    if (me != null && ok && me.bonus > 0) {
      detail = 'Có thưởng chuỗi +${me.bonus} điểm. ';
    }
    final bool validIndex = _c.correctIndex >= 0 && _c.correctIndex < _c.qOptions.length;
    final String right = validIndex ? _c.qOptions[_c.correctIndex] : '';

    final List<Widget> children = <Widget>[
      Panel(
        borderColor: color,
        borderWidth: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: serif(size: 20, weight: FontWeight.w900, color: color)),
            const SizedBox(height: 4),
            Text(
              '$detail${right.isEmpty ? '' : 'Đáp án đúng: $right'}',
              style: const TextStyle(fontSize: 15, height: 1.4, color: AppColors.ink),
            ),
            if (_c.explain.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'Giải thích: ${_c.explain}',
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
    ];

    if (_c.roundEnded) {
      final bool passed = me?.roundPass ?? false;
      final String text;
      if (passed && _c.qLevel < 2) {
        text = 'Bạn đã đạt ${kRoundNames[_c.qLevel]}, được vào ${kRoundNames[_c.qLevel + 1]}.';
      } else if (passed) {
        text = 'Bạn đủ điều kiện xét bảng vàng. Chờ công bố!';
      } else {
        text = 'Bạn dừng bước ở ${kRoundNames[_c.qLevel]} '
            '(cần đúng từ ${kLanPassMark[_c.qLevel]}/$kLanPerRound câu). '
            'Bạn vẫn thi tiếp cho vui, nhưng danh hiệu chỉ tính tới kỳ này.';
      }
      children.add(const SizedBox(height: 12));
      children.add(
        Panel(
          borderColor: passed ? AppColors.green : AppColors.wrong,
          child: Column(
            children: <Widget>[
              Text(
                'Kết thúc ${kRoundNames[_c.qLevel]}',
                style: serif(size: 18, weight: FontWeight.w900, color: AppColors.red),
              ),
              const SizedBox(height: 4),
              Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    children.add(const SizedBox(height: 12));
    children.add(
      Panel(
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Bảng xếp hạng sau câu ${_c.qIndex + 1}/${_c.qTotal}',
              textAlign: TextAlign.center,
              style: serif(size: 17, weight: FontWeight.w900, color: AppColors.red),
            ),
            const SizedBox(height: 8),
            ..._c.reveal.map(_boardRow),
          ],
        ),
      ),
    );

    final int secs = (_c.revealRemainingMs / 1000).ceil();
    String footer;
    if (_c.nextLevel < 0) {
      footer = 'Công bố bảng vàng sau $secs giây';
    } else if (_c.nextLevel != _c.qLevel) {
      footer = 'Sắp bước vào ${kRoundNames[_c.nextLevel]} (${kLevelNames[_c.nextLevel]}) sau $secs giây';
    } else {
      footer = 'Câu tiếp theo sau $secs giây';
    }
    children.add(const SizedBox(height: 12));
    children.add(
      Text(
        footer,
        textAlign: TextAlign.center,
        style: serif(size: 16, weight: FontWeight.w800, color: AppColors.goldDark),
      ),
    );
    return _scroll(children);
  }

  // ------------------------------------------------------------
  //  Bảng vàng cuối khoa
  // ------------------------------------------------------------

  Color _titleColor(LanTitle t) {
    if (t.index >= LanTitle.thamHoa.index) {
      return AppColors.red;
    }
    if (t == LanTitle.hoangGiap) {
      return AppColors.goldDark;
    }
    if (t == LanTitle.none) {
      return AppColors.inkSoft;
    }
    return AppColors.green;
  }

  Widget _finalRow(LanFinalEntry e) {
    final bool me = e.id == _c.myId;
    final Color tc = _titleColor(e.title);
    final String detail = 'Hương ${e.correct.isNotEmpty ? e.correct[0] : 0}/$kLanPerRound'
        '  ·  Hội ${e.correct.length > 1 ? e.correct[1] : 0}/$kLanPerRound'
        '  ·  Đình ${e.correct.length > 2 ? e.correct[2] : 0}/$kLanPerRound';
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: me ? const Color(0xFFF6E3B4) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: me ? Border.all(color: AppColors.gold, width: 1.2) : null,
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 26,
            child: Text(
              '${e.rank}',
              textAlign: TextAlign.center,
              style: serif(size: 16, weight: FontWeight.w900, color: tc),
            ),
          ),
          const SizedBox(width: 4),
          CompetitorAvatar(who: _who(e.id, e.name), size: 34),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  me ? '${e.name} (bạn)' : e.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: me ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                Text(
                  lanTitleLabel(e.title),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: tc),
                ),
                Text(
                  detail,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
          Text(
            '${e.total}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildFinal() {
    final LanFinalEntry? me = _c.myFinal;
    final List<Widget> children = <Widget>[];

    if (me != null) {
      final Color tc = _titleColor(me.title);
      String headline;
      if (me.title == LanTitle.none) {
        headline = 'Dừng bước ở Hương thí';
      } else {
        headline = lanTitleLabel(me.title);
      }
      children.add(
        Panel(
          borderColor: tc,
          borderWidth: 2.4,
          child: Column(
            children: <Widget>[
              Text(
                headline.toUpperCase(),
                textAlign: TextAlign.center,
                style: serif(size: 30, weight: FontWeight.w900, color: tc),
              ),
              const SizedBox(height: 4),
              Text(
                me.name,
                textAlign: TextAlign.center,
                style: serif(size: 17, color: AppColors.inkSoft),
              ),
              const SizedBox(height: 4),
              Text(
                'Hạng ${me.rank}/${_c.finalBoard.length}  ·  ${me.total} điểm',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14.5, color: AppColors.inkSoft),
              ),
            ],
          ),
        ),
      );
      if (_finalMsg.isNotEmpty) {
        children.add(const SizedBox(height: 12));
        children.add(
          Panel(
            child: Text(
              _finalMsg,
              textAlign: TextAlign.center,
              style: serif(
                size: 17,
                weight: FontWeight.w500,
                height: 1.5,
                style: FontStyle.italic,
              ),
            ),
          ),
        );
      }
    }

    if (_noWinnerMsg.isNotEmpty) {
      children.add(const SizedBox(height: 12));
      children.add(
        Panel(
          borderColor: AppColors.inkSoft,
          child: Text(
            _noWinnerMsg,
            textAlign: TextAlign.center,
            style: serif(
              size: 16,
              weight: FontWeight.w500,
              height: 1.5,
              style: FontStyle.italic,
              color: AppColors.inkSoft,
            ),
          ),
        ),
      );
    }

    children.add(const SizedBox(height: 12));
    children.add(
      Panel(
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Bảng vàng khoa thi',
              textAlign: TextAlign.center,
              style: serif(size: 18, weight: FontWeight.w900, color: AppColors.red),
            ),
            const SizedBox(height: 8),
            ..._c.finalBoard.map(_finalRow),
          ],
        ),
      ),
    );
    children.add(const SizedBox(height: 16));
    children.add(PrimaryButton(label: 'Rời phòng', onPressed: _leave));
    return _scroll(children);
  }

  // ------------------------------------------------------------
  //  Mất kết nối hoặc phòng đóng
  // ------------------------------------------------------------

  Widget _buildClosed() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Icon(Icons.wifi_off, size: 48, color: AppColors.wrong),
            const SizedBox(height: 12),
            Text(
              _c.error.isEmpty ? 'Phòng đã đóng.' : _c.error,
              textAlign: TextAlign.center,
              style: serif(size: 18, height: 1.4),
            ),
            const SizedBox(height: 20),
            PrimaryButton(label: 'Quay lại', onPressed: _leave),
          ],
        ),
      ),
    );
  }
}
