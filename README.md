# Đường Tới Trạng Nguyên

Game thi cử Hương, Hội, Đình chơi hoàn toàn offline trên Android, cùng 50 sĩ tử máy.

## Về dự án này

- **Được làm hoàn toàn bằng AI.** Toàn bộ mã nguồn, câu hỏi và lời thoại do AI (Claude của Anthropic) soạn theo ý tưởng và yêu cầu của tác giả.
- **Miễn phí và offline.** Không quảng cáo, không thu phí, chơi không cần mạng, không thu thập dữ liệu người chơi. Mạng chỉ dùng cho một việc tùy chọn: hỏi GitHub xem có bản cập nhật mới không (không gửi dữ liệu gì của người chơi).
- **Mục đích giải trí và giáo dục.** Đây là trò chơi để vui và ôn kiến thức phổ thông, khoa cử xưa chỉ là bối cảnh.
- **Tác giả không dùng vào mục đích thương mại.** Dự án không được tạo ra để kiếm tiền. Mã nguồn dùng giấy phép MIT (xem `LICENSE`), người khác được tự do sử dụng theo giấy phép đó.
- **Về nội dung.** Câu hỏi do AI soạn nên có thể còn sai sót hoặc chưa chính xác tuyệt đối. Nếu phát hiện lỗi, bạn có thể sửa trực tiếp trong `assets/data/questions.json` hoặc mở issue.

## Luật chơi

| Kỳ thi | Cấp độ | Số câu | Điều kiện đi tiếp |
|---|---|---|---|
| Hương thí | Dễ | 12 | Đúng từ 10/12 để vào Hội |
| Hội thí | Trung bình | 12 | Đúng từ 8/12 để vào Đình |
| Đình thí | Khó | 12 | Đúng từ 6/12 mới được xét bảng vàng |

- Ba người điểm Đình cao nhất: Trạng Nguyên, Bảng Nhãn, Thám Hoa. Người còn lại qua Đình là Hoàng Giáp (Đệ nhị giáp Tiến sĩ). Có khoa không ai đỗ.
- Bằng điểm Đình thì xét tổng điểm 3 kỳ, rồi tổng thời gian ít hơn.
- Dừng bước giữa chừng vẫn có danh xưng xưa: đỗ Hương rớt Hội là **Cử Nhân**, đỗ Hội rớt Đình là **Phó Bảng**.
- Sau mỗi kỳ có bảng xếp hạng top 10 (kèm avatar, điểm vừa cộng, lên/xuống hạng). Nếu bạn ngoài top 10, dòng của bạn hiện ở dưới cùng.
- Mỗi câu 30 giây = 300 điểm. 1 giây = 100 khắc, cứ 10 khắc trừ 1 điểm.
- Chuỗi: đúng liên tiếp và mỗi câu từ 250 điểm trở lên (trả lời trong 5 giây). Từ câu thứ 6 của chuỗi, cộng thêm 10 × (độ dài chuỗi − 5). Sai, hết giờ hoặc chậm quá 5 giây là đứt chuỗi. Sang kỳ mới tính lại.

## Cấu trúc

- `assets/data/questions.json`: 120 câu hỏi (mỗi cấp 40 câu, mỗi kỳ bốc ngẫu nhiên 12 câu của đúng cấp đó, đáp án xáo lại). Câu dễ chỉ ra ở Hương, câu trung bình chỉ ra ở Hội, câu khó chỉ ra ở Đình. Mỗi câu có phần giải thích ngắn hiện sau khi trả lời.
- `assets/data/messages.json`: lời thoại cổ phong theo từng tình huống. Chỗ `{ten}` được thay bằng tên sĩ tử. Sửa tay thoải mái.
- `lib/engine.dart`: luật chơi, điểm, chuỗi, 50 bot. Các con số luật nằm ở đầu file.
- `lib/screens/`: màn hình chủ, thi, kết quả.

## Thêm câu hỏi

Thêm một mục vào `questions.json`:

```json
{
  "id": "h21",
  "level": 0,
  "topic": "Địa lý",
  "q": "Nội dung câu hỏi?",
  "options": ["Đáp án A", "Đáp án B", "Đáp án C", "Đáp án D"],
  "answer": 0,
  "explain": "Giải thích ngắn, tối đa 2 dòng (có thể bỏ trống)."
}
```

`level`: 0 = dễ, 1 = trung bình, 2 = khó. `explain` là phần giải thích hiện sau khi trả lời, nên viết ngắn (khoảng 100 ký tự). `answer` là vị trí (0 đến 3) của đáp án đúng trong `options`. Mỗi cấp cần ít nhất 12 câu, và không nên lặp một câu ở hai cấp khác nhau.

## Build APK

Đẩy code lên nhánh `main`, vào tab **Actions**, chạy workflow **Build APK**. File APK nằm trong mục **Artifacts** của lần chạy, và cả trong mục **Releases** để tải thẳng trên điện thoại. Khung Android được workflow tự tạo, không cần commit thư mục `android/`.

## Cập nhật app

Trong app có nút **Kiểm tra cập nhật** (và tự kiểm tra khi mở app nếu có mạng). Có bản mới thì bấm **Tải bản mới**, mở file APK tải về và cài, máy sẽ cài đè lên bản cũ, **không cần gỡ app, không mất dữ liệu**.

Để cài đè được, mọi bản build phải ký cùng một khóa và có số bản tăng dần. Vì vậy workflow dùng khóa cố định `keystore/debug.keystore` (đây là khóa của game giải trí, công khai trong repo, không dùng cho mục đích bảo mật) và đặt số bản bằng số lần chạy workflow.

## So tài (wifi LAN, bản thử nghiệm)

Cùng một wifi: một người bấm **Tạo phòng** rồi đọc mã 4 số, người khác bấm **Tìm phòng** và nhập mã (nếu không tìm thấy thì nhập địa chỉ IP của chủ phòng). Tối đa 10 người, 3 kỳ x 10 câu = 30 câu, mọi người thi hết 30 câu. Ngưỡng đạt: Hương 8/10, Hội 7/10, Đình 5/10; danh hiệu tính theo số kỳ đã vượt, top 3 Đình xếp hạng Thám Hoa, Bảng Nhãn, Trạng Nguyên. Một số router bật "cách ly thiết bị" sẽ chặn chức năng này.

## Chưa có

- Thêm câu hỏi (hiện 120 câu).
