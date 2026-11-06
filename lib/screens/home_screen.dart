import 'package:flutter/material.dart';

import '../data.dart';
import '../engine.dart';
import '../theme.dart';
import '../widgets.dart';
import 'game_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _name = TextEditingController(text: 'Sĩ tử');
  GameData? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final GameData data = await GameData.load();
      if (!mounted) {
        return;
      }
      setState(() => _data = data);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _error = e.toString());
    }
  }

  void _start() {
    final GameData? data = _data;
    if (data == null) {
      return;
    }
    final String typed = _name.text.trim();
    final String name = typed.isEmpty ? 'Sĩ tử' : typed;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            GameScreen(data: data, playerName: name),
      ),
    );
  }

  void _soTai() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('So tài qua wifi LAN sẽ ra mắt ở bản sau. Hiện chưa mở.'),
      ),
    );
  }

  void _showRules() {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Thể lệ khoa thi'),
        content: SingleChildScrollView(
          child: Text(
            'Hương thí: 12 câu dễ. Đúng từ ${kPassMark[0]}/12 trở lên mới được vào Hội thí.\n\n'
            'Hội thí: 12 câu trung bình. Đúng từ ${kPassMark[1]}/12 trở lên mới được vào Đình thí.\n\n'
            'Đình thí: 12 câu khó. Đúng từ ${kPassMark[2]}/12 trở lên mới được xét bảng vàng: '
            'ba người điểm cao nhất là Trạng Nguyên, Bảng Nhãn, Thám Hoa. '
            'Những người còn lại qua Đình thí là Tú Tài. Có khoa không ai đỗ.\n\n'
            'Mỗi câu 30 giây, tối đa 300 điểm. Cứ mỗi 0,1 giây trôi qua trừ 1 điểm, '
            'trả lời càng nhanh điểm càng cao.\n\n'
            'Chuỗi: trả lời đúng liên tiếp, mỗi câu trong vòng 5 giây thì giữ chuỗi. '
            'Từ câu thứ 6 của chuỗi, mỗi câu được cộng thêm 10, 20, 30... điểm. '
            'Sai, hết giờ hoặc chậm quá 5 giây là đứt chuỗi. Sang kỳ mới chuỗi tính lại.\n\n'
            'Cùng dự thi với $kBotCount sĩ tử máy.',
            style: const TextStyle(fontSize: 15, height: 1.4),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đã rõ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool ready = _data != null;
    final String? error = _error;

    final List<Widget> children = <Widget>[
      const Icon(Icons.emoji_events, size: 56, color: AppColors.gold),
      const SizedBox(height: 8),
      Text(
        'ĐƯỜNG TỚI',
        textAlign: TextAlign.center,
        style: serif(
          size: 18,
          weight: FontWeight.w800,
          color: AppColors.goldDark,
          letterSpacing: 6,
        ),
      ),
      Text(
        'TRẠNG NGUYÊN',
        textAlign: TextAlign.center,
        style: serif(size: 38, weight: FontWeight.w900, color: AppColors.red),
      ),
      const SizedBox(height: 4),
      Text(
        'Hương thí  ·  Hội thí  ·  Đình thí',
        textAlign: TextAlign.center,
        style: serif(size: 14, color: AppColors.inkSoft, letterSpacing: 1),
      ),
      const SizedBox(height: 28),
      TextField(
        controller: _name,
        maxLength: 18,
        textAlign: TextAlign.center,
        decoration: const InputDecoration(
          labelText: 'Danh tính sĩ tử',
          border: OutlineInputBorder(),
          counterText: '',
          filled: true,
          fillColor: AppColors.card,
        ),
      ),
      const SizedBox(height: 16),
    ];

    if (error != null) {
      children.add(
        Text(
          'Không đọc được dữ liệu câu hỏi: $error',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.wrong),
        ),
      );
      children.add(const SizedBox(height: 12));
    } else if (!ready) {
      children.add(
        const Center(
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        ),
      );
      children.add(const SizedBox(height: 12));
    }

    children.add(
      PrimaryButton(
        label: 'Vào trường thi',
        icon: Icons.edit,
        onPressed: ready ? _start : null,
      ),
    );
    children.add(const SizedBox(height: 12));
    children.add(
      SecondaryButton(label: 'So tài (wifi LAN) · sắp ra mắt', onPressed: _soTai),
    );
    children.add(const SizedBox(height: 8));
    children.add(
      TextButton(
        onPressed: _showRules,
        child: const Text('Thể lệ khoa thi'),
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: PageScroll(children: children),
      ),
    );
  }
}
