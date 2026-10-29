# Hợp đồng API cho Flutter

Base URL: `https://nguyen-hoai-nam-2380601398-api.onrender.com/v1`.

JSON thành công: `{"data": ...}`. JSON lỗi: `{"error":{"code":"...","message":"..."}}`. UUID dạng chuỗi; thuộc tính camelCase; thời gian ISO 8601 có timezone. Token Bearer cho endpoint bảo vệ.

| Nhóm | Endpoint / dữ liệu |
|---|---|
| Đăng ký | POST `/auth/register`: fullName, username, email, password |
| Đăng nhập | POST `/auth/login`: username, password; trả challenge, chưa có token |
| OTP | POST `/auth/verify-otp`: challengeId, code; trả accessToken, refreshToken, user |
| Gửi lại | POST `/auth/resend-otp`: challengeId; cooldown 60s |
| Phiên | POST `/auth/refresh`, `/auth/logout`: refreshToken; GET `/me` |
| Dashboard | GET `/dashboard` |
| Nhân viên / chi nhánh / ca | GET/POST `/employees`, `/branches`, `/shifts`; GET/PATCH/DELETE `/:id` theo quyền |
| Công | GET `/attendance`; POST `/attendance/check-in`, `/attendance/check-out`: shiftId, latitude, longitude, accuracyMeters |
| Điều chỉnh | GET/POST `/corrections`; PATCH/DELETE `/:id`; status và resolutionNote khi duyệt |
| Mặt | GET `/face/status`; POST `/face/enroll`: imageBase64; DELETE `/face/enroll`; POST `/auth/face-login`: username, imageBase64 |
| Vị trí | GET/POST `/location-shares`: latitude, longitude, accuracyMeters, ttlMinutes; DELETE `/:id` chỉ chủ sở hữu |
| Báo cáo | GET `/reports/monthly?month=YYYY-MM` |

Quyền: admin toàn hệ thống, manager trong chi nhánh, employee dữ liệu cá nhân. Pending chỉ đọc `/me`; không mở dashboard. Server luôn kiểm tra quyền, không dựa vào menu frontend.

Mật khẩu 10–128 ký tự; OTP 6 số, hạn 10 phút, tối đa 5 lần sai; refresh xoay một lần. Không phát lại request ghi khi timeout mạng vì máy chủ có thể đã ghi thành công.

QR chỉ chọn ca của người quét, không gọi endpoint `/qr` cũ và không gửi `qr_token`. GPS yêu cầu sai số <=100m và khoảng cách + sai số nằm trong bán kính; giờ server quyết định cửa sổ chấm công.

Source định nghĩa schema chi tiết: `backend_shared/src/resources.js`, `auth.js`, `validation.js`. Module Node.js mới là backend dùng cho bản này; OpenAPI FastAPI cũ ở `docs/legacy/` không áp dụng.
