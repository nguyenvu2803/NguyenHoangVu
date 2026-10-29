# Kịch bản nghiệm thu và thuyết trình cá nhân

## Chuẩn bị trước buổi trình bày

- Backend đã deploy HTTPS, health check production qua; Brevo (hoặc SMTP trên hosting cho phép), Google OAuth và Twilio đã cấu hình nếu trình bày SMS.
- APK build với `DEMO_MODE=false` và URL thật. Không dùng APK demo để chứng minh API đã deploy.
- Hai thiết bị hoặc một điện thoại và một màn hình admin hiển thị QR.
- Tài khoản admin và nhân viên dùng email nhận OTP được; điện thoại nhân viên được phân ca hôm nay.
- Chi nhánh đặt GPS đúng nơi trình bày, không dùng tọa độ mặc định Sài Gòn nếu nhóm ở nơi khác.
- Để trình bày mục khuôn mặt: iPhone hỗ trợ Face ID, đã đăng ký Face ID và build ứng dụng iOS. Vân tay Android chỉ minh họa thêm, không tự coi là đã trình bày Face ID.

## Kịch bản 10–12 phút

| Thời gian | Người trình bày | Nội dung |
|---|---|---|
| 0:00–1:00 | Nguyễn Hoàng Vũ | Bài toán chấm công, tên NguyenHoangVu, Flutter, một API HTTPS cho cả nhóm |
| 1:00–3:00 | Nguyễn Hoàng Vũ | Đăng ký email → nhận OTP → vào trang khách hàng; Google OAuth với email chưa có tài khoản |
| 3:00–4:00 | Nguyễn Hoàng Vũ | Admin đăng nhập password + email OTP/SMS OTP; cấp quyền nhân viên và phân ca |
| 4:00–6:00 | Nguyễn Hoàng Vũ | CRUD chi nhánh, ca, nhân viên và phân ca; chỉ ra chặn xóa dữ liệu còn tham chiếu |
| 6:00–8:00 | Nguyễn Hoàng Vũ | Chia sẻ vị trí chủ động, admin xem vị trí; dừng chia sẻ; quét QR + GPS để vào/ra ca |
| 8:00–9:00 | Nguyễn Hoàng Vũ | Bật Face ID sau OTP → khóa app → Face ID mở phiên; đăng xuất thu hồi phiên thiết bị |
| 9:00–10:00 | Nguyễn Hoàng Vũ | Nhân viên tạo/sửa/xóa đơn pending, admin duyệt/từ chối; không tự duyệt đơn |
| 10:00–11:00 | Nguyễn Hoàng Vũ | Nhịp cân bằng, gợi ý nghỉ theo giờ tuần; bảng công và xuất CSV |
| 11:00–12:00 | Nguyễn Hoàng Vũ | Hai máy dùng cùng API, thử sai quyền/GPS ngoài phạm vi/QR hết hạn; chốt kiểm thử |

## Giải thích tính năng đề xuất

**Nhịp cân bằng:** từ dữ liệu vào/ra ca và thời gian nghỉ, tổng hợp số giờ tuần, số phút làm vượt 8 giờ/ngày và đưa gợi ý nghỉ bù hoặc xem lại lịch. Tính toán có thể giải thích được, không cần dịch vụ AI trả phí.

Không khẳng định thị trường chưa có tính năng tương tự. Khi trình bày, nêu đây là điểm bổ sung cho app nhóm xây dựng và đối chiếu với các app tham khảo nhóm thực tế đã khảo sát.

## Bộ ca nghiệm thu thủ công

| ID | Thao tác | Kết quả cần đạt |
|---|---|---|
| AUTH-01 | Đăng ký email mới | Nhận OTP thật; không đăng nhập trước xác minh |
| AUTH-02 | OTP sai 5 lần rồi nhập mã đúng | Challenge bị khóa, yêu cầu mã mới |
| AUTH-03 | Đăng nhập email/password sai | Không nhận access token |
| AUTH-04 | Chọn SMS với số E.164 đã cấu hình | Nhận và xác minh OTP thật qua Twilio |
| AUTH-05 | Google OAuth, user mới | Callback về app, tài khoản customer |
| AUTH-06 | Dùng lại mã callback/refresh token | API từ chối |
| ROLE-01 | Customer mở chức năng nhân viên qua API | 403 dù tự gọi URL |
| ROLE-02 | Nhân viên gọi danh sách nhân sự/admin | 403 |
| CRUD-01 | Admin tạo, đọc, sửa, khóa nhân viên | Hồ sơ cập nhật; tài khoản bị khóa không đăng nhập được |
| CRUD-02 | Tạo/sửa/xóa chi nhánh chưa có ca | Thành công; tọa độ và bán kính được lưu |
| CRUD-03 | Xóa chi nhánh đang có ca | 409, không mất dữ liệu |
| CRUD-04 | Tạo/sửa/xóa ca chưa có tham chiếu | Thành công; ca sai thứ tự giờ bị từ chối |
| CRUD-05 | Phân ca trùng nhân viên/ngày | 409 |
| CRUD-06 | Sửa/xóa phân ca đã chấm công | 409 |
| ATT-01 | Trong vùng GPS, đúng ca, QR còn hạn | Một bản ghi vào ca, giờ server, số phút trễ |
| ATT-02 | Vào ca lần hai | 409, không nhân đôi bảng công |
| ATT-03 | QR cũ quá 45 giây hoặc sai chi nhánh | Từ chối |
| ATT-04 | GPS ngoài bán kính/độ chính xác thấp | Từ chối, thông báo rõ |
| ATT-05 | Từ chối quyền camera/GPS | Hiện lỗi và cách cấp lại; app không crash |
| ATT-06 | Ra ca bằng QR và GPS mới | Ghi giờ ra; ra ca lại bị chặn |
| BIO-01 | Đăng nhập OTP → bật Face ID → khóa → Face ID | Mở phiên khi xác thực thành công |
| BIO-02 | Hủy Face ID/vân tay hoặc dùng web | Không mở phiên; hiện hướng dẫn phù hợp |
| BIO-03 | Đăng xuất rồi thử Face ID | Cần đăng nhập OTP và bật lại |
| LOC-01 | Chia sẻ vị trí | Admin thấy tọa độ hiện tại và thời hạn |
| LOC-02 | Dừng chia sẻ | API admin không còn bản ghi |
| LOC-03 | Qua 1 giờ | API admin không trả vị trí hết hạn |
| LEAVE-01 | Chủ đơn tạo/sửa/xóa pending | Thành công |
| LEAVE-02 | Người khác sửa đơn | 403 |
| LEAVE-03 | Admin tự duyệt đơn của mình | 403 |
| LEAVE-04 | Đơn đã duyệt bị sửa/xóa | 409 |
| LEAVE-05 | Duyệt nghỉ nguyên ngày đã có chấm công | 409, không chặn nhân viên kết thúc ca đang mở |
| INS-01 | Tuần có tổng giờ vượt 40 giờ | Gợi ý xem lại lịch, tải giờ công tối đa 100% |
| INS-02 | Ngày có trên 8 giờ làm, tổng làm thêm >= 120p | Gợi ý trao đổi quản lý để nghỉ bù |
| TEAM-01 | Hai thành viên đăng nhập khác máy | Đọc/ghi cùng DB sau làm mới |
| DEP-01 | Tắt/restart API rồi mở lại | Dữ liệu PostgreSQL vẫn còn |
| DEP-02 | Kiểm tra APK nộp | Tên NguyenHoangVu, API HTTPS thật, DEMO_MODE=false |

Chỉ đánh dấu đạt các ca phần cứng/dịch vụ sau khi thực hiện thật. Kiểm thử giả lập provider ở backend không chứng minh Google, SMTP hay Twilio của nhóm đã cấu hình đúng.

## Chuẩn bị bài cá nhân

Nguyễn Hoàng Vũ trình bày toàn bộ luồng, không cần chia phần cho thành viên khác. Có thể dùng một điện thoại đăng nhập nhân viên và Flutter Web trên máy tính đăng nhập admin để hiển thị QR; cả hai gọi cùng API HTTPS trên Render. Xem [DEPLOY_FREE.md](DEPLOY_FREE.md) cho cấu hình miễn phí và CORS của bản web chạy trên máy tính.
