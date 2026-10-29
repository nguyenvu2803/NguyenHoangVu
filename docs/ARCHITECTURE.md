# Kiến trúc bản mobile tích hợp

`Flutter Android` gọi HTTPS public `/v1` tới `Express Node.js`, server dùng PostgreSQL, HTTPS mail relay và YuNet/SFace CPU. Ảnh mặt chỉ gửi sau thao tác đồng ý; vị trí chỉ gửi sau người dùng chọn. Secret chỉ nằm backend.

`main.dart` chuyển AuthScreen, AccountWaiting hoặc LiveShell dựa trên user trả từ server. LiveShell có tổng quan, ca cá nhân, đơn điều chỉnh, quản trị/báo cáo theo vai trò và hồ sơ. Frontend không tự cấp quyền.

`core/api.dart` unwrap envelope, Bearer access token, hợp nhất refresh đồng thời và xử lý 401 trễ. POST timeout không tự retry. `core/live.dart` đọc dữ liệu schema thật, tạo/kiểm tra QR chọn ca, kiểm tra ảnh và phân tích Nhịp cân bằng.

Backend `backend_shared/` là nguồn dùng chung được ghi rõ tại INTEGRATION_NGUYENHOANGVU.md. `backend/` và Docker Compose cũ không phục vụ APK production này. Mỗi bản cài dùng cùng URL public để chia sẻ dữ liệu; dữ liệu local demo không đồng bộ server.

Kiểm thử được tách theo bằng chứng: Flutter với HTTP fixture; Express/SQL với pg-mem, mailbox và model thật; HTTP public không token; APK native trên máy ảo; đăng nhập/CRUD có quyền, email/GPS/camera production cần tài khoản/thiết bị phù hợp.

Một APK cung cấp ba giao diện theo role trả từ backend. Entry Tin nhắn mở danh bạ/hội thoại riêng, không thêm chat vào tải dashboard để API cũ không làm hỏng các màn chấm công. `core/chat.dart` quản lý SSE Bearer, cursor bigint, dedupe, UUID gửi lại, reconnect/backoff, dừng khi app về nền. Khi phiên hết hạn, route chat được đóng.

`core/message_translation.dart` dùng Google ML Kit native Android; tải mô hình Việt/Anh/Trung sau thao tác Bật dịch, cache bản dịch, tự dịch tin đến. Bản nháp debounce 400 ms với revision chống kết quả cũ. Bản gốc luôn hiển thị và được gửi lên backend. Backend SSE dùng PostgreSQL làm cursor, kiểm tra thay đổi bằng poll 1.5 giây, heartbeat 15 giây; giữ đúng dữ liệu khi chạy nhiều process. Đây là realtime gần tức thời, không phải từng phím gõ hay theo dõi nền.
