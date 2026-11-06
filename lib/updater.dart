import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Số hiệu bản build, do GitHub Actions truyền vào (--dart-define=BUILD_NUMBER=...).
/// Chạy máy local không truyền thì là 0.
const int kBuildNumber = int.fromEnvironment('BUILD_NUMBER', defaultValue: 0);

/// Kho GitHub chứa các bản phát hành (Releases).
const String kRepo = 'Khang-ayart/Duong-toi-trang-nguyen';

class UpdateInfo {
  final int build;
  final String apkUrl;
  final String pageUrl;

  const UpdateInfo({
    required this.build,
    required this.apkUrl,
    required this.pageUrl,
  });
}

/// Hỏi GitHub bản phát hành mới nhất (tên thẻ dạng "build-12").
/// - Trả về null nếu đang dùng bản mới nhất.
/// - Ném lỗi nếu không có mạng hoặc GitHub không trả lời; nơi gọi tự xử lý.
/// Đây là lần duy nhất app dùng mạng, chỉ để xem có bản mới, không gửi dữ liệu người chơi.
Future<UpdateInfo?> checkForUpdate() async {
  final HttpClient client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 6);
  try {
    final HttpClientRequest req = await client
        .getUrl(Uri.parse('https://api.github.com/repos/$kRepo/releases/latest'))
        .timeout(const Duration(seconds: 8));
    req.headers.set('Accept', 'application/vnd.github+json');
    req.headers.set('User-Agent', 'DuongToiTrangNguyen');
    final HttpClientResponse res =
        await req.close().timeout(const Duration(seconds: 8));
    if (res.statusCode == 404) {
      return null; // chưa có bản phát hành nào
    }
    if (res.statusCode != 200) {
      throw HttpException('GitHub trả mã ${res.statusCode}');
    }
    final String body = await res
        .transform(utf8.decoder)
        .join()
        .timeout(const Duration(seconds: 8));
    final Map<String, dynamic> json = jsonDecode(body) as Map<String, dynamic>;

    final String tag = (json['tag_name'] as String?) ?? '';
    final RegExpMatch? m = RegExp(r'(\d+)$').firstMatch(tag);
    final int build = m == null ? 0 : int.parse(m.group(1)!);
    if (build <= kBuildNumber) {
      return null;
    }

    String apkUrl = '';
    final List<dynamic> assets = (json['assets'] as List<dynamic>?) ?? <dynamic>[];
    for (final dynamic a in assets) {
      final Map<String, dynamic> asset = a as Map<String, dynamic>;
      final String name = (asset['name'] as String?) ?? '';
      if (name.toLowerCase().endsWith('.apk')) {
        apkUrl = (asset['browser_download_url'] as String?) ?? '';
        break;
      }
    }
    final String pageUrl = (json['html_url'] as String?) ??
        'https://github.com/$kRepo/releases/latest';
    return UpdateInfo(
      build: build,
      apkUrl: apkUrl.isEmpty ? pageUrl : apkUrl,
      pageUrl: pageUrl,
    );
  } finally {
    client.close(force: true);
  }
}
