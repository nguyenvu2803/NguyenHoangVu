# Kiến trúc bản mobile tích hợp

`Flutter Android` gọi HTTPS public `/v1` tới `Express Node.js`, server dùng PostgreSQL, HTTPS mail relay và YuNet/SFace CPU. Ảnh mặt chỉ gửi sau thao tác đồng ý; vị trí chỉ gửi sau người dùng chọn. Secret chỉ nằm backend.

`main.dart` chuyển AuthScreen, AccountWaiting hoặc LiveShell dựa trên user trả từ server. LiveShell có tổng quan, ca cá nhân, đơn điều chỉnh, quản trị/báo cáo theo vai trò và hồ sơ. Frontend không tự cấp quyền.

`core/api.dart` unwrap envelope, Bearer access token, hợp nhất refresh đồng thời và xử lý 401 trễ. POST timeout không tự retry. `core/live.dart` đọc dữ liệu schema thật, tạo/kiểm tra QR chọn ca, kiểm tra ảnh và phân tích Nhịp cân bằng.

Backend `backend_shared/` là nguồn dùng chung được ghi rõ tại INTEGRATION_NGUYENHOANGVU.md. `backend/` và Docker Compose cũ không phục vụ APK production này. Mỗi bản cài dùng cùng URL public để chia sẻ dữ liệu; dữ liệu local demo không đồng bộ server.

Kiểm thử được tách theo bằng chứng: Flutter với HTTP fixture; Express/SQL với pg-mem, mailbox và model thật; HTTP public không token; APK native trên máy ảo; đăng nhập/CRUD có quyền, email/GPS/camera production cần tài khoản/thiết bị phù hợp.
