# Bảng nghiệm thu bản mobile

Phân biệt code/test đã đạt và kiểm thử tích hợp production còn cần tài khoản. Chi tiết, log và phiên bản tại VERIFICATION.md.

| Chức năng | Bằng chứng đã có | Còn cần nghiệm thu production |
|---|---|---|
| Đăng ký/OTP/đăng nhập | Flutter form/routing + Dart gọi Express thật, mailbox test; APK nhận lỗi đăng nhập sai từ API public | Thư đến email thật, OTP đúng, admin duyệt active |
| Admin/manager/employee | Backend quyền có test; UI fixture 3 vai trò/320px; pending chặn dashboard | Tài khoản được cấp quyền trên API chung |
| CRUD | Express regression + Dart client create/read/update/delete; form gửi camelCase | CRUD dữ liệu test riêng qua APK với admin hợp lệ |
| Chấm công | Backend GPS/window/owner/duplicate; Dart vào/ra và kiểm tra giờ gốc/correction | GPS mới, chi nhánh thật, ca trong cửa sổ, kết quả công production |
| QR | Encode/decode ca được phân, từ chối QR lạ/sai version; màn QR/scanner có code | Camera đọc QR trên máy ảo có nguồn ảnh hoặc điện thoại |
| Khuôn mặt | Model YuNet/SFace CPU thật; API enroll/login/OTP/delete qua Dart client | Người dùng chụp/enroll/login camera trên API chung |
| Chia sẻ vị trí | TTL/phạm vi/dừng ở backend; Dart tạo/đọc/dừng; URL bản đồ được kiểm tra | GPS native, admin thấy đúng dữ liệu thật, mở bản đồ |
| Báo cáo/CSV | Đọc report thật qua Dart/Express; giữ giờ gốc sau correction; CSV escape | Dữ liệu thực, share sheet native |
| Nhịp cân bằng | Unit test ca qua đêm, nghỉ ngắn, ca dài, thiếu giờ; thẻ dashboard fixture | Giảng viên chấp nhận tính mới; dữ liệu thực phù hợp |
| APK/giao diện | Release build, cài Success trên Android13, login thật; ảnh fixture 7 màn | Thao tác đầy đủ tài khoản active, video thật |
| API Internet | HTTPS health200, endpoint bảo vệ401, APK thấy lỗi API | Tài khoản, email và quyền; duy trì dịch vụ đến ngày chấm |

Không đánh dấu hoàn tất chỉ vì có mã nguồn. Không dùng dữ liệu mô phỏng làm bằng chứng nhận OTP/GPS/camera thật.
