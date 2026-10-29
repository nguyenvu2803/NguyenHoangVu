# API và phân quyền

API thật dùng origin HTTPS sau deploy. Swagger tại `/docs` và schema OpenAPI tại `/openapi.json` được FastAPI sinh trực tiếp từ source; đây là tài liệu schema chính xác nhất.

Header với request đã đăng nhập: `Authorization: Bearer <access_token>`.

| Endpoint | Quyền / chức năng |
|---|---|
| `GET /health` | Công khai, kiểm tra API và DB |
| `POST /auth/register` | Công khai; `name`, `email`, `password`, `phone` tùy chọn; gửi OTP, không cấp token ngay |
| `POST /auth/login` | Công khai; `email`, `password`, `channel=email\|sms`; gửi OTP |
| `POST /auth/verify` | Công khai; `challenge_id`, `code`; xác minh OTP, trả token và user |
| `POST /auth/refresh` | `refresh_token`; xoay token một lần |
| `POST /auth/logout` | `refresh_token`; thu hồi phiên thiết bị |
| `GET /auth/google/start?app_challenge=...` | Redirect tới Google; hash SHA-256 hex của verifier ứng dụng |
| `GET /auth/google/callback` | Callback server do Google gọi; kiểm tra state và email đã xác minh |
| `POST /auth/google/exchange` | `code`, `verifier`; đổi mã callback một lần lấy token |
| `GET /me` | Mọi tài khoản đã xác minh |
| `GET, POST /employees` | Admin; danh sách và tạo nhân viên |
| `PUT, DELETE /employees/{id}` | Admin; cập nhật hoặc khóa, không cho tự khóa/hạ quyền |
| `GET /branches` | Admin/employee |
| `POST /branches`, `PUT, DELETE /branches/{id}` | Admin CRUD chi nhánh |
| `GET /shifts` | Admin/employee |
| `POST /shifts`, `PUT, DELETE /shifts/{id}` | Admin CRUD ca |
| `GET /assignments` | Admin xem toàn bộ; employee chỉ xem của mình |
| `POST /assignments`, `PUT, DELETE /assignments/{id}` | Admin phân ca, sửa/xóa khi chưa chấm công |
| `GET /qr/{branch_id}` | Admin; token QR hiệu lực 45 giây |
| `POST /attendance/check-in` | Admin/employee; QR + tọa độ + độ chính xác |
| `POST /attendance/check-out` | Admin/employee; QR + tọa độ + độ chính xác |
| `GET /attendance` | Admin toàn bộ; employee của mình; tối đa 500 bản ghi gần nhất |
| `GET /attendance/export` | Admin; toàn bộ bảng công CSV UTF-8 BOM |
| `GET /leaves` | Admin toàn bộ; employee của mình |
| `POST /leaves` | Tạo đơn của chính mình |
| `PUT, DELETE /leaves/{id}` | Chủ đơn, trạng thái pending |
| `POST /leaves/{id}/decision` | Admin; `status=approved\|rejected`, không tự duyệt |
| `POST /locations/share` | Admin/employee; chủ động chia sẻ trong 1 giờ |
| `DELETE /locations/share` | Dừng chia sẻ vị trí của chính mình |
| `GET /locations` | Admin; chỉ vị trí còn hạn |
| `GET /insights` | Admin/employee; số liệu nhịp làm việc cá nhân |
| `GET /audit` | Admin; 200 thao tác gần nhất |

## Dữ liệu chấm công

```json
{
  "latitude": 10.7769,
  "longitude": 106.7009,
  "accuracy": 10,
  "qr_token": "TOKEN_KY_SO_DO_ADMIN_CAP"
}
```

Giá trị vị trí ở ví dụ chỉ minh họa. Trong app thật, Flutter lấy GPS mới; API kiểm tra với tọa độ chi nhánh do admin cấu hình.

## Mã lỗi

- `400`: OTP sai/hết hạn, quy tắc ngày hoặc ca không phù hợp, GPS ngoài phạm vi, QR hết hạn/không hợp lệ.
- `401`: thiếu/hết hạn access token, refresh token đã dùng hoặc không hợp lệ.
- `403`: sai vai trò, cố sửa đơn người khác hoặc tự duyệt đơn.
- `404`: bản ghi không tồn tại.
- `409`: dữ liệu trùng, còn tham chiếu, chấm công hai lần hoặc đơn đã xử lý.
- `422`: trường nhập sai định dạng hoặc giới hạn.
- `429`: quá nhiều request xác thực.
- `503`: nhà cung cấp OTP/Google chưa cấu hình hoặc đang lỗi.

OTP không xuất hiện trong response. Không đưa refresh token hoặc password hash vào dữ liệu `/me`, `/employees`, bảng công hay CSV.
