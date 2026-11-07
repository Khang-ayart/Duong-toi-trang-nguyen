# Icon app (chuẩn bị cho đợt cập nhật sau)

Chưa gắn vào app. Thư mục này chỉ lưu sẵn bộ icon làm từ hình gốc: mũ trạng nguyên trên ba đồng tiền Hương, Hội, Đình.

## Có gì ở đây

- `icon_master_1024.png`: bản gốc 1024 px đã xử lý: nền trắng ở bốn góc thành trong suốt (bo góc), và đã xóa dấu sao nhỏ của công cụ tạo ảnh ở góc dưới phải.
- `res/mipmap-*/ic_launcher.png`: icon thường, đủ 5 độ phân giải (48, 72, 96, 144, 192 px), dùng cho Android 7 trở xuống.
- `res/mipmap-*/ic_launcher_foreground.png` và `res/values/ic_launcher_background.xml`: icon thích ứng (adaptive) cho Android 8 trở lên. Lớp trước là biểu tượng trong vòng hoa văn, lớp sau là màu đỏ bordeaux `#480914`. Dòng chữ "TRẠNG NGUYÊN" ở đáy được bỏ khỏi lớp trước vì launcher sẽ cắt tròn hoặc bo vuông và làm cụt chữ.
- `res/mipmap-anydpi-v26/ic_launcher.xml`: khai báo icon thích ứng.

## Cách gắn vào app (làm ở đợt cập nhật sau)

Khung Android do workflow tự tạo mỗi lần build, nên chỉ cần thêm một bước vào `.github/workflows/build-apk.yml`, ngay sau bước "Tạo khung Android nếu repo chưa có":

```yaml
      - name: Gắn icon app
        run: cp -r prep/icon/res/* android/app/src/main/res/
```

Khi `flutter create` chạy nó đã tạo sẵn `ic_launcher.png` mặc định, bước trên sẽ ghi đè bằng icon này. Không cần sửa `AndroidManifest.xml` vì manifest mặc định đã trỏ tới `@mipmap/ic_launcher`.

## Ghi chú

- Muốn đổi icon thì thay `icon_master_1024.png` rồi tạo lại các kích thước, hoặc gửi mình hình mới.
- Chưa tạo icon 512 px cho Google Play vì app chưa đăng lên cửa hàng.
