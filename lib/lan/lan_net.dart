import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'lan_rules.dart';

/// Các địa chỉ IPv4 của máy trong mạng (wifi hoặc điểm phát wifi), loại bỏ 127.0.0.1.
/// Địa chỉ dạng 192.168.x.x xếp trước vì thường là wifi nhà hoặc hotspot.
Future<List<String>> localIPv4s() async {
  final List<String> out = <String>[];
  try {
    final List<NetworkInterface> ifs = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    for (final NetworkInterface i in ifs) {
      for (final InternetAddress a in i.addresses) {
        out.add(a.address);
      }
    }
  } catch (_) {
    // không đọc được thì trả danh sách rỗng
  }
  int rank(String ip) {
    if (ip.startsWith('192.168.')) {
      return 0;
    }
    if (ip.startsWith('172.')) {
      return 1;
    }
    if (ip.startsWith('10.')) {
      return 2;
    }
    return 3;
  }

  out.sort((String a, String b) => rank(a).compareTo(rank(b)));
  return out;
}

/// Chủ phòng phát "phòng số X ở đây" mỗi giây cho cả wifi (UDP broadcast).
class LanAnnouncer {
  RawDatagramSocket? _socket;
  Timer? _timer;

  Future<void> start(String Function() payload) async {
    final RawDatagramSocket socket =
        await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;
    _socket = socket;
    await _send(payload());
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      _send(payload());
    });
  }

  Future<void> _send(String text) async {
    final RawDatagramSocket? socket = _socket;
    if (socket == null) {
      return;
    }
    final List<int> data = utf8.encode(text);
    final Set<String> targets = <String>{'255.255.255.255'};
    for (final String ip in await localIPv4s()) {
      final List<String> parts = ip.split('.');
      if (parts.length == 4) {
        targets.add('${parts[0]}.${parts[1]}.${parts[2]}.255');
      }
    }
    for (final String t in targets) {
      try {
        socket.send(data, InternetAddress(t), kLanDiscoveryPort);
      } catch (_) {
        // một đường phát lỗi thì bỏ qua, các đường khác vẫn chạy
      }
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _socket?.close();
    _socket = null;
  }
}

/// Thông tin một phòng tìm thấy trong wifi.
class LanRoomInfo {
  final String code;
  final String host; // địa chỉ IP của chủ phòng
  final int port;
  final String hostName;
  final int players;
  final bool started;

  const LanRoomInfo({
    required this.code,
    required this.host,
    required this.port,
    required this.hostName,
    required this.players,
    required this.started,
  });
}

Future<RawDatagramSocket?> _bindDiscovery() async {
  try {
    return await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      kLanDiscoveryPort,
      reuseAddress: true,
    );
  } catch (_) {
    return null;
  }
}

/// Lắng nghe tín hiệu trong wifi để tìm phòng có mã [code].
/// Trả về null nếu hết [timeout] mà không thấy.
Future<LanRoomInfo?> findLanRoom(
  String code, {
  Duration timeout = const Duration(seconds: 8),
}) async {
  final RawDatagramSocket? socket = await _bindDiscovery();
  if (socket == null) {
    return null;
  }
  final Completer<LanRoomInfo?> done = Completer<LanRoomInfo?>();
  final StreamSubscription<RawSocketEvent> sub =
      socket.listen((RawSocketEvent event) {
    if (event != RawSocketEvent.read) {
      return;
    }
    final Datagram? d = socket.receive();
    if (d == null) {
      return;
    }
    try {
      final Map<String, dynamic> m =
          jsonDecode(utf8.decode(d.data)) as Map<String, dynamic>;
      if (m['app'] == kLanApp && m['room'] == code && !done.isCompleted) {
        done.complete(
          LanRoomInfo(
            code: code,
            host: d.address.address,
            port: (m['port'] as num).toInt(),
            hostName: (m['host'] as String?) ?? '',
            players: (m['players'] as num?)?.toInt() ?? 0,
            started: (m['started'] as bool?) ?? false,
          ),
        );
      }
    } catch (_) {
      // gói tin lạ thì bỏ qua
    }
  });
  final Timer timer = Timer(timeout, () {
    if (!done.isCompleted) {
      done.complete(null);
    }
  });
  final LanRoomInfo? result = await done.future;
  timer.cancel();
  await sub.cancel();
  socket.close();
  return result;
}
