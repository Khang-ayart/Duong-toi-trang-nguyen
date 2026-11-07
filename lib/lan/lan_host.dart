import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../data.dart';
import '../engine.dart';
import '../models.dart';
import 'lan_net.dart';
import 'lan_rules.dart';

class _HostPlayer {
  final int id;
  final bool isHost;
  String name;
  WebSocket? ws;
  bool connected = true;

  final List<RoundTally> rounds = <RoundTally>[
    RoundTally(),
    RoundTally(),
    RoundTally(),
  ];

  bool answered = false;
  int pick = -1;
  int answerKhac = 0;

  _HostPlayer({
    required this.id,
    required this.name,
    required this.isHost,
    required this.ws,
  });

  LanPlayerScore get score => LanPlayerScore(id, rounds);
}

/// Máy chủ phòng thi, chạy ngay trên điện thoại của chủ phòng.
/// Chủ phòng cũng chơi như mọi người: màn hình của chủ phòng nối vào chính máy chủ này
/// qua địa chỉ 127.0.0.1, nên chủ phòng và người chơi dùng chung một đường xử lý.
/// Máy chủ giữ đồng hồ chuẩn và tính điểm theo lúc nhận được đáp án.
class LanHost {
  final GameData data;
  final Random _rnd = Random();

  HttpServer? _server;
  LanAnnouncer? _announcer;
  final Map<int, _HostPlayer> _players = <int, _HostPlayer>{};
  int _nextId = 1;

  String roomCode = '';
  int port = 0;
  bool _started = false;
  bool _closed = false;

  // câu hỏi đang diễn ra
  int _curIndex = -1;
  bool _accepting = false;
  final Stopwatch _qWatch = Stopwatch();

  LanHost(this.data);

  bool get started => _started;

  /// Mở cổng, sinh mã phòng và bắt đầu phát tín hiệu cho cả wifi.
  Future<void> start() async {
    HttpServer? server;
    for (int p = kLanPort; p < kLanPort + 10; p++) {
      try {
        server = await HttpServer.bind(InternetAddress.anyIPv4, p);
        port = p;
        break;
      } catch (_) {
        // cổng bận, thử cổng kế tiếp
      }
    }
    if (server == null) {
      throw const SocketException('Không mở được cổng mạng để tạo phòng.');
    }
    _server = server;
    roomCode = (1000 + _rnd.nextInt(9000)).toString();
    server.listen(_onRequest, onError: (Object e) {});

    final LanAnnouncer announcer = LanAnnouncer();
    _announcer = announcer;
    try {
      await announcer.start(_announcePayload);
    } catch (_) {
      // không phát được tín hiệu thì người chơi vẫn nối được bằng địa chỉ IP
    }
  }

  String _announcePayload() {
    return jsonEncode(<String, dynamic>{
      'app': kLanApp,
      'room': roomCode,
      'port': port,
      'host': _hostName(),
      'players': _players.values.where((_HostPlayer p) => p.connected).length,
      'max': kLanMaxPlayers,
      'started': _started,
    });
  }

  String _hostName() {
    for (final _HostPlayer p in _players.values) {
      if (p.isHost) {
        return p.name;
      }
    }
    return '';
  }

  // ---------- Kết nối ----------

  Future<void> _onRequest(HttpRequest req) async {
    if (!WebSocketTransformer.isUpgradeRequest(req)) {
      req.response.statusCode = HttpStatus.notFound;
      await req.response.close();
      return;
    }
    final bool local = req.connectionInfo?.remoteAddress.isLoopback ?? false;
    try {
      final WebSocket ws = await WebSocketTransformer.upgrade(req);
      ws.pingInterval = const Duration(seconds: 5);
      _handleSocket(ws, local);
    } catch (_) {
      // kết nối hỏng giữa chừng thì bỏ qua
    }
  }

  void _handleSocket(WebSocket ws, bool local) {
    _HostPlayer? me;
    ws.listen(
      (dynamic raw) {
        if (raw is! String || raw.length > 4000) {
          return;
        }
        Map<String, dynamic> m;
        try {
          m = jsonDecode(raw) as Map<String, dynamic>;
        } catch (_) {
          return;
        }
        final String t = (m['t'] as String?) ?? '';
        final _HostPlayer? cur = me;
        if (cur == null) {
          if (t == 'join') {
            me = _join(ws, m, local);
          }
          return;
        }
        _onMessage(cur, t, m);
      },
      onDone: () {
        final _HostPlayer? cur = me;
        if (cur != null) {
          _onLeave(cur);
        }
      },
      onError: (Object e) {
        final _HostPlayer? cur = me;
        if (cur != null) {
          _onLeave(cur);
        }
      },
      cancelOnError: true,
    );
  }

  _HostPlayer? _join(WebSocket ws, Map<String, dynamic> m, bool local) {
    if (_started) {
      _sendTo(ws, <String, dynamic>{
        't': 'error',
        'msg': 'Phòng đã bắt đầu thi, không vào thêm được.',
      });
      ws.close();
      return null;
    }
    final int online = _players.values.where((_HostPlayer p) => p.connected).length;
    if (online >= kLanMaxPlayers) {
      _sendTo(ws, <String, dynamic>{
        't': 'error',
        'msg': 'Phòng đã đủ $kLanMaxPlayers người.',
      });
      ws.close();
      return null;
    }

    String name = ((m['name'] as String?) ?? '').trim();
    if (name.isEmpty) {
      name = 'Sĩ tử';
    }
    if (name.length > 18) {
      name = name.substring(0, 18);
    }
    final String base = name;
    int suffix = 2;
    while (_players.values.any((_HostPlayer p) => p.name == name)) {
      name = '$base ($suffix)';
      suffix++;
    }

    final bool hasHost = _players.values.any((_HostPlayer p) => p.isHost);
    final _HostPlayer p = _HostPlayer(
      id: _nextId,
      name: name,
      isHost: local && !hasHost,
      ws: ws,
    );
    _nextId++;
    _players[p.id] = p;

    _sendTo(ws, <String, dynamic>{
      't': 'welcome',
      'id': p.id,
      'room': roomCode,
      'host': p.isHost,
    });
    _broadcastLobby();
    return p;
  }

  void _onMessage(_HostPlayer p, String t, Map<String, dynamic> m) {
    switch (t) {
      case 'start':
        if (p.isHost && !_started) {
          _runGame();
        }
        break;
      case 'a':
        _onAnswer(p, m);
        break;
      case 'leave':
        p.ws?.close();
        break;
      default:
        break;
    }
  }

  void _onLeave(_HostPlayer p) {
    p.connected = false;
    p.ws = null;
    if (!_started) {
      _players.remove(p.id);
    }
    _broadcastLobby();
    if (_started) {
      _broadcastProgress();
    }
  }

  // ---------- Gửi tin ----------

  void _sendTo(WebSocket ws, Map<String, dynamic> msg) {
    try {
      ws.add(jsonEncode(msg));
    } catch (_) {
      // máy nhận đã rớt mạng, bỏ qua
    }
  }

  void _broadcast(Map<String, dynamic> msg) {
    final String text = jsonEncode(msg);
    for (final _HostPlayer p in _players.values) {
      final WebSocket? ws = p.ws;
      if (p.connected && ws != null) {
        try {
          ws.add(text);
        } catch (_) {
          // bỏ qua
        }
      }
    }
  }

  void _broadcastLobby() {
    _broadcast(<String, dynamic>{
      't': 'lobby',
      'room': roomCode,
      'players': _players.values
          .map(
            (_HostPlayer p) => <String, dynamic>{
              'id': p.id,
              'name': p.name,
              'host': p.isHost,
              'on': p.connected,
            },
          )
          .toList(),
    });
  }

  void _broadcastProgress() {
    final List<_HostPlayer> online =
        _players.values.where((_HostPlayer p) => p.connected).toList();
    _broadcast(<String, dynamic>{
      't': 'prog',
      'a': online.where((_HostPlayer p) => p.answered).length,
      'n': online.length,
    });
  }

  // ---------- Diễn biến khoa thi ----------

  /// Bốc ngẫu nhiên 10 câu mỗi cấp, theo thứ tự dễ, trung bình, khó.
  List<PlayQuestion> _pickQuestions() {
    final List<PlayQuestion> out = <PlayQuestion>[];
    for (int lv = 0; lv < 3; lv++) {
      final List<Question> pool = List<Question>.of(data.byLevel[lv]);
      pool.shuffle(_rnd);
      final int n = min(kLanPerRound, pool.length);
      for (int i = 0; i < n; i++) {
        out.add(PlayQuestion.from(pool[i], _rnd));
      }
    }
    return out;
  }

  Future<void> _runGame() async {
    _started = true;
    _announcer?.stop();
    final List<PlayQuestion> qs = _pickQuestions();
    _broadcast(<String, dynamic>{'t': 'start', 'total': qs.length});
    await Future<void>.delayed(const Duration(milliseconds: 3000));

    for (int i = 0; i < qs.length; i++) {
      if (_closed || _noOneOnline()) {
        return;
      }
      await _ask(i, qs);
      if (_closed) {
        return;
      }
      await _reveal(i, qs);
    }
    if (!_closed) {
      _finish();
    }
  }

  bool _noOneOnline() {
    return !_players.values.any((_HostPlayer p) => p.connected);
  }

  Future<void> _wait(int maxMs, bool Function() done) async {
    final Stopwatch w = Stopwatch()..start();
    while (!_closed && w.elapsedMilliseconds < maxMs && !done()) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  bool _allAnswered() {
    return _players.values
        .where((_HostPlayer p) => p.connected)
        .every((_HostPlayer p) => p.answered);
  }

  Future<void> _ask(int i, List<PlayQuestion> qs) async {
    final PlayQuestion pq = qs[i];
    for (final _HostPlayer p in _players.values) {
      p.answered = false;
      p.pick = -1;
      p.answerKhac = 0;
    }
    _curIndex = i;
    _accepting = true;
    _qWatch
      ..reset()
      ..start();
    _broadcast(<String, dynamic>{
      't': 'q',
      'i': i,
      'n': qs.length,
      'lv': pq.source.level,
      'topic': pq.topic,
      'text': pq.text,
      'opts': pq.options,
      'ms': kTimeLimitKhac * 10,
    });
    _broadcastProgress();

    // chờ tới khi ai cũng đã đáp, hoặc hết 30 giây (cộng 0,6 giây bù độ trễ mạng)
    await _wait(kTimeLimitKhac * 10 + 600, _allAnswered);
    if (_allAnswered() && _qWatch.elapsedMilliseconds < kTimeLimitKhac * 10) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    _accepting = false;
  }

  void _onAnswer(_HostPlayer p, Map<String, dynamic> m) {
    if (!_accepting || p.answered || !p.connected) {
      return;
    }
    final int? idx = (m['i'] as num?)?.toInt();
    if (idx != _curIndex) {
      return;
    }
    final int choice = (m['c'] as num?)?.toInt() ?? -1;
    final int khac = _qWatch.elapsedMilliseconds ~/ 10;
    p.answered = true;
    p.pick = choice;
    p.answerKhac = min(khac, kTimeLimitKhac - 1);
    _broadcastProgress();
  }

  List<_HostPlayer> _rankedPlayers() {
    final List<_HostPlayer> list = _players.values.toList();
    list.sort((_HostPlayer a, _HostPlayer b) => compareByTotal(a.score, b.score));
    return list;
  }

  Future<void> _reveal(int i, List<PlayQuestion> qs) async {
    final PlayQuestion pq = qs[i];
    final int round = pq.source.level;
    final int nextLevel = i + 1 < qs.length ? qs[i + 1].source.level : -1;
    final bool roundEnded = nextLevel != round;

    final Map<int, int> prevRank = <int, int>{};
    final List<_HostPlayer> before = _rankedPlayers();
    for (int k = 0; k < before.length; k++) {
      prevRank[before[k].id] = k + 1;
    }

    final Map<int, AnswerRecord> records = <int, AnswerRecord>{};
    for (final _HostPlayer p in _players.values) {
      final bool correct = p.answered && p.pick == pq.correctIndex;
      records[p.id] = p.rounds[round].add(
        isCorrect: correct,
        khac: p.answered ? p.answerKhac : kTimeLimitKhac,
      );
    }

    final List<_HostPlayer> after = _rankedPlayers();
    final List<Map<String, dynamic>> entries = <Map<String, dynamic>>[];
    for (int k = 0; k < after.length; k++) {
      final _HostPlayer p = after[k];
      final AnswerRecord rec = records[p.id]!;
      entries.add(<String, dynamic>{
        'id': p.id,
        'name': p.name,
        'on': p.connected,
        'pick': p.answered ? p.pick : -1,
        'ok': rec.correct,
        'pts': rec.points,
        'bonus': rec.bonus,
        'streak': rec.streakAfter,
        'total': p.score.total,
        'rank': k + 1,
        'prev': prevRank[p.id] ?? (k + 1),
        'rp': roundEnded ? p.score.chainPassed(round) : null,
      });
    }

    int waitMs = kLanRevealMs;
    if (i + 1 >= qs.length) {
      waitMs = kLanLastRevealMs;
    } else if (roundEnded) {
      waitMs = kLanRoundBreakMs;
    }

    _broadcast(<String, dynamic>{
      't': 'r',
      'i': i,
      'ans': pq.correctIndex,
      'explain': pq.explain,
      'e': entries,
      'ms': waitMs,
      'nx': nextLevel,
      'end': roundEnded,
    });
    await _wait(waitMs, () => false);
  }

  void _finish() {
    final List<LanPlayerScore> all =
        _players.values.map((_HostPlayer p) => p.score).toList();
    final Map<int, LanTitle> titles = decideTitles(all);
    final List<LanPlayerScore> ordered = orderFinal(all, titles);
    final Map<int, _HostPlayer> byId = _players;
    final List<Map<String, dynamic>> entries = <Map<String, dynamic>>[];
    for (int k = 0; k < ordered.length; k++) {
      final LanPlayerScore s = ordered[k];
      final _HostPlayer p = byId[s.id]!;
      entries.add(<String, dynamic>{
        'id': p.id,
        'name': p.name,
        'on': p.connected,
        'total': s.total,
        'c': s.rounds.map((RoundTally t) => t.correct).toList(),
        's': s.rounds.map((RoundTally t) => t.score).toList(),
        'title': (titles[s.id] ?? LanTitle.none).name,
        'rank': k + 1,
      });
    }
    _broadcast(<String, dynamic>{'t': 'final', 'e': entries});
  }

  /// Đóng phòng: ngắt mọi kết nối, tắt máy chủ và ngừng phát tín hiệu.
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    _announcer?.stop();
    for (final _HostPlayer p in _players.values) {
      try {
        await p.ws?.close();
      } catch (_) {
        // bỏ qua
      }
    }
    try {
      await _server?.close(force: true);
    } catch (_) {
      // bỏ qua
    }
  }
}
