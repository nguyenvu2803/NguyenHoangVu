# Triển khai chat và dịch tin nhắn

Bản 1.2.0+3 chọn **khuôn mặt, định vị, dịch tin nhắn realtime**. Một APK, ba giao diện theo quyền. QR là tiện ích phụ.

## Tình trạng dịch vụ

API đang cấu hình trong APK: `https://nguyen-hoai-nam-2380601398-api.onrender.com/v1`.
Chủ API chung giữ quyền deploy và database. Source mới trong repository cá nhân chưa tự thay đổi dịch vụ đó. Đăng nhập Render/GitHub trên trình duyệt không tự cấp token deploy cho công cụ dòng lệnh.

## Chủ API cập nhật dịch vụ đang có

1. Lấy source `backend_shared` bản mới từ repository cá nhân. So sánh thay đổi trước khi cập nhật backend chung; giữ nguyên `.env` và secret trong Render. File `NguyenHoangVu-chat-backend.patch` trong bộ bàn giao chứa thay đổi chat để tham khảo/apply khi source nền khớp. Chạy `git apply --check -p2 /duong-dan/NguyenHoangVu-chat-backend.patch` tại root backend trước khi apply. Nếu có xung đột, đối chiếu source, không ép ghi đè.
2. Thêm `src/chat.js`, migration `005_realtime_chat.sql`; cập nhật `src/app.js`, `src/auth.js`, `src/server.js`. Không sửa migration 001–004 đã áp dụng. Chat dùng dependency hiện có của Node backend; không cần dịch vụ trả phí hay API key dịch.
3. Chạy `npm ci`, `npm run models:fetch`, `npm test` trên Node.js >=22. Máy cần hỗ trợ ONNX Runtime CPU của bản đã ghim. Khi deploy Render dùng build/start từ `render.yaml` hoặc cấu hình upstream tương ứng.
4. Deploy commit đã kiểm tra. `src/server.js` tự chạy `applyMigrations()` trước khi mở cổng; có thể chạy `npm run migrate` riêng bằng môi trường database của chủ dịch vụ. Không chạy migration bằng URL database của người khác khi chưa được cấp quyền.
5. Chạy `python3 scripts/check_chat_deployment.py` từ project Flutter. Health phải trả `data.features.realtimeChat=true`. Kiểm tra thêm `/chat/contacts`, lịch sử và SSE bằng tài khoản được cấp quyền. Với proxy riêng, tắt buffering/cache cho SSE, cho timeout trên 40 giây; Render chuyển tiếp SSE trực tiếp.
6. Admin kích hoạt tài khoản `hoangvu2380602586`, gán chi nhánh; cấp tài khoản quản lý/admin thử nghiệm hợp lệ. Không dùng mật khẩu hay OTP mặc định.
7. Mở hai thiết bị/phiên Android bằng hai tài khoản active. Gửi tin cả hai chiều, xác nhận tin đến tự xuất hiện; bấm Bật dịch để tải mô hình, chọn Việt/Anh/Trung. Kiểm tra ngắt/bật mạng và kết nối lại. Chỉ sau bước này ghi nhận chat production đạt.

Nếu deploy dịch vụ riêng, dùng `render.yaml` gói Free + PostgreSQL Neon Free và relay email theo `DEPLOY_FREE.md`. Lấy URL HTTPS Render thực tế, cập nhật `mobile/config/production.json`, giữ ba cờ demo/insecure false rồi build lại APK. Không tự tạo URL chưa được cấp.

## Phạm vi chức năng

- SSE dùng Bearer header, không đưa token vào URL. Mỗi 1.5 giây server kiểm tra thay đổi từ PostgreSQL, heartbeat 15 giây; độ trễ phụ thuộc mạng/cold start.
- Nhân viên/quản lý chat cùng chi nhánh hoặc với admin; admin liên hệ toàn hệ thống. Chỉ hai người trong cuộc đọc lịch sử; admin không đọc hội thoại của người khác.
- Tin được lưu bản gốc và ngôn ngữ nguồn. UUID cho phép người dùng gửi lại cùng nội dung sau timeout mà không tạo hai bản ghi.
- Dịch ML Kit trên Android, cần mạng tải mô hình lần đầu. Sau đó mô hình dịch dùng trên thiết bị; gửi/nhận tin vẫn cần Internet. Chưa bảo đảm đúng mọi ngữ cảnh.
- Không hứa thông báo khi app đóng. App dừng SSE khi về nền, tải bù tin khi mở lại. Đây là chat realtime trong màn đang mở.

## Lệnh kiểm thử

```sh
cd backend_shared
npm test
cd ../mobile
flutter analyze --no-pub
flutter test --no-pub
flutter test integration_test/translation_test.dart -d emulator-5554
cd ..
python3 scripts/test_backend_integration.py
python3 scripts/check_chat_deployment.py
```

Kiểm thử Dart–Express chạy HTTP loopback trong môi trường tách biệt; APK nộp chỉ dùng HTTPS public.
