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
| Chat danh bạ | GET `/chat/contacts`: đồng nghiệp active cùng chi nhánh hoặc admin |
| Chat lịch sử | GET `/chat/messages?peerId=UUID&limit=50&beforeId=ID` hoặc `afterId=ID`; `{messages,hasMore}`, id bigint chuỗi |
| Chat gửi | POST `/chat/messages`: clientMessageId UUID, recipientId, text 1–2000, sourceLanguage vi/en/zh; 201 mới, 200 gửi lại cùng nội dung, 409 tái dùng UUID sai |
| Chat realtime | GET `/chat/stream?peerId=UUID`, `Authorization: Bearer ...`; SSE ready/messages/session_expired/access_revoked/unavailable; messages chứa latestId, client tải lịch sử |
| Báo cáo | GET `/reports/monthly?month=YYYY-MM` |

Quyền: admin toàn hệ thống, manager trong chi nhánh, employee dữ liệu cá nhân. Pending chỉ đọc `/me`; không mở dashboard. Server luôn kiểm tra quyền, không dựa vào menu frontend.

Mật khẩu 10–128 ký tự; OTP 6 số, hạn 10 phút, tối đa 5 lần sai; refresh xoay một lần. Không phát lại request ghi khi timeout mạng vì máy chủ có thể đã ghi thành công.

QR chỉ chọn ca của người quét, không gọi endpoint `/qr` cũ và không gửi `qr_token`. GPS yêu cầu sai số <=100m và khoảng cách + sai số nằm trong bán kính; giờ server quyết định cửa sổ chấm công.

Source định nghĩa schema chi tiết: `backend_shared/src/resources.js`, `auth.js`, `validation.js`. Module Node.js mới là backend dùng cho bản này; OpenAPI FastAPI cũ ở `docs/legacy/` không áp dụng.

Chat là phần bổ sung trong source, chưa có trên API public cũ. Migration `005_realtime_chat.sql` bổ sung bảng, không sửa migration đã áp dụng. Server kiểm tra cặp người gửi/nhận; admin không đọc được hội thoại giữa hai người khác. Dịch chỉ chạy trên thiết bị, server lưu bản gốc/ngôn ngữ nguồn. SSE kiểm tra lại phiên/quyền mỗi 1.5 giây; mất kết nối client tải phần sau cursor, UUID bảo vệ lần gửi lại sau timeout.

## Bổ sung 1.3 — migration 006

| API | Hợp đồng |
|---|---|
| GET `/face/status` | enrolled, enrolledAt, quickLoginEnabled, canEnrollQuickLogin; không trả khóa/embedding |
| POST `/face/enroll` | imageBase64, enableQuickLogin tùy chọn; phiên password_otp; khi bật trả deviceKey một lần |
| POST `/auth/face-unlock` | username, deviceKey, imageBase64; khớp mặt và khóa thiết bị thì trả token trực tiếp, không OTP |
| PATCH `/me` | fullName, phone, bio; ít nhất một trường; strict schema chặn đổi quyền/email/tài khoản |

`/auth/face-login` cũ vẫn dùng OTP. Khóa thiết bị được băm SHA-256, thay/xóa mẫu thu hồi phiên face_device; reset mật khẩu/email hoặc suspended vô hiệu khóa. Xem SETTINGS_FACE_LOGIN.md.
