# Kịch bản video demo — Nguyễn Hoàng Vũ, 2380602586

Một APK, ba giao diện: nhân viên/người dùng, quản lý chi nhánh, quản trị viên. Ba chức năng nâng cao chọn nộp: khuôn mặt, định vị, dịch tin nhắn realtime. QR là tiện ích phụ.

Mục tiêu 8–11 phút, quay ứng dụng Flutter Android. Chỉ mô tả kết quả đã thao tác thành công. Không nói “đã test thật” khi đang dùng fixture/demo. Không quay mật khẩu, OTP rõ, token, secret Render hoặc database URL. Video YouTube để Unlisted/Public để giảng viên mở link được.

## Chuẩn bị

- APK production `NguyenHoangVu.apk`, Internet, API public health200.
- Một tài khoản admin hợp lệ và một nhân viên active/emailVerified thuộc chi nhánh test. Nhờ chủ API chung duyệt, không tự nâng quyền.
- Chi nhánh test ở vị trí đang quay và bán kính hợp lý; ca đang trong cửa sổ giờ để vào/ra. Không thay dữ liệu nhân viên thật khác.
- Camera/định vị đã cấp quyền. Máy ảo chỉ chứng minh được phần đang hoạt động; nếu không có nguồn camera/GPS dùng được, ghi rõ giới hạn và quay phần phần cứng sau trên điện thoại thật. Không tắt bảo vệ GPS để tạo bằng chứng giả.
- Chủ API triển khai migration 005–006 và backend mới; health có features.realtimeChat=true, quickFaceLogin=true, selfProfile=true. Dùng hai phiên đăng nhập: một máy ảo và một điện thoại/máy ảo khác, hai tài khoản active có quyền chat.
- Vào Tin nhắn, bấm Bật dịch và tải mô hình trước khi quay; cần Internet/dung lượng. Khi đã tải, dịch chạy trên thiết bị, gửi/nhận vẫn cần mạng.

## Trình tự và lời giới thiệu

1. **00:00–00:30 — Giới thiệu.** “Em Nguyễn Hoàng Vũ, MSSV 2380602586. App NguyenHoangVu viết bằng Flutter để chấm công nhân viên. Backend Node.js/PostgreSQL dùng chung, API HTTPS public.” Hiển thị link API và phản hồi health, rồi mở app.
2. **00:30–01:45 — Đăng ký, đăng nhập, OTP.** Tạo tài khoản bằng email thật; nhận và nhập OTP ngoài vùng quay. Cho thấy màn chờ duyệt. Dùng tài khoản đã được duyệt để đăng nhập username + password + OTP. Nói rõ không cấp token trước OTP.
3. **01:45–03:30 — Phân quyền và CRUD.** Admin mở Quản trị, tạo/sửa/tìm/xóa một chi nhánh trống, một tài khoản test và một ca chưa có lịch sử. Với ca dùng chấm công, giữ lại để bảo vệ lịch sử. Đổi sang quản lý để thấy Đội ngũ trong chi nhánh, rồi nhân viên chỉ thấy ca/báo cáo cá nhân; tài khoản nhân viên không có quyền quản trị.
4. **03:30–04:30 — Chấm công GPS.** Nhân viên chọn ca được phân, nhấn Vào ca với GPS rồi Ra ca. Nói rõ máy chủ kiểm tra người được phân, vị trí/cửa sổ giờ. QR có thể quay thêm như tiện ích chọn ca, không tính trong ba chức năng đã chọn.
5. **04:30–05:30 — Khuôn mặt.** Với API chung hiện tại: đăng nhập mật khẩu + OTP trước. Cài đặt → Thiết lập khuôn mặt → đồng ý → chụp → Dùng ảnh này. Đăng xuất, nhập username, chọn Đăng nhập bằng khuôn mặt → chụp → Dùng ảnh này. APK 1.3.2 vào đúng vai trò khi API trả phiên trực tiếp; chỉ nhập OTP ngoài vùng quay nếu máy chủ yêu cầu. Nói rõ ảnh 2D chưa kiểm tra người thật. Xóa mẫu để ngừng đăng nhập mặt. Luồng khóa thiết bị `/auth/face-unlock` riêng chỉ dùng khi backend công bố quickFaceLogin và thiết bị đã lưu khóa.
6. **05:30–06:15 — Chia sẻ vị trí.** Nhân viên chọn TTL, chia sẻ vị trí. Admin/manager thấy đúng phạm vi; mở bản đồ. Nhân viên dừng chia sẻ, tải lại ở quản lý để thấy đã dừng. Nói không chạy theo dõi nền.
7. **06:15–07:45 — Dịch tin nhắn realtime.** Hai tài khoản active mở hội thoại. Máy A chọn ngôn ngữ viết English, gửi “Please check my shift tomorrow”. Máy B chọn Dịch sang Tiếng Việt, cho thấy tin đến tự xuất hiện và bản dịch bên dưới bản gốc. Gửi trả lời tiếng Việt, máy A dịch sang English. Gõ bản nháp để thấy xem trước đổi theo nội dung; đổi đích sang 中文 nếu cần. Nói đây là dịch máy ML Kit, không bảo đảm đúng mọi ngữ cảnh. Ngắt/bật mạng để quan sát kết nối lại; không dùng nội dung fixture làm bằng chứng API public.
8. **07:45–08:45 — Điều chỉnh và báo cáo.** Tạo đơn điều chỉnh, sửa khi pending, admin khác người tạo duyệt. Cho thấy giờ hiệu lực và giờ thiết bị gốc được giữ; báo cáo theo tháng và xuất CSV.
9. **08:45–09:30 — Tính năng đề xuất.** Mở Nhịp cân bằng: nghỉ dưới 11 giờ, ca trên 10 giờ, thiếu công. Nói đây là đề xuất cá nhân hỗ trợ xem lịch; chưa có khảo sát chứng minh mọi app khác chưa có tính năng tương tự.
10. **09:30–10:00 — Kết thúc.** Hiển thị link GitHub frontend/backend, API và `hovaten.txt`. Nói rõ phần đã làm/đã nghiệm thu và phần còn giới hạn, không đọc điểm dự kiến thành điểm được giảng viên chấm.

Sau khi tải video lên YouTube, mở thử link ở cửa sổ chưa đăng nhập; cập nhật cùng URL vào `hovaten.txt` và `docs/NOP_BAI.md`. Không điền URL video giả.

## Máy ảo đang chuẩn bị trên máy này

AVD `NguyenHoangVu_QA` dùng Android 13/API 33, khung Pixel 6, màn hình 1080×2400, host OpenGL. APK production đã cài và xác thực OTP email thật. Tài khoản đang chờ admin; sau khi được duyệt, nhấn **Kiểm tra trạng thái duyệt** để vào app. Không dùng AVD Android 36 cũ đang gặp lỗi System UI.

Camera mặc định của AVD là ảnh mô phỏng. Để quay khuôn mặt người dùng hoặc quét QR bằng webcam, cần đóng máy ảo sau khi đã giữ thông tin đăng nhập riêng rồi mở lại với camera thật của máy tính. Lần mở lại app yêu cầu đăng nhập/OTP lại. Trên macOS, kiểm tra tên webcam trước:

```sh
"$HOME/Library/Android/sdk/emulator/emulator" -webcam-list
```

Nếu có `webcam0`, chạy:

```sh
"$HOME/Library/Android/sdk/emulator/emulator" -avd NguyenHoangVu_QA -gpu host -feature -Vulkan -no-snapshot -camera-front webcam0 -camera-back webcam0
```

Chủ máy tự cho phép quyền camera nếu macOS hỏi. Chưa nghiệm thu webcam ở phiên máy ảo hiện tại; không đọc khuôn mặt fixture thành bằng chứng camera người dùng thật. GPS máy ảo cũng là dữ liệu vị trí mô phỏng; nói rõ trong video. Không tắt kiểm tra `isMocked` của APK production để làm video trông như GPS điện thoại thật. Nếu app từ chối nguồn vị trí/camera của máy ảo, phần đó cần nghiệm thu trên thiết bị có nguồn hợp lệ.

Mật khẩu tài khoản được tạo ngẫu nhiên và giữ riêng trên máy, ngoài gói nộp/Git. Không quay file thông tin tài khoản hoặc mã OTP.

## Quay Cài đặt bản 1.3

Mở bánh răng Cài đặt. Chọn chữ Lớn/Rất lớn và nền Xanh trời; quay thay đổi ngay. Sửa họ tên, điện thoại, giới thiệu → Lưu hồ sơ; đóng/mở lại để xác nhận. Bật/tắt Camera đối xứng và xem trước ảnh. Không nhận là lưu hồ sơ thành công khi API còn 404. Chi tiết `SETTINGS_FACE_LOGIN.md`.
