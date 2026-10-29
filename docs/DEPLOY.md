# Deploy API HTTPS cho NguyenHoangVu

Chưa có tài khoản dịch vụ của bạn nên source chưa gắn URL production. Thực hiện một trong hai cách dưới đây, sau đó build Flutter bằng URL thật. Không dùng URL mẫu làm bằng chứng deploy.

## 1. Chuẩn bị chung

1. Tạo repository Git riêng và đẩy source `NguyenHoangVu` lên GitHub. Giữ nguyên `.gitignore`; kiểm tra không có `.env`, keystore hoặc mật khẩu trong commit.
2. Chọn Neon Free và Brevo Free cho phương án cá nhân không thuê VPS; Google Cloud OAuth và Twilio cấu hình riêng khi cần. Nếu dùng SMTP, hosting phải cho phép cổng STARTTLS 587.
3. Sinh `JWT_SECRET` bằng `python3 -c 'import secrets; print(secrets.token_hex(48))'`. Dùng giá trị mới trên server; không đưa giá trị này vào Flutter.
4. Chọn email admin có thể nhận OTP. Mật khẩu admin ban đầu tối thiểu 14 ký tự. Không dùng tài khoản demo trong production.

## 2. Cách A — Render Free + Neon Free + Brevo Free

**Đồ án cá nhân muốn miễn phí:** làm theo [DEPLOY_FREE.md](DEPLOY_FREE.md). File `render.yaml` hiện chỉ tạo một web service Free, nhận `DATABASE_URL` bên ngoài từ Neon và gửi OTP email qua Brevo HTTPS API. Không còn tạo Render PostgreSQL trả phí trong blueprint.

Các biến riêng của cấu hình miễn phí: `MAIL_PROVIDER=brevo`, `BREVO_API_KEY`, `EMAIL_FROM`, `EMAIL_SENDER_NAME`. Không cần SMTP khi dùng Brevo. Production vẫn bắt buộc PostgreSQL, HTTPS, JWT secret riêng và `SEED_DEMO=false`.

Render Free chặn SMTP cổng 25/465/587. Chỉ chọn `MAIL_PROVIDER=smtp` nếu hosting thực tế cho phép kết nối SMTP, ví dụ VPS phù hợp hoặc gói hosting cho phép. Kiểm tra chi phí trước khi chọn phương án trả phí; không cần mua VPS để dùng phương án Free.

### Nếu cần tạo admin bằng CLI

Trong shell của service có đủ biến môi trường:

```bash
python -m app.manage create-admin --email admin@your-company.vn --name "Quản trị viên"
```

CLI hỏi mật khẩu ẩn, không truyền mật khẩu trong command. Tài khoản mới cần xác minh OTP khi đăng nhập. Dùng bootstrap khi gói hosting không có shell tương tác.

## 3. Cách B — VPS Docker + Caddy

Yêu cầu Ubuntu/VPS có Docker Engine + Compose plugin, domain trỏ DNS A/AAAA đúng IP, mở cổng 80/443. API và PostgreSQL không công khai cổng trực tiếp.

1. Chép project lên VPS. Tạo `.env.production` từ `.env.production.example` ở thư mục gốc.
2. Điền `SITE_DOMAIN`, `PUBLIC_URL`, SMTP, admin và secret. `DB_PASSWORD` nên dùng hex ngẫu nhiên để không phải URL-encode khi ghép connection string.
3. Chạy:

```bash
docker compose --env-file .env.production up -d --build
docker compose --env-file .env.production logs --tail=100 api caddy
```

4. Caddy tự cấp HTTPS nếu DNS đúng và cổng 80/443 truy cập được. Kiểm tra:

```bash
python3 scripts/check_deployment.py https://api.TEN-MIEN-THAT.vn
```

5. Đăng nhập admin bằng OTP, xóa **cả hai** biến bootstrap khỏi `.env.production`, rồi chạy lại `up -d`.

DB nằm trong volume `postgres_data`, không trong container API. Tránh xóa volume khi cập nhật.

Sao lưu trước khi thay schema hoặc cập nhật lớn:

```bash
mkdir -p backups
docker compose --env-file .env.production exec -T db pg_dump -U attendance -d attendance -Fc > backups/attendance.dump
```

Bản v1 tạo schema bằng `create_all` lúc khởi động. Các lần thay đổi cấu trúc DB về sau cần migration có kiểm soát; `create_all` không tự sửa cột cũ. Không chạy `drop_all` trên dữ liệu thật.

## 4. Gửi email OTP: Brevo HTTPS hoặc SMTP

**Trên Render Free:** dùng Brevo theo [DEPLOY_FREE.md](DEPLOY_FREE.md), không dùng SMTP.

**Trên hosting cho phép SMTP:** đặt `MAIL_PROVIDER=smtp`. Ví dụ Gmail: bật xác minh hai bước cho tài khoản dự án, tạo App Password, cấu hình `smtp.gmail.com:587`. Không dùng mật khẩu đăng nhập Gmail thông thường. Có thể dùng SMTP provider khác hỗ trợ STARTTLS và đã xác minh email gửi.

- OTP gồm 6 chữ số, hết hạn sau 5 phút.
- Tối đa 5 lần sai cho mỗi challenge, challenge chỉ dùng một lần.
- OTP SMS chỉ gửi đến số do admin cập nhật, theo định dạng E.164, ví dụ `+84901234567`.
- Provider lỗi trả 503 và không tạo phiên đăng nhập thành công.
- Production không ghi OTP vào log. Chỉ development chưa cấu hình SMTP mới in mã để lập trình viên thử nội bộ.

## 5. Google OAuth 2.0

1. Trong Google Cloud, cấu hình OAuth consent screen và thêm email bạn vào test users nếu ứng dụng đang ở chế độ testing.
2. Tạo OAuth client loại **Web application**. Client secret chỉ ở backend.
3. Authorized redirect URI phải khớp chính xác:

```text
https://API-THAT-CUA-NHOM/auth/google/callback
```

4. Đặt `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `PUBLIC_URL` rồi deploy lại.
5. Android/iOS dùng `MOBILE_CALLBACK=nguyenhoangvu://oauth`; manifest/plist đã khai báo scheme.
6. Ứng dụng tạo verifier ngẫu nhiên, backend ràng buộc mã trao đổi với hash verifier. Callback gửi mã một lần hiệu lực 60 giây, không đưa access/refresh token vào URL.
7. Tài khoản Google mới nhận quyền `customer`; admin cấp `employee` để sử dụng chấm công. Nếu email đã có tài khoản mật khẩu, backend từ chối tự liên kết; đăng nhập bằng mật khẩu + OTP. Bản v1 chưa có màn hình liên kết hai phương thức.

Để dùng OAuth trên Flutter Web, đặt callback về origin HTTPS của web và CORS tương ứng. Một backend v1 chọn một callback cố định cho mỗi môi trường; nên giữ môi trường trình bày mobile riêng khi cần cả web và mobile OAuth. Web demo không cần Google OAuth.

## 6. SMS Twilio

Điền SID/token/số gửi thật trong biến môi trường, bảo đảm Twilio cho phép gửi tới Việt Nam. Trial thường chỉ gửi tới số đã xác minh; phí và hạn mức phụ thuộc tài khoản. Admin thêm điện thoại E.164 vào hồ sơ nhân viên. Chọn SMS ở màn đăng nhập, nhận và nhập OTP thật.

Không có cấu hình Twilio: SMS trả thông báo chưa cấu hình; không dùng mã demo giả cho máy chủ thật.

## 7. Nối Flutter cho cả bạn

```bash
cp mobile/config/production.example.json mobile/config/production.json
```

Sửa thành URL API thật:

```json
{
  "API_BASE_URL": "https://API-DA-DEPLOY-CUA-NHOM",
  "DEMO_MODE": "false",
  "ALLOW_INSECURE_DEV": "false"
}
```

Chia sẻ file này cho các thành viên. File chỉ chứa URL công khai, không có secret.

```bash
cd mobile
flutter pub get
flutter run --dart-define-from-file=config/production.json
```

Build APK bằng script ở README. iOS:

```bash
flutter build ios --release --dart-define-from-file=config/production.json
```

Lệnh iOS cần Xcode và signing đã cấu hình; sau đó archive bằng Xcode để phân phối. Không có IPA dựng sẵn trong project này.

## 8. Khởi tạo dữ liệu thật sau deploy

1. Đăng nhập admin bằng email/password và OTP.
2. Quản lý → Chi nhánh: đặt tọa độ văn phòng thật và bán kính phù hợp.
3. Quản lý → Ca làm: tạo giờ bắt đầu/kết thúc và thời gian nghỉ.
4. Quản lý → Nhân viên: tạo/cấp quyền nhân viên với email thật, số điện thoại nếu dùng SMS.
5. Quản lý → Phân ca: chọn nhân viên, ca và ngày hiện tại.
6. Admin mở QR tại chi nhánh trên một thiết bị/màn hình khác.
7. Nhân viên lấy GPS, quét QR, xác nhận vào ca; làm tương tự khi ra ca.
8. Kiểm tra bảng công, đơn nghỉ, phân quyền và dữ liệu còn tồn tại sau khi restart API.
