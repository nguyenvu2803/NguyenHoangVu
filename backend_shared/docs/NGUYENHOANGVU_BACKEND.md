# Bàn giao backend — Nguyễn Hoàng Vũ, 2380602586

Kiểm tra source và chạy lại ngày **15/11/2026**. Thư mục project: `NguyenHoangVu/backend_shared`. Project Flutter ở `NguyenHoangVu/mobile`. Backend package: `nguyenhoangvu-attendance-api`, bản **1.3.3**.

## Đối chiếu yêu cầu

| Yêu cầu | Backend đã có | Giới hạn |
|---|---|---|
| Đăng ký | Email, mật khẩu scrypt, OTP xác minh, trạng thái pending | Không triển khai OAuth trong bản chọn email |
| Đăng nhập | Username/password + OTP email, JWT 15 phút, refresh 30 ngày xoay vòng, logout/thu hồi | Không chọn SMS; gửi email thật cần cấu hình relay/Brevo |
| Phân quyền | Admin, manager theo chi nhánh, employee theo cá nhân; pending/suspended bị hạn chế | Tài khoản test production cần chủ API cấp quyền hợp lệ |
| CRUD | Nhân viên, chi nhánh, ca; đơn điều chỉnh, bàn giao có quyền và lịch sử | Dữ liệu đã có lịch sử bị khóa kế hoạch/xóa để đối soát |
| Khuôn mặt | YuNet/SFace thật, đăng ký/xóa mẫu, mặt + OTP, mặt + khóa thiết bị không OTP | 2D chưa có liveness; không tương đương Face ID phần cứng |
| Định vị | Chấm công đúng bán kính/độ chính xác/cửa sổ giờ; chia sẻ có TTL, dừng, phân quyền xem | Không theo dõi nền; GPS test không thay GPS điện thoại thật |
| Chat realtime | PostgreSQL, SSE, cursor bigint, UUID chống gửi trùng, kiểm tra quyền/phiên khi stream | Dịch do ML Kit trong Flutter; phiên dịch trên app public vẫn chưa nghiệm thu |
| Hồ sơ | Xem/sửa tên, điện thoại, giới thiệu; cấm tự đổi quyền/email/chi nhánh | Cỡ chữ/màu nền/camera gương là phần Flutter lưu trên thiết bị |
| Báo cáo | Dashboard, báo cáo tháng, thời gian gốc và thời gian sau điều chỉnh | CSV/Nhịp cân bằng được xử lý bởi Flutter từ dữ liệu API |
| Swagger | UI public `/docs/`, OpenAPI 3.1, Authorize Bearer, tài liệu toàn bộ route nghiệp vụ | Muốn URL Render có Swagger phải deploy bản này |
| PostgreSQL/deploy | 6 migration có checksum/advisory lock, bootstrap admin, TLS DB, graceful shutdown, Render/Dockerfile | Source local không chứng minh dịch vụ public đã cập nhật |

Email thay OAuth và OTP email thay SMS đúng nhánh lựa chọn của đề. QR chỉ là tiện ích chọn ca phía mobile, không tự chứng minh hiện diện. Backend luôn xác minh nhân viên, vị trí và giờ.

## Cấu trúc cần bàn giao

- `src/`: Express, xác thực/quyền, CRUD, GPS, face engine, chat, hồ sơ, FCM tùy chọn, Swagger/OpenAPI.
- `migrations/001` đến `006`: lược đồ và lịch sử nâng cấp; giữ nguyên checksum.
- `test/`, `test-support/`: regression, model mặt thật, mail relay VM, pg-mem.
- `tool/verify-postgres.js`: kiểm tra PostgreSQL thật, schema riêng, dọn sau kiểm tra.
- `tool/fetch-face-models.js`: tải model đúng nguồn/hash; model không đưa vào Git/ZIP source.
- `tool/apps-script/`: source email relay HTTPS ký HMAC; không xin quyền đọc Gmail.
- `package.json`, `package-lock.json`: dependency được khóa; Node.js >=22.
- `.env.example`, `render.yaml`, `Dockerfile`: cấu hình/deploy; không chứa secret thật.
- `README.md`, `INTEGRATION_NGUYENHOANGVU.md`, `docs/`: cách chạy, nguồn, phạm vi và giới hạn.

## Cấu hình bắt buộc

1. Cài Node.js 22+; khuyến nghị Node.js 24.
2. Chạy `ONNXRUNTIME_NODE_INSTALL=skip npm ci` và `npm run models:fetch`.
3. Chạy `node tool/setup-env.js`; mở `.env` riêng trên máy.
4. Điền PostgreSQL `DATABASE_URL`; production giữ `DATABASE_SSL=true`, xác minh TLS. Giữ hai secret JWT/OTP khác nhau, mỗi khóa ít nhất 32 ký tự.
5. Chọn email relay Apps Script hoặc Brevo và cấu hình gửi thật. Không có chế độ hiện OTP ra log/màn hình để bỏ qua email.
6. Điền `BOOTSTRAP_ADMIN_*` cho lần khởi động đầu. `npm start` chạy migration và tạo admin chỉ khi chưa có. Sau khi tạo, xóa biến bootstrap khỏi hosting.
7. Deploy Render Free với Root Directory `backend_shared`, build `npm ci && npm run models:fetch`, start `npm start`, health `/v1/health`. Dùng root `render.yaml` của monorepo làm mẫu.
8. Đặt URL HTTPS public + `/v1` vào Flutter `API_BASE_URL`. Localhost chỉ phục vụ kiểm thử trên máy phát triển; APK nộp phải dùng URL Internet.

FCM tùy chọn; thiếu cấu hình thì tắt và báo rõ, không ảnh hưởng email/CRUD/chấm công.

## Mở và thử Swagger

Swagger tài liệu source đã public và kiểm tra hiển thị: https://nguyenvu2803.github.io/NguyenHoangVu/ . Trang này chỉ đọc vì API chung chưa hỗ trợ CORS; không phải bằng chứng đã deploy backend mới lên Render. GitHub Actions `Publish Swagger UI` run `43697941710` đã thành công.

Sau khi backend chạy/deploy, truy cập `/docs/` trên cùng host API. `/v1` chuyển hướng đến trang này. Tài liệu không cần đăng nhập, endpoint nghiệp vụ vẫn yêu cầu quyền.

1. `GET /health` → Try it out → Execute: xác nhận database hoạt động.
2. `POST /auth/login`: nhập tài khoản test thật. Lấy `data.challengeId`.
3. `POST /auth/verify-otp`: nhập challengeId và OTP email; lấy `data.accessToken`.
4. Authorize: chỉ dán accessToken, không thêm chữ Bearer. Thử `GET /me` rồi endpoint theo quyền.

Không đăng công khai mật khẩu, OTP hoặc token. Swagger không lưu token bền và không dùng validator bên ngoài. Gọi cùng host tránh lỗi CORS. Trang Swagger chỉ đọc trên GitHub Pages là tài liệu riêng, không thay deploy API.

## Kiểm chứng ngày 15/11/2026

- **106/106 test Node đạt**, không skip: gồm nhận diện model thật và 3 test Swagger.
- **13/13 kiểm tra PostgreSQL 17 thật đạt**: migration chạy lại an toàn; bootstrap/password/OTP/JWT; Swagger và auth; CRUD; ba vai trò; concurrent check-in có đúng một bản ghi; điều chỉnh giữ giờ gốc; vị trí; chat idempotent/SSE; mặt/khóa thiết bị không gửi OTP và xóa mẫu thu hồi phiên; hồ sơ đọc lại qua kết nối mới; báo cáo tháng; reuse refresh thu hồi phiên.
- Test dùng mailbox riêng, ảnh mẫu chính thức OpenCV và tọa độ test; không gửi email thật, không ghi database production, không chứng minh camera/GPS người dùng thật.
- Docker build thành công. Container Linux chạy migration và server: `/v1` chuyển đến Swagger HTTP 200, OpenAPI 3.1 trả 200, health 200/database ok, `/v1/me` thiếu token trả 401. ONNX CPU Linux trích xuất embedding 128 chiều từ ảnh mẫu thành công.
- API công khai chung do chủ dịch vụ khác vận hành. Thay source tại đây không tự deploy hoặc cấp quyền tài khoản trên dịch vụ đó.
- Google OAuth, SMS OTP và liveness chưa triển khai. Phiên dịch app public chưa hoàn thành; giữ nguyên ghi chú chưa đạt và điểm tự chấm trong `hovaten.txt`.

Log riêng ở `../dist/backend-full-tests.log`, `../dist/backend-postgres-tests.log`. Gói backend được tạo bằng `../scripts/package_backend.py`, loại credential, dependency và model tải về.
