import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'lan_rules.dart';

enum LanPhase { connecting, lobby, question, reveal, finished, closed }

class LanMember {
  final int id;
  final String name;
  final bool isHost;
  final bool online;

  const LanMember({
    required this.id,
    required this.name,
    required this.isHost,
    required this.online,
  });
}

/// Một dòng trên bảng xếp hạng sau mỗi câu.
class LanRevealEntry {
  final int id;
  final String name;
  final bool online;
  final int pick; // -1 nếu không đáp
  final bool ok;
  final int pts; // điểm câu này (đã gồm thưởng chuỗi)
  final int bonus;
  final int streak;
  final int total;
  final int rank;
  final int prev; // hạng trước câu này
  final bool? roundPass; // chỉ có khi vừa hết một kỳ: đạt hay dừng bước

  const LanRevealEntry({
    required this.id,
    required this.name,
    required this.online,
    required this.pick,
    required this.ok,
    required this.pts,
    required this.bonus,
    required this.streak,
    required this.total,
    required this.rank,
    required this.prev,
    required this.roundPass,
  });

  /// > 0 lên hạng, < 0 xuống hạng.
  int get change => prev - rank;
}

/// Một dòng trên bảng vàng cuối khoa.
class LanFinalEntry {
  final int id;
  final String name;
  final bool online;
  final int total;
  final List<int> correct; // số câu đúng ở ba kỳ
  final List<int> scores; // điểm ba kỳ
  final LanTitle title;
  final int rank;

  const LanFinalEntry({
    required this.id,
    required this.name,
    required this.online,
    required this.total,
    required this.correct,
    required this.scores,
    required this.title,
    required this.rank,
  });
}

int _asInt(dynamic v, [int fallback = 0]) => v is num ? v.toInt() : fallback;

/// Phía người chơi: nối vào máy chủ phòng, nhận tin và giữ trạng thái cho giao diện.
class LanClient extends ChangeNotifier {
  WebSocket? _ws;
  Completer<bool>? _joined;
  bool _disposed = false;

  LanPhase phase = LanPhase.connecting;
  String error = '';

  int myId = -1;
  bool isHost = false;
  String room = '';
  bool startingSoon = false;
  List<LanMember> members = <LanMember>[];

  // câu hỏi đang diễn ra
  int qIndex = 0;
  int qTotal = 0;
  int qLevel = 0;
  String qTopic = '';
  String qText = '';
  List<String> qOptions = <String>[];
  int qDurationMs = 30000;
  int myPick = -1;
  int answeredCount = 0;
  int onlineCount = 0;
  final Stopwatch _qWatch = Stopwatch();

  // xem đáp án
  int correctIndex = -1;
  String explain = '';
  List<LanRevealEntry> reveal = <LanRevealEntry>[];
  int nextLevel = -1;
  bool roundEnded = false;
  int revealMs = 0;
  final Stopwatch _revealWatch = Stopwatch();

  // bảng vàng cuối khoa
  List<LanFinalEntry> finalBoard = <LanFinalEntry>[];

  /// Số mili-giây còn lại ở câu hiện tại (theo đồng hồ máy này kể từ lúc nhận câu hỏi).
  int get remainingMs => max(0, qDurationMs - _qWatch.elapsedMilliseconds);

  /// Số mili-giây còn lại trước khi sang câu tiếp theo.
  int get revealRemainingMs => max(0, revealMs - _revealWatch.elapsedMilliseconds);

  /// Đã chốt đáp án ở câu hiện tại hay chưa.
  bool get hasAnswered => myPick != -1;

  LanRevealEntry? get myReveal {
    for (final LanRevealEntry e in reveal) {
      if (e.id == myId) {
        return e;
      }
    }
    return null;
  }

  LanFinalEntry? get myFinal {
    for (final LanFinalEntry e in finalBoard) {
      if (e.id == myId) {
        return e;
      }
    }
    return null;
  }

  /// Nối vào phòng. Trả về true khi được chủ phòng cho vào.
  Future<bool> connect(String host, int port, String name) async {
    final Completer<bool> joined = Completer<bool>();
    _joined = joined;
    try {
      final WebSocket ws = await WebSocket
          .connect('ws://$host:$port')
          .timeout(const Duration(seconds: 6));
      _ws = ws;
      ws.listen(
        _onData,
        onDone: _onDone,
        onError: (Object e) => _onDone(),
        cancelOnError: true,
      );
      _send(<String, dynamic>{'t': 'join', 'name': name});
    } catch (_) {
      _fail('Không nối được tới phòng ($host). Hãy kiểm tra cùng một wifi rồi thử lại.');
      return false;
    }
    return joined.future.timeout(
      const Duration(seconds: 6),
      onTimeout: () {
        _fail('Chủ phòng không trả lời. Hãy thử lại.');
        return false;
      },
    );
  }

  void _send(Map<String, dynamic> msg) {
    try {
      _ws?.add(jsonEncode(msg));
    } catch (_) {
      // mất kết nối, _onDone sẽ xử lý
    }
  }

  /// Chủ phòng bấm bắt đầu thi.
  void startGame() {
    if (isHost) {
      _send(<String, dynamic>{'t': 'start'});
    }
  }

  /// Chọn đáp án [choice] (0 đến 3) cho câu hiện tại.
  void sendAnswer(int choice) {
    if (phase != LanPhase.question || myPick != -1) {
      return;
    }
    myPick = choice;
    _send(<String, dynamic>{'t': 'a', 'i': qIndex, 'c': choice});
    _notify();
  }

  void _fail(String msg) {
    error = msg;
    phase = LanPhase.closed;
    final Completer<bool>? j = _joined;
    if (j != null && !j.isCompleted) {
      j.complete(false);
    }
    _closeSocket();
    _notify();
  }

  void _onDone() {
    if (phase != LanPhase.finished && phase != LanPhase.closed) {
      _fail('Mất kết nối với chủ phòng.');
    }
  }

  void _closeSocket() {
    final WebSocket? ws = _ws;
    _ws = null;
    try {
      ws?.close();
    } catch (_) {
      // bỏ qua
    }
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  void _onData(dynamic raw) {
    if (raw is! String) {
      return;
    }
    Map<String, dynamic> m;
    try {
      m = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    switch ((m['t'] as String?) ?? '') {
      case 'welcome':
        myId = _asInt(m['id'], -1);
        isHost = (m['host'] as bool?) ?? false;
        room = (m['room'] as String?) ?? '';
        phase = LanPhase.lobby;
        final Completer<bool>? j = _joined;
        if (j != null && !j.isCompleted) {
          j.complete(true);
        }
        break;
      case 'error':
        _fail((m['msg'] as String?) ?? 'Có lỗi xảy ra.');
        return;
      case 'lobby':
        room = (m['room'] as String?) ?? room;
        members = ((m['players'] as List<dynamic>?) ?? <dynamic>[])
            .map((dynamic e) {
          final Map<String, dynamic> p = e as Map<String, dynamic>;
          return LanMember(
            id: _asInt(p['id']),
            name: (p['name'] as String?) ?? '',
            isHost: (p['host'] as bool?) ?? false,
            online: (p['on'] as bool?) ?? true,
          );
        }).toList();
        break;
      case 'start':
        startingSoon = true;
        qTotal = _asInt(m['total']);
        break;
      case 'q':
        qIndex = _asInt(m['i']);
        qTotal = _asInt(m['n']);
        qLevel = _asInt(m['lv']);
        qTopic = (m['topic'] as String?) ?? '';
        qText = (m['text'] as String?) ?? '';
        qOptions = List<String>.from((m['opts'] as List<dynamic>?) ?? <dynamic>[]);
        qDurationMs = _asInt(m['ms'], 30000);
        myPick = -1;
        answeredCount = 0;
        _qWatch
          ..reset()
          ..start();
        phase = LanPhase.question;
        break;
      case 'prog':
        answeredCount = _asInt(m['a']);
        onlineCount = _asInt(m['n']);
        break;
      case 'r':
        correctIndex = _asInt(m['ans'], -1);
        explain = (m['explain'] as String?) ?? '';
        nextLevel = _asInt(m['nx'], -1);
        roundEnded = (m['end'] as bool?) ?? false;
        revealMs = _asInt(m['ms'], 7000);
        reveal = ((m['e'] as List<dynamic>?) ?? <dynamic>[]).map((dynamic e) {
          final Map<String, dynamic> p = e as Map<String, dynamic>;
          return LanRevealEntry(
            id: _asInt(p['id']),
            name: (p['name'] as String?) ?? '',
            online: (p['on'] as bool?) ?? true,
            pick: _asInt(p['pick'], -1),
            ok: (p['ok'] as bool?) ?? false,
            pts: _asInt(p['pts']),
            bonus: _asInt(p['bonus']),
            streak: _asInt(p['streak']),
            total: _asInt(p['total']),
            rank: _asInt(p['rank']),
            prev: _asInt(p['prev'], _asInt(p['rank'])),
            roundPass: p['rp'] as bool?,
          );
        }).toList();
        _revealWatch
          ..reset()
          ..start();
        phase = LanPhase.reveal;
        break;
      case 'final':
        finalBoard = ((m['e'] as List<dynamic>?) ?? <dynamic>[]).map((dynamic e) {
          final Map<String, dynamic> p = e as Map<String, dynamic>;
          return LanFinalEntry(
            id: _asInt(p['id']),
            name: (p['name'] as String?) ?? '',
            online: (p['on'] as bool?) ?? true,
            total: _asInt(p['total']),
            correct: List<dynamic>.from((p['c'] as List<dynamic>?) ?? <dynamic>[])
                .map((dynamic v) => _asInt(v))
                .toList(),
            scores: List<dynamic>.from((p['s'] as List<dynamic>?) ?? <dynamic>[])
                .map((dynamic v) => _asInt(v))
                .toList(),
            title: lanTitleFromName(p['title'] as String?),
            rank: _asInt(p['rank']),
          );
        }).toList();
        phase = LanPhase.finished;
        break;
      default:
        return;
    }
    _notify();
  }

  /// Rời phòng và dọn dẹp.
  void leave() {
    _send(<String, dynamic>{'t': 'leave'});
    if (phase != LanPhase.finished) {
      phase = LanPhase.closed;
    }
    _closeSocket();
  }

  @override
  void dispose() {
    _disposed = true;
    leave();
    super.dispose();
  }
}
