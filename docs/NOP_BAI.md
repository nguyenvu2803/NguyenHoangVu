# Hồ sơ nộp bài — Nguyễn Hoàng Vũ, 2380602586

| Trường | Nội dung |
|---|---|
| Link GitHub chứa frontend Flutter | https://github.com/nguyenvu2803/NguyenHoangVu/tree/main/mobile |
| Link GitHub chứa backend | https://github.com/nguyenvu2803/NguyenHoangVu/tree/main/backend_shared |
| Link API | https://nguyen-hoai-nam-2380601398-api.onrender.com/v1 |
| Link YouTube demo | CHUA_CO_LINK — chủ bài cần quay và tải video thật |
| File cá nhân | `hovaten.txt` tại root source |
| APK Android | `dist/NguyenHoangVu.apk` trong gói bàn giao |

Frontend/backend nằm ở hai thư mục cùng repository cá nhân; backend upstream dùng chung được ghi nguồn. Chỉ nộp link sau khi mở được source trên GitHub. Không nộp link trang đăng nhập Render thay API.

## Cần đạt trước khi bấm nộp

- Source GitHub public mở được, bao gồm pubspec.lock, mã Flutter và Node package-lock/migrations; không có secret.
- Cài APK production, DEMO_MODE/SHOW_DEMO/ALLOW_INSECURE_DEV đều false; truy cập API Internet không qua máy lập trình. Đã thử đăng ký và OTP email thật thành công; tài khoản cá nhân hiện chờ admin duyệt.
- Chủ API cần deploy chat và Cài đặt/migration 005–006; health công khai có `features.realtimeChat=true`, `quickFaceLogin=true`, `selfProfile=true`. Xem SETTINGS_FACE_LOGIN.md.
- Có tài khoản cá nhân active và tài khoản quản trị test hợp lệ để ghi hình đủ quyền/CRUD; OTP email thật đến hộp thư.
- Quay đủ khuôn mặt, chia sẻ vị trí, dịch tin nhắn realtime và Nhịp cân bằng, ghi rõ giới hạn máy ảo nếu có. Không dùng screenshot fixture thay video tích hợp thật.
- `hovaten.txt` ghi đúng Nguyễn Hoàng Vũ — 2380602586, chức năng, điểm dự kiến có điều kiện, link video thật.
- Mở thử YouTube khi chưa đăng nhập; kiểm tra API/database còn hoạt động đến ngày chấm bài.

Trạng thái và giới hạn kiểm thử: `VERIFICATION.md`. Gói chuẩn bị không thay thế các bước còn thiếu nói trên.

Bản 1.3.0+4 bổ sung thiết lập khuôn mặt sau mật khẩu/OTP, quét mặt không OTP trên thiết bị đã thiết lập, camera đối xứng, cỡ chữ, màu nền và sửa hồ sơ. Cần deploy backend mới; không xác nhận production chỉ từ APK.
