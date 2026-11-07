import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data.dart';
import '../lan/lan_client.dart';
import '../lan/lan_host.dart';
import '../lan/lan_net.dart';
import '../lan/lan_rules.dart';
import '../theme.dart';
import '../widgets.dart';
import 'lan_room_screen.dart';

/// Lối vào "So tài": Tạo phòng hoặc Tìm phòng bằng mã số (giống chọn phòng trong game online).
class LanMenuScreen extends StatefulWidget {
  final GameData data;
  final String playerName;

  const LanMenuScreen({super.key, required this.data, required this.playerName});

  @override
  State<LanMenuScreen> createState() => _LanMenuScreenState();
}

class _LanMenuScreenState extends State<LanMenuScreen> {
  final TextEditingController _code = TextEditingController();
  final TextEditingController _ip = TextEditingController();
  bool _busy = false;
  bool _showIp = false;
  String _status = '';

  @override
  void dispose() {
    _code.dispose();
    _ip.dispose();
    super.dispose();
  }

  void _setStatus(String text, {bool busy = false}) {
    if (!mounted) {
      return;
    }
    setState(() {
      _status = text;
      _busy = busy;
    });
  }

  Future<void> _openRoom(LanClient client, LanHost? host) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => LanRoomScreen(
          client: client,
          host: host,
          data: widget.data,
        ),
      ),
    );
  }

  Future<void> _create() async {
    if (_busy) {
      return;
    }
    _setStatus('Đang mở phòng...', busy: true);
    final LanHost host = LanHost(widget.data);
    final LanClient client = LanClient();
    String problem = '';
    try {
      await host.start();
      final bool ok = await client.connect(
        '127.0.0.1',
        host.port,
        widget.playerName,
      );
      if (!ok) {
        problem = client.error;
      }
    } catch (e) {
      problem = 'Không mở được phòng. Hãy bật wifi rồi thử lại.';
    }
    if (problem.isNotEmpty || !mounted) {
      client.dispose();
      await host.close();
      _setStatus(problem);
      return;
    }
    _setStatus('');
    await _openRoom(client, host);
  }

  Future<void> _find() async {
    if (_busy) {
      return;
    }
    final String code = _code.text.trim();
    if (code.length != 4) {
      _setStatus('Hãy nhập mã phòng gồm 4 chữ số.');
      return;
    }
    _setStatus('Đang tìm phòng $code trong wifi...', busy: true);
    final LanRoomInfo? info = await findLanRoom(code);
    if (!mounted) {
      return;
    }
    if (info == null) {
      setState(() {
        _busy = false;
        _showIp = true;
        _status = 'Không thấy phòng $code. Hãy kiểm tra cả nhóm cùng một wifi, '
            'hoặc nhập địa chỉ IP của chủ phòng ở bên dưới.';
      });
      return;
    }
    if (info.started) {
      _setStatus('Phòng $code đã bắt đầu thi, không vào thêm được.');
      return;
    }
    await _joinAt(info.host, info.port);
  }

  Future<void> _joinByIp() async {
    if (_busy) {
      return;
    }
    final String text = _ip.text.trim();
    final List<String> parts = text.split(':');
    final String host = parts[0].trim();
    final int port = parts.length > 1 ? (int.tryParse(parts[1].trim()) ?? kLanPort) : kLanPort;
    final bool valid = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(host);
    if (!valid) {
      _setStatus('Địa chỉ IP chưa đúng, ví dụ 192.168.1.5');
      return;
    }
    _setStatus('Đang vào phòng...', busy: true);
    await _joinAt(host, port);
  }

  Future<void> _joinAt(String host, int port) async {
    _setStatus('Đang vào phòng...', busy: true);
    final LanClient client = LanClient();
    final bool ok = await client.connect(host, port, widget.playerName);
    if (!mounted) {
      client.dispose();
      return;
    }
    if (!ok) {
      final String msg = client.error;
      client.dispose();
      _setStatus(msg);
      return;
    }
    _setStatus('');
    await _openRoom(client, null);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = <Widget>[
      const Icon(Icons.wifi, size: 48, color: AppColors.gold),
      const SizedBox(height: 6),
      Text(
        'SO TÀI',
        textAlign: TextAlign.center,
        style: serif(size: 34, weight: FontWeight.w900, color: AppColors.red),
      ),
      const SizedBox(height: 4),
      Text(
        'Tối đa $kLanMaxPlayers sĩ tử, $kLanPerRound câu mỗi kỳ, tổng ${kLanPerRound * 3} câu',
        textAlign: TextAlign.center,
        style: serif(size: 14, color: AppColors.inkSoft),
      ),
      const SizedBox(height: 16),
      const Panel(
        child: Text(
          'Tất cả vào cùng một wifi (hoặc cùng một điểm phát wifi). '
          'Một người bấm Tạo phòng rồi đọc mã số cho mọi người. '
          'Những người còn lại nhập mã đó và bấm Tìm phòng.',
          style: TextStyle(fontSize: 15, height: 1.4),
        ),
      ),
      const SizedBox(height: 16),
      PrimaryButton(
        label: 'Tạo phòng',
        icon: Icons.add_circle_outline,
        onPressed: _busy ? null : _create,
      ),
      const SizedBox(height: 20),
      TextField(
        controller: _code,
        enabled: !_busy,
        maxLength: 4,
        keyboardType: TextInputType.number,
        inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        style: serif(size: 28, weight: FontWeight.w800, letterSpacing: 6),
        decoration: const InputDecoration(
          labelText: 'Mã phòng (4 chữ số)',
          border: OutlineInputBorder(),
          counterText: '',
          filled: true,
          fillColor: AppColors.card,
        ),
      ),
      const SizedBox(height: 10),
      SecondaryButton(label: 'Tìm phòng', onPressed: _busy ? null : _find),
    ];

    if (_busy) {
      children.add(const SizedBox(height: 14));
      children.add(
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: const LinearProgressIndicator(minHeight: 8),
        ),
      );
    }
    if (_status.isNotEmpty) {
      children.add(const SizedBox(height: 12));
      children.add(
        Text(
          _status,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14.5, height: 1.35, color: AppColors.wrong),
        ),
      );
    }

    children.add(const SizedBox(height: 8));
    children.add(
      TextButton(
        onPressed: () => setState(() => _showIp = !_showIp),
        child: Text(_showIp ? 'Ẩn ô nhập địa chỉ IP' : 'Không tìm thấy phòng? Nhập địa chỉ IP'),
      ),
    );
    if (_showIp) {
      children.add(
        TextField(
          controller: _ip,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
            labelText: 'IP của chủ phòng, ví dụ 192.168.1.5',
            border: OutlineInputBorder(),
            filled: true,
            fillColor: AppColors.card,
          ),
        ),
      );
      children.add(const SizedBox(height: 10));
      children.add(
        SecondaryButton(label: 'Vào bằng địa chỉ IP', onPressed: _busy ? null : _joinByIp),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('So tài'),
        backgroundColor: AppColors.paper,
        foregroundColor: AppColors.red,
        elevation: 0,
      ),
      body: SafeArea(child: PageScroll(children: children)),
    );
  }
}
