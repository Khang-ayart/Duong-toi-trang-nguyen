import 'package:flutter/material.dart';

import 'engine.dart';
import 'theme.dart';
import 'widgets.dart';

/// Ảnh đại diện sĩ tử: vòng tròn màu theo số báo danh, chữ cái đầu của tên.
/// Người chơi có vòng tròn đỏ viền vàng cùng biểu tượng riêng.
class CompetitorAvatar extends StatelessWidget {
  final Competitor who;
  final double size;

  const CompetitorAvatar({super.key, required this.who, this.size = 34});

  String get _initial {
    final List<String> parts = who.name.trim().split(RegExp(r'\s+'));
    final String last = parts.isEmpty ? '' : parts.last;
    if (last.isEmpty) {
      return '?';
    }
    return String.fromCharCode(last.runes.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (who.isPlayer) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.red,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.gold, width: 2),
        ),
        child: Icon(Icons.person, size: size * 0.6, color: Colors.white),
      );
    }
    final Color bg = HSLColor.fromAHSL(
      1.0,
      ((who.id * 47) % 360).toDouble(),
      0.42,
      0.40,
    ).toColor();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(
        _initial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.46,
        ),
      ),
    );
  }
}

/// Bảng xếp hạng sau mỗi kỳ thi: top 10, kèm dòng của người chơi nếu ngoài top 10.
class StandingsPanel extends StatelessWidget {
  final String title;
  final int round; // 0 Hương, 1 Hội, 2 Đình
  final List<StandingRow> rows;
  final int passedCount;
  final int participantCount;

  const StandingsPanel({
    super.key,
    required this.title,
    required this.round,
    required this.rows,
    required this.passedCount,
    required this.participantCount,
  });

  @override
  Widget build(BuildContext context) {
    final bool dinh = round == 2;
    final List<StandingRow> top = rows.take(kBoardSize).toList();
    StandingRow? mine;
    for (final StandingRow r in rows) {
      if (r.who.isPlayer && r.rank > kBoardSize) {
        mine = r;
      }
    }

    final List<Widget> children = <Widget>[
      Text(
        title,
        textAlign: TextAlign.center,
        style: serif(size: 17, weight: FontWeight.w900, color: AppColors.red),
      ),
      const SizedBox(height: 4),
      Text(
        'Đạt $passedCount/$participantCount sĩ tử'
        '${dinh ? ' (đủ điều kiện xét bảng vàng)' : ''}',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
      ),
      const SizedBox(height: 4),
      Text(
        dinh
            ? 'Xếp theo điểm Đình thí. Số nhỏ bên phải là tổng điểm 3 kỳ.'
            : 'Xếp theo tổng điểm. Số xanh là điểm vừa cộng ở kỳ này.',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
      ),
      const SizedBox(height: 8),
    ];

    for (final StandingRow r in top) {
      children.add(_row(r, dinh));
    }
    if (mine != null) {
      children.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 2),
          child: Text(
            '· · ·',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.inkSoft, letterSpacing: 4),
          ),
        ),
      );
      children.add(_row(mine, dinh));
    }

    return Panel(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _row(StandingRow r, bool dinh) {
    final bool me = r.who.isPlayer;
    final int mainScore = dinh ? r.roundScore : r.cumulative;
    final Color rankColor = r.rank <= 3 ? AppColors.red : AppColors.ink;

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
            width: 30,
            child: Text(
              '${r.rank}',
              textAlign: TextAlign.center,
              style: serif(size: 16, weight: FontWeight.w900, color: rankColor),
            ),
          ),
          const SizedBox(width: 4),
          CompetitorAvatar(who: r.who, size: 32),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              me ? '${r.who.name} (bạn)' : r.who.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: me ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(width: 36, child: _changeChip(r.change)),
          SizedBox(
            width: 58,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  '$mainScore',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (dinh)
                  Text(
                    '${r.cumulative}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.inkSoft,
                    ),
                  )
                else
                  Text(
                    '+${r.roundScore}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.green,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _changeChip(int? change) {
    if (change == null) {
      return const SizedBox.shrink();
    }
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
}
