# Kết quả kiểm tra — 29/10/2026

## Đã thực hiện

| Kiểm tra | Kết quả |
|---|---|
| Backend `python -m pytest -q` | **30 passed**, một DeprecationWarning từ Starlette/AnyIO |
| Python compile/import và `pip check` | Đạt, không có dependency bị thiếu/xung đột |
| Flutter `flutter analyze --no-pub` | **No issues found** |
| Flutter `flutter test --no-pub` | **4 passed** |
| Flutter Web release, demo | Build thành công |
| Android APK release, demo | Build thành công; package `vn.nguyenhoangvu.nguyen_hoang_vu`, tên hiển thị `NguyenHoangVu` |
| Cài APK lên Android emulator API 36 | `Success`, khởi tạo được process ứng dụng |
| Chạy giao diện native trên emulator | **Chưa kết luận**: emulator gặp System UI ANR và treo thao tác chụp màn hình; không dùng kết quả này để xác nhận camera/GPS/sinh trắc học |
| Docker Compose syntax/config | `docker compose ... config --no-env-resolution --quiet` đạt |
| Trình duyệt 1440×1050 và 390×844 | Đăng nhập/demo, dashboard, chuyển vai trò, quản trị và QR hiển thị được |
| Thao tác trình duyệt | Demo vào ca/ra ca thành công; admin tạo được chi nhánh có tọa độ; mở được QR có đếm ngược |
| Kiểm tra lại sau sửa chờ Render Free | Backend **30 passed**, Flutter **4 passed**, analyzer không lỗi |
| Chặn cấu hình nộp bài sai | Build yêu cầu `DEMO_MODE=false`, `ALLOW_INSECURE_DEV=false`, API HTTPS production phản hồi; script smoke check từ chối URL nội bộ và URL chứa credential trước khi gọi mạng |

APK demo ký debug key để cài thử. Build phát cảnh báo KGP/plugin và font Cupertino từ toolchain; build vẫn hoàn tất, các icon giao diện đã quan sát hiển thị đúng. Chưa tạo APK kết nối production vì nhóm chưa có URL đã deploy.

Source mới tăng thời gian chờ kết nối API lên 90 giây để hỗ trợ Render Free khởi động lại; APK demo hiện có chưa build lại sau thay đổi này. Chế độ demo không gọi API nên thay đổi không ảnh hưởng luồng demo. Bản APK production phải build từ source mới sau khi có URL thật.

## Phạm vi 30 kiểm thử backend

- Đăng ký và xác minh email; tài khoản tự đăng ký không tự nhận quyền nhân viên/admin.
- Password + OTP, không trả token trước OTP, không trả OTP trong response, khóa sau 5 lần sai, chống dùng lại mã.
- Chặn dùng SMS để bỏ qua xác minh email khi đăng ký.
- Refresh token xoay một lần, logout thu hồi, tài khoản bị khóa không dùng được access token cũ.
- Phân quyền admin/employee/customer, bảo vệ dữ liệu và thao tác người khác.
- CRUD nhân viên, chi nhánh, ca, phân ca; unique constraint và khóa ngoại.
- GPS ngoài vùng, độ chính xác thấp, QR giả/hết hạn/sai chi nhánh/sai loại token.
- Vào/ra ca, chặn ghi trùng, bảo vệ lịch sử và đơn nghỉ nguyên ngày.
- CRUD đơn nghỉ pending, chặn trùng khoảng ngày, admin duyệt và quyền chủ đơn.
- Chia sẻ/dừng chia sẻ vị trí và giới hạn đọc dữ liệu.
- Nhịp làm việc, export CSV, audit.
- OAuth state, ràng buộc verifier, đổi mã một lần; provider Google được **giả lập trong test**.
- Production từ chối SQLite, HTTP, seed demo, secret mẫu hoặc thiếu credential của provider email được chọn.
- Rate limit và kiểm tra dữ liệu đầu vào.
- Brevo HTTPS: production không cần SMTP, request gửi đúng người nhận, provider trả 401/429/500 thành 503, không lộ OTP/API key trong log, lỗi gửi không cấp token/challenge và không fallback SMTP.

Các test DB dùng SQLite tạm riêng biệt, không ghi vào DB người dùng.

## Phạm vi 4 kiểm thử Flutter

1. Mở đăng nhập, chủ động vào demo và hiển thị dashboard trên điện thoại.
2. Admin vào quản lý/chi nhánh; customer chuyển sang trang riêng, không có menu admin.
3. Tất cả màn nhân viên không tràn bố cục ở chiều rộng 320 và 768.
4. Nhân viên tạo đơn nghỉ qua form và thấy dữ liệu mới sau làm mới.

## Chưa được kiểm chứng trong môi trường này

- **Chưa deploy thật**: chưa có tài khoản/credential Render, Neon, Brevo và URL production của bạn; không cần mua domain riêng cho API Render.
- PostgreSQL và Docker runtime: Docker daemon của máy không chạy; cấu hình Compose mới kiểm tra ở mức syntax.
- Brevo email OTP/SMS thật và Google OAuth thật: cần credential dịch vụ của nhóm. Test provider giả lập không thay thế nghiệm thu tích hợp thật.
- Face ID/vân tay, camera QR, GPS và bảng chia sẻ trên điện thoại thật.
- Build iOS/IPA: Xcode trên máy chưa đầy đủ. Source và plist iOS đã chuẩn bị, chưa build hoặc ký IPA.
- Script PowerShell chưa được chạy trên Windows; nhóm cần thử trên máy thành viên dùng Windows.

Cấu hình mới dùng Render Free + Neon Free + Brevo Free; xem [DEPLOY_FREE.md](DEPLOY_FREE.md). Các test Brevo giả lập HTTP, chưa chứng minh tài khoản gửi thật đã được duyệt.

Yêu cầu nộp bài bắt buộc API public hoạt động và APK kết nối API đó. Cấu hình và [hướng dẫn deploy](DEPLOY.md) chưa thay thế nghiệm thu triển khai thật. Hoàn thành checklist trong [DEMO.md](DEMO.md) trước khi nộp bài.

## Hình ảnh

- [Dashboard desktop](dashboard-desktop.png)
- [Dashboard điện thoại](dashboard-mobile.png)
- [Màn đăng nhập](login-desktop.png)
- [QR trên điện thoại](qr-mobile.png)
