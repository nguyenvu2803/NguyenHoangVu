# Backend dùng với Flutter NguyenHoangVu

Bản tích hợp cho **Nguyễn Hoàng Vũ — 2380602586**. Backend được dùng chung theo đề bài, giữ ghi nhận nguồn tác giả Nguyễn Hoài Nam.

- Upstream: https://github.com/wom-sama/nguyen-hoai-nam-2380601398-api
- Commit nguồn: `263421e0db595cd72f3df472f2c7e8b20f89b691`.
- Gói `API_CHO_AI_NHOM_8.zip` cung cấp hợp đồng API/Postman, không chứa source backend hoặc tài khoản đã cấp.
- API đang sử dụng: `https://nguyen-hoai-nam-2380601398-api.onrender.com/v1`.
- Source thư mục này được đưa vào repository cá nhân để chạy lại cùng frontend. README upstream giữ thông tin và kết quả do tác giả gốc báo cáo; kết quả kiểm tra của bản cá nhân nằm tại `../docs/VERIFICATION.md`.

## Điều chỉnh bản cá nhân

- Mẫu môi trường dùng tên Nguyễn Hoàng Vũ, nhãn email NguyenHoangVu và múi giờ `Asia/Ho_Chi_Minh`.
- Ghim ONNX Runtime Node `1.20.1` thay `1.31.1`: gói mới không có binary `darwin/x64`, khiến nhận diện trả 503 trên máy Mac Intel hiện tại. Bản CPU được kiểm tra lại bằng model YuNet/SFace thật; thay đổi này không tự cập nhật dịch vụ Render chung.
- Tăng thời gian tải model từ 120 lên 300 giây, giữ kiểm tra SHA256/kích thước và tải nguyên tử.
- Root `render.yaml` triển khai đúng Node.js tại `backend_shared`, không còn trỏ tới FastAPI cũ.
- CI chạy bộ kiểm thử Node.js, tải model đã ghim phiên bản, build APK Flutter dùng HTTPS.
- Bổ sung phép thử Dart API client gọi Express thật qua fixture server chỉ bind loopback với pg-mem/mailbox riêng. Runner bắt buộc `NODE_ENV=test`, không dùng database production, không có endpoint lấy OTP ngoài mạng.
- Flutter dùng camelCase, UUID, `/v1`, OTP email, phiên access/refresh, admin/manager/employee đúng hợp đồng. API client không phát lại POST khi timeout.

Các chỉnh sửa cục bộ **chưa được deploy lên API chung**. Không có credential để thay đổi database, quyền quản trị hoặc môi trường của người vận hành API chung. Không tự nâng quyền người tự đăng ký.

## Chạy kiểm thử

```sh
npm ci
npm run models:fetch
npm test
```

Yêu cầu Node.js >=22. Có thể đặt `ONNXRUNTIME_NODE_INSTALL=skip` lúc cài để bỏ GPU CUDA tùy chọn. Model không nằm trong Git/source ZIP; script tải từ OpenCV Zoo và xác minh hash.

Muốn deploy bản riêng, dùng root `render.yaml` và đọc `../docs/DEPLOY_FREE.md`. Không đưa database URL, khóa email, OTP hoặc mật khẩu vào Flutter/Git.
