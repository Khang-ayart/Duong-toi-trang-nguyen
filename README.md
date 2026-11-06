# Đường Tới Trạng Nguyên

Game thi cử Hương, Hội, Đình chơi hoàn toàn offline trên Android, cùng 50 sĩ tử máy.

## Về dự án này

- **Được làm hoàn toàn bằng AI.** Toàn bộ mã nguồn, câu hỏi và lời thoại do AI (Claude của Anthropic) soạn theo ý tưởng và yêu cầu của tác giả.
- **Miễn phí và offline.** Không quảng cáo, không thu phí, không cần mạng, không thu thập dữ liệu người chơi.
- **Mục đích giải trí và giáo dục.** Đây là trò chơi để vui và ôn kiến thức phổ thông, khoa cử xưa chỉ là bối cảnh.
- **Không nhằm mục đích thương mại.** Dự án không được tạo ra để kiếm tiền, và giấy phép (xem `LICENSE`) không cho phép dùng lại vào mục đích thương mại.
- **Về nội dung.** Câu hỏi do AI soạn nên có thể còn sai sót hoặc chưa chính xác tuyệt đối. Nếu phát hiện lỗi, bạn có thể sửa trực tiếp trong `assets/data/questions.json` hoặc mở issue.

## Luật chơi

| Kỳ thi | Cấp độ | Số câu | Điều kiện đi tiếp |
|---|---|---|---|
| Hương thí | Dễ | 12 | Đúng từ 10/12 để vào Hội |
| Hội thí | Trung bình | 12 | Đúng từ 8/12 để vào Đình |
| Đình thí | Khó | 12 | Đúng từ 6/12 mới được xét bảng vàng |

- Ba người điểm Đình cao nhất: Trạng Nguyên, Bảng Nhãn, Thám Hoa. Người còn lại qua Đình là Tú Tài. Có khoa không ai đỗ.
- Bằng điểm Đình thì xét tổng điểm 3 kỳ, rồi tổng thời gian ít hơn.
- Mỗi câu 30 giây = 300 điểm. 1 giây = 100 khắc, cứ 10 khắc trừ 1 điểm.
- Chuỗi: đúng liên tiếp và mỗi câu từ 250 điểm trở lên (trả lời trong 5 giây). Từ câu thứ 6 của chuỗi, cộng thêm 10 × (độ dài chuỗi − 5). Sai, hết giờ hoặc chậm quá 5 giây là đứt chuỗi. Sang kỳ mới tính lại.

## Cấu trúc

- `assets/data/questions.json`: 60 câu hỏi (mỗi cấp 20 câu, mỗi kỳ bốc ngẫu nhiên 12 câu, đáp án xáo lại).
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
  "answer": 0
}
```

`level`: 0 = dễ, 1 = trung bình, 2 = khó. `answer` là vị trí (0 đến 3) của đáp án đúng trong `options`. Mỗi cấp cần ít nhất 12 câu.

## Build APK

Đẩy code lên nhánh `main`, vào tab **Actions**, chạy workflow **Build APK**. File APK nằm trong mục **Artifacts** của lần chạy, và cả trong mục **Releases** để tải thẳng trên điện thoại. Khung Android được workflow tự tạo, không cần commit thư mục `android/`.

## Chưa có

- So tài qua wifi LAN (Tạo Phòng / Tìm Phòng bằng mã số, tối đa 10 người, 30 câu).
- Thêm câu hỏi (hiện 60 câu).
