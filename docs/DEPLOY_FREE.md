# Deploy miễn phí cho bài cá nhân NguyenHoangVu

Không cần thuê VPS, mua domain hoặc đưa app lên cửa hàng. Triển khai **backend lên Render Free**, **PostgreSQL lên Neon Free**, **OTP email qua Brevo Free HTTPS API**, sau đó build APK dùng URL thật.

Source đã được sửa cho phương án này. `render.yaml` chỉ tạo một web service `plan: free`, **không tạo database trả phí**. Chưa có tài khoản/credential dịch vụ của bạn nên chưa deploy thật.

## Chi phí và giới hạn

| Phần | Lựa chọn | Điều kiện |
|---|---|---|
| API FastAPI | [Render Free](https://render.com/docs/free) | Ngủ sau 15 phút không có request; lần mở lại có thể chậm khoảng một phút |
| PostgreSQL | [Neon Free](https://neon.com/pricing) | Gói Free theo hạn mức hiện hành, không có hạn dùng 30 ngày như Render Free Postgres |
| OTP email | [Brevo Free](https://www.brevo.com/pricing/) | Hiện công bố tối đa 300 email/ngày sau khi tài khoản được duyệt gửi; phải xác minh người gửi và kích hoạt transactional email |
| URL và HTTPS | Subdomain `*.onrender.com` | Render cấp sẵn, không cần domain riêng cho API |
| APK cài trực tiếp | Flutter build | Miễn phí; không cần Google Play Console |
| Google OAuth | Google Auth Platform | Với đồ án, cấu hình ứng dụng testing và thêm tài khoản trình bày vào test users |
| SMS thật | Twilio | Không được bảo đảm miễn phí; chỉ dùng trial credit nếu tài khoản được cấp và đáp ứng giới hạn, hoặc trả phí |

Thông tin free được đối chiếu ngày 29/10/2026. Chọn **Free** ở từng dịch vụ, giữ trong quota và kiểm tra màn hình plan trước khi tạo. Không cần nâng gói để chạy email OTP bằng cấu hình này. Brevo có thể yêu cầu duyệt tài khoản/kênh transactional và xác minh email hoặc domain theo chính sách của họ; việc có API key chưa chứng minh đã được gửi email.

Nếu giảng viên yêu cầu cả SMS OTP, phương án email miễn phí không tự thay thế yêu cầu đó. Chức năng SMS trong source được giữ lại để cấu hình riêng.

## Bước 1 — Đưa source lên GitHub

1. Đăng nhập [GitHub](https://github.com), tạo repository cho bài cá nhân, ví dụ `NguyenHoangVu`.
2. Đẩy **nội dung thư mục project** lên repository. Ở root repo phải thấy `backend`, `mobile`, `render.yaml` và `README.md`.
3. Giữ `.gitignore`. Không upload `.env`, `.env.production`, DB connection string, API key, keystore hoặc thư mục `.venv`/`build`.

Nếu dùng source ZIP, giải nén và dùng bản mới có `docs/DEPLOY_FREE.md` và `backend/tests/test_delivery.py`.

## Bước 2 — Tạo PostgreSQL Neon Free

1. Đăng nhập [Neon](https://console.neon.tech), chọn **Free**, tạo project `NguyenHoangVu`.
2. Chọn khu vực gần nơi đặt Render nếu có; tạo database theo mặc định.
3. Mở **Connect**, chọn database/role, lấy connection string PostgreSQL. Có thể dùng connection pooling do Neon cung cấp.
4. Giữ nguyên các tham số SSL trong connection string. Ví dụ cấu trúc, không phải credential thật:

```text
postgresql://USER:PASSWORD@HOST/neondb?sslmode=require
```

5. Lưu chuỗi này vào biến môi trường `DATABASE_URL` của Render ở bước 4. Không đưa vào Flutter hoặc GitHub.

Backend tự tạo bảng lần khởi động đầu. Sau này thay cấu trúc DB phải có migration; không xóa DB để cập nhật khi đã có dữ liệu cần giữ.

## Bước 3 — Tạo Brevo Free để gửi OTP thật

1. Đăng ký [Brevo](https://www.brevo.com), giữ **Free**.
2. Hoàn tất thông tin tài khoản và bước duyệt gửi nếu được yêu cầu. Bật quyền gửi **transactional email**, không chỉ tạo chiến dịch marketing.
3. Trong phần **Senders, Domains & Dedicated IPs / Senders**, thêm địa chỉ người gửi do bạn sở hữu, thực hiện xác minh và các yêu cầu xác thực mà Brevo hiển thị. Có thể bắt đầu bằng địa chỉ cá nhân nếu Brevo cho phép; không giả định mọi tài khoản được chấp nhận ngay.
4. Trong **SMTP & API → API Keys**, tạo **API key**. Lấy API key, không lấy SMTP password.
5. Ghi lại hai giá trị để điền trực tiếp vào Render:

```text
BREVO_API_KEY=<API key do Brevo cấp>
EMAIL_FROM=<địa chỉ người gửi đã xác minh>
```

Project gọi `https://api.brevo.com/v3/smtp/email` qua HTTPS cổng 443. Chữ `smtp` trong đường dẫn API không có nghĩa là mở kết nối SMTP; không dùng cổng 587 và không bị giới hạn SMTP của Render Free.

Nếu Brevo từ chối hoặc quota hết, app báo dịch vụ OTP tạm không khả dụng, không tự đổi sang OTP giả hoặc ghi mã vào log production. Xem Transactional Logs trong Brevo để xác nhận thư được chấp nhận/gửi; kiểm tra cả Spam của người nhận.

## Bước 4 — Deploy backend lên Render Free

Có thể chọn **New → Blueprint** với `render.yaml` đã sửa. Cách thủ công dưới đây dễ kiểm tra từng lựa chọn hơn:

1. Đăng nhập [Render Dashboard](https://dashboard.render.com), chọn **New → Web Service**, kết nối repository GitHub.
2. Chọn repo `NguyenHoangVu`, đặt tên service riêng không trùng người khác, ví dụ `nguyenhoangvu-api-MA-SINH-VIEN` bằng chữ thường/số/dấu gạch ngang.
3. Chọn **Root Directory: `backend`**, **Language/Runtime: Docker**, Dockerfile `./Dockerfile`, **Instance Type: Free**, Health Check Path `/health`.
4. Điền biến môi trường sau. Không dùng nguyên các giá trị trong dấu `<...>`:

| Biến | Giá trị |
|---|---|
| `ENVIRONMENT` | `production` |
| `SEED_DEMO` | `false` |
| `DATABASE_URL` | Connection string Neon ở bước 2, giữ SSL |
| `JWT_SECRET` | Chuỗi ngẫu nhiên mới ít nhất 40 ký tự |
| `PUBLIC_URL` | URL HTTPS của service, không có dấu `/` cuối |
| `CORS_ORIGINS` | Có thể đặt cùng URL API nếu chỉ dùng APK; khi dùng Flutter Web phải thêm đúng origin của web |
| `MAIL_PROVIDER` | `brevo` |
| `BREVO_API_KEY` | API key ở bước 3 |
| `EMAIL_FROM` | Email người gửi được Brevo xác minh |
| `EMAIL_SENDER_NAME` | `NguyenHoangVu` |
| `MOBILE_CALLBACK` | `nguyenhoangvu://oauth` |
| `BOOTSTRAP_ADMIN_EMAIL` | Email cá nhân của bạn, có thể nhận OTP |
| `BOOTSTRAP_ADMIN_PASSWORD` | Mật khẩu mới ít nhất 14 ký tự |

Sinh `JWT_SECRET` trên máy bằng Python:

```bash
python3 -c 'import secrets; print(secrets.token_hex(48))'
```

Windows có thể dùng `py -3.11` thay `python3`. Chuỗi sinh ra chỉ điền vào Render, không đưa lên chat hoặc GitHub.

5. Bấm **Create Web Service / Deploy**. Kiểm tra vẫn là gói **Free**, không tạo Render Postgres hoặc chọn instance trả phí.
6. Sau khi service được tạo, sao chép URL HTTPS **thực tế** ở đầu trang Render, cập nhật chính xác `PUBLIC_URL` và `CORS_ORIGINS` nếu giá trị ban đầu khác, lưu và redeploy. Không tự đoán URL nếu Render thêm hậu tố vào tên.
7. Chờ trạng thái **Live**, mở `https://URL-THAT/health`. Cần thấy:

```json
{"status":"ok","service":"NguyenHoangVu","environment":"production"}
```

8. Khi admin đã được tạo và đăng nhập OTP thành công, xóa **cả hai** biến `BOOTSTRAP_ADMIN_EMAIL` và `BOOTSTRAP_ADMIN_PASSWORD`, lưu và redeploy. Không chỉ xóa một biến. Tài khoản admin và mật khẩu hash vẫn nằm trong Neon.

Không cần đặt các biến `SMTP_*` khi `MAIL_PROVIDER=brevo`. Google và Twilio được cấu hình riêng nếu dùng các chức năng đó.

## Bước 5 — Nối URL thật và build APK

Tại thư mục project:

```bash
cp mobile/config/production.example.json mobile/config/production.json
```

Windows PowerShell dùng `Copy-Item`. Sửa `mobile/config/production.json`:

```json
{
  "API_BASE_URL": "https://URL-THAT-CUA-BAN.onrender.com",
  "DEMO_MODE": "false",
  "ALLOW_INSECURE_DEV": "false"
}
```

Build trên macOS/Linux:

```bash
bash scripts/build_android.sh
```

Windows:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build_android.ps1
```

Kết quả là `dist/NguyenHoangVu.apk`. Cài trực tiếp lên điện thoại Android và cho phép cài từ nguồn đã chọn khi hệ điều hành hỏi. APK ký debug phục vụ đồ án/cài thử; không phải bản ký phát hành Play Store.

`NguyenHoangVu-demo.apk` cũ vẫn là bản dữ liệu mẫu, không tự đổi sang server mới. Sau khi có URL thật phải build lại bằng cấu hình production như trên.

## Bước 6 — Đăng nhập và khởi tạo dữ liệu

1. Trước lần mở app đầu tiên hoặc trước buổi chấm bài, mở `/health` trong trình duyệt và đợi server thức dậy. App chờ tối đa 90 giây để thiết lập kết nối khi Render Free khởi động lại; nếu vẫn timeout, đợi health hoạt động rồi thử lại. App không tự gửi lại thao tác ghi dữ liệu khi mất mạng.
2. Đăng nhập admin bằng email và mật khẩu bootstrap, chọn **Email OTP**, nhập mã thật nhận qua Brevo.
3. Quản lý → Chi nhánh: nhập địa chỉ/tọa độ nơi trình bày thật và bán kính chấm công.
4. Tạo ca làm và tài khoản nhân viên, phân ca cho đúng ngày trình bày.
5. Dùng một màn hình admin mở QR; điện thoại nhân viên lấy GPS và quét mã để vào/ra ca.
6. Thử CRUD, đơn nghỉ và sai quyền; kiểm tra log Render/Brevo khi có lỗi. Chỉ điền URL API vào Flutter, không điền secret của backend.

## Trình bày cá nhân với một điện thoại

Không cần mua thêm thiết bị. Dùng điện thoại cho nhân viên và mở cùng source Flutter trên Chrome máy tính cho admin hiển thị QR.

Thêm origin giao diện web vào `CORS_ORIGINS` trên Render, phân tách bằng dấu phẩy:

```text
https://URL-API-THAT.onrender.com,http://localhost:8080,http://127.0.0.1:8080
```

Sau đó chạy trên máy tính:

```bash
cd mobile
flutter run -d chrome --web-port=8080 --dart-define-from-file=config/production.json
```

Admin đăng nhập bằng password + Email OTP. API của cả web và điện thoại vẫn là **URL HTTPS Render**, không phải API localhost. Chỉ giao diện web dùng để trình bày chạy trên máy tính. Thử Google OAuth và sinh trắc học bằng bản mobile; callback Google của môi trường này đang cấu hình về app native.

## Bước 7 — Google OAuth miễn phí cho đồ án

Nếu trình bày Google OAuth, trong [Google Cloud Console](https://console.cloud.google.com/) tạo OAuth client **Web application**, đặt ứng dụng ở chế độ testing và thêm email cá nhân trình bày vào test users.

Đặt redirect URI chính xác:

```text
https://URL-API-THAT/auth/google/callback
```

Điền `GOOGLE_CLIENT_ID` và `GOOGLE_CLIENT_SECRET` vào Render; giữ `MOBILE_CALLBACK=nguyenhoangvu://oauth`. Client secret không đưa vào Flutter.

Dùng email chưa đăng ký mật khẩu để thử đăng ký Google. Bản v1 không tự liên kết hai tài khoản cùng email; nếu đã có tài khoản email/password, dùng password + OTP. Cơ chế này không yêu cầu dùng VPS.

## Kiểm tra sau deploy

```bash
python3 scripts/check_deployment.py https://URL-API-THAT.onrender.com
```

Chỉ URL của bạn sau khi deploy mới là API thật. Health check xác nhận server và DB; tiếp tục kiểm tra OTP thật, đăng ký Google, GPS/camera/sinh trắc học trên điện thoại. Chưa có URL hoặc credential thì không coi deploy đã xong.
