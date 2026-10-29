# API public và phương án miễn phí

APK hiện dùng API đã deploy: **https://nguyen-hoai-nam-2380601398-api.onrender.com/v1**. Không cần tạo VPS, Neon hoặc Brevo mới để kết nối API này. Cần tài khoản ứng dụng được quản trị viên của API chung kích hoạt.

## Kiểm tra API hiện có

```sh
python3 scripts/check_deployment.py
```

Kỳ vọng `/health` 200; `/me`, `/employees`, `/attendance` 401 khi chưa có token. Điều này chứng minh endpoint Internet hoạt động và yêu cầu đăng nhập, chưa chứng minh OTP/email/chấm công của tài khoản cá nhân.

Backend chung do người khác vận hành. Theo tài liệu upstream, PostgreSQL Free hiện tại hết hạn **28/11/2026**; cần chủ dịch vụ xác nhận/gia hạn/di chuyển trước hạn chấm bài nếu cần. Render Free có cold start; app chờ tối đa 90 giây. Không coi URL miễn phí là cam kết hoạt động vĩnh viễn.

## Nếu cần tự quản trị và deploy bản cá nhân

Có thể dùng Render Web Service Free + Neon PostgreSQL Free + Gmail Apps Script HTTPS relay. Không cần VPS hoặc domain riêng. Hạn mức, chính sách xác thực và gói miễn phí có thể thay đổi; xem lại bảng giá trước khi tạo dịch vụ. Chỉ chọn Free, không bật thanh toán hoặc nâng gói tự động.

1. Đưa source repo cá nhân lên GitHub. Dùng `backend_shared`, không dùng FastAPI cũ trong `backend`.
2. Trong Neon tạo project PostgreSQL Free; giữ URL kết nối ở Render Secrets, không đưa vào Flutter/source/chat. Dùng TLS có xác minh chứng chỉ.
3. Dùng source `backend_shared/tool/apps-script/Code.gs` và manifest kèm theo để tạo email relay theo README backend. Chủ Gmail tự cấp quyền gửi thư và cấu hình secret trong Script properties. Không cần Brevo nếu dùng relay này.
4. Render tạo Web Service từ repo, chọn Free. Root Directory `backend_shared`; build `ONNXRUNTIME_NODE_INSTALL=skip npm ci && npm run models:fetch`; start `npm start`; health `/v1/health`. Hoặc dùng root `render.yaml` sau khi kiểm tra các trường.
5. Điền môi trường theo `backend_shared/.env.example`: `DATABASE_URL`, `DATABASE_SSL=true`, hai secret JWT/OTP khác nhau >=32 ký tự, `EMAIL_PROVIDER=apps_script`, URL/secret relay, `TRUST_PROXY=true`, `APP_TIME_ZONE=Asia/Ho_Chi_Minh`. Không in secret trong log.
6. Đặt `BOOTSTRAP_ADMIN_FULL_NAME`, username, email nhận OTP thật và mật khẩu riêng cho admin đầu tiên. Bootstrap chỉ chạy khi database chưa có admin; không được dùng để chiếm quyền API chung. Xóa biến bootstrap sau khi đăng nhập thành công.
7. Chờ Render Live, chạy script smoke với URL **kết thúc `/v1`**. Thử đăng ký/OTP/email thật, quyền, CRUD, ca, chấm công, mặt và chia sẻ vị trí. Xác nhận dữ liệu còn sau restart.
8. Điền URL HTTPS mới vào `mobile/config/production.json`; giữ 3 cờ false. Build lại bằng `bash scripts/build_android.sh`. APK cũ không tự đổi endpoint.

Bản chỉnh cục bộ chưa được đưa lên Render chung. Không thay đổi cấu hình/tài khoản của chủ API chung. Nếu dùng chung, nhờ admin duyệt tài khoản; nếu muốn tự quản trị, dùng dịch vụ cá nhân và database riêng.
