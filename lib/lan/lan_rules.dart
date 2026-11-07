import '../engine.dart';

// ============================================================
//  LUẬT "SO TÀI" QUA WIFI LAN - muốn chỉnh thì đổi các con số ở đây
// ============================================================

/// Cổng chủ phòng mở cho người chơi nối vào (thử lần lượt kLanPort đến kLanPort + 9).
const int kLanPort = 45455;

/// Cổng chủ phòng phát tín hiệu "phòng số X ở đây" cho cả wifi.
const int kLanDiscoveryPort = 45454;

/// Chữ nhận dạng gói tin của game này.
const String kLanApp = 'dttn';

/// Tối đa người trong một phòng (kể cả chủ phòng).
const int kLanMaxPlayers = 10;

/// Mỗi kỳ 10 câu, tổng 30 câu: 10 dễ (Hương), 10 trung bình (Hội), 10 khó (Đình).
const int kLanPerRound = 10;

/// Số câu đúng tối thiểu để được đi tiếp, quy đổi từ 10/12, 8/12, 6/12 sang 10 câu.
/// Hương -> Hội: 8/10, Hội -> Đình: 7/10, Đình -> được xét bảng vàng: 5/10.
const List<int> kLanPassMark = <int>[8, 7, 5];

/// Thời gian xem đáp án và bảng xếp hạng giữa hai câu.
const int kLanRevealMs = 7000;

/// Nghỉ lâu hơn khi sắp sang kỳ thi mới.
const int kLanRoundBreakMs = 9000;

/// Sau câu cuối trước khi hiện bảng vàng.
const int kLanLastRevealMs = 5000;

/// Danh hiệu cuối khoa, từ thấp đến cao.
enum LanTitle { none, cuNhan, phoBang, hoangGiap, thamHoa, bangNhan, trangNguyen }

LanTitle lanTitleFromName(String? name) {
  for (final LanTitle t in LanTitle.values) {
    if (t.name == name) {
      return t;
    }
  }
  return LanTitle.none;
}

String lanTitleLabel(LanTitle t) {
  switch (t) {
    case LanTitle.none:
      return 'Chưa đỗ';
    case LanTitle.cuNhan:
      return kTitleCuNhan;
    case LanTitle.phoBang:
      return kTitlePhoBang;
    case LanTitle.hoangGiap:
      return 'Hoàng Giáp';
    case LanTitle.thamHoa:
      return 'Thám Hoa';
    case LanTitle.bangNhan:
      return 'Bảng Nhãn';
    case LanTitle.trangNguyen:
      return 'Trạng Nguyên';
  }
}

/// Khóa lời thoại trong assets/data/messages.json ứng với từng danh hiệu.
String lanTitleMessageKey(LanTitle t) {
  switch (t) {
    case LanTitle.none:
      return 'fail_huong';
    case LanTitle.cuNhan:
      return 'danh_cunhan';
    case LanTitle.phoBang:
      return 'danh_phobang';
    case LanTitle.hoangGiap:
      return 'hoanggiap';
    case LanTitle.thamHoa:
      return 'thamhoa';
    case LanTitle.bangNhan:
      return 'bangnhan';
    case LanTitle.trangNguyen:
      return 'trangnguyen';
  }
}

/// Kết quả ba kỳ của một người chơi trong phòng.
class LanPlayerScore {
  final int id;
  final List<RoundTally> rounds;

  const LanPlayerScore(this.id, this.rounds);

  int get total {
    int s = 0;
    for (final RoundTally t in rounds) {
      s += t.score;
    }
    return s;
  }

  int get khac {
    int k = 0;
    for (final RoundTally t in rounds) {
      k += t.totalKhac;
    }
    return k;
  }

  /// Đã đạt liên tục từ Hương đến hết kỳ r hay chưa.
  /// Ai rớt một kỳ thì các kỳ sau dù có giỏi cũng không được tính.
  bool chainPassed(int r) {
    for (int i = 0; i <= r; i++) {
      if (rounds[i].correct < kLanPassMark[i]) {
        return false;
      }
    }
    return true;
  }
}

/// Xếp theo tổng điểm; bằng nhau thì ai dùng ít thời gian hơn; vẫn bằng thì theo số báo danh.
int compareByTotal(LanPlayerScore a, LanPlayerScore b) {
  if (a.total != b.total) {
    return b.total.compareTo(a.total);
  }
  if (a.khac != b.khac) {
    return a.khac.compareTo(b.khac);
  }
  return a.id.compareTo(b.id);
}

/// Xếp theo luật bảng vàng: điểm Đình thí, rồi tổng điểm 3 kỳ, rồi thời gian.
int compareForPodium(LanPlayerScore a, LanPlayerScore b) {
  final int sa = a.rounds[2].score;
  final int sb = b.rounds[2].score;
  if (sa != sb) {
    return sb.compareTo(sa);
  }
  return compareByTotal(a, b);
}

/// Phân danh hiệu cho cả phòng.
/// - Không qua Hương: Chưa đỗ. Qua Hương rớt Hội: Cử Nhân. Qua Hội rớt Đình: Phó Bảng.
/// - Qua cả Đình: xếp theo điểm Đình, nhất nhì ba là Trạng Nguyên, Bảng Nhãn, Thám Hoa,
///   người còn lại là Hoàng Giáp. Có thể không ai đỗ nên không có Trạng Nguyên.
Map<int, LanTitle> decideTitles(List<LanPlayerScore> all) {
  final Map<int, LanTitle> out = <int, LanTitle>{};
  final List<LanPlayerScore> finalists = <LanPlayerScore>[];
  for (final LanPlayerScore p in all) {
    if (p.chainPassed(2)) {
      finalists.add(p);
    } else if (p.chainPassed(1)) {
      out[p.id] = LanTitle.phoBang;
    } else if (p.chainPassed(0)) {
      out[p.id] = LanTitle.cuNhan;
    } else {
      out[p.id] = LanTitle.none;
    }
  }
  finalists.sort(compareForPodium);
  const List<LanTitle> podium = <LanTitle>[
    LanTitle.trangNguyen,
    LanTitle.bangNhan,
    LanTitle.thamHoa,
  ];
  for (int i = 0; i < finalists.length; i++) {
    out[finalists[i].id] = i < podium.length ? podium[i] : LanTitle.hoangGiap;
  }
  return out;
}

/// Thứ tự bảng cuối: người đỗ Đình (theo bảng vàng) rồi Phó Bảng, Cử Nhân, Chưa đỗ.
/// Trong cùng nhóm xếp theo tổng điểm.
List<LanPlayerScore> orderFinal(
  List<LanPlayerScore> all,
  Map<int, LanTitle> titles,
) {
  final List<LanPlayerScore> list = List<LanPlayerScore>.of(all);
  list.sort((LanPlayerScore a, LanPlayerScore b) {
    final LanTitle ta = titles[a.id] ?? LanTitle.none;
    final LanTitle tb = titles[b.id] ?? LanTitle.none;
    if (ta != tb) {
      return tb.index.compareTo(ta.index);
    }
    if (ta.index >= LanTitle.hoangGiap.index) {
      return compareForPodium(a, b);
    }
    return compareByTotal(a, b);
  });
  return list;
}
