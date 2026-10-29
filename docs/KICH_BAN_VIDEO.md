# Kịch bản video demo — Nguyễn Hoàng Vũ, 2380602586

Mục tiêu 7–10 phút, quay ứng dụng Flutter Android. Chỉ mô tả kết quả đã thao tác thành công. Không nói “đã test thật” khi đang dùng fixture/demo. Không quay mật khẩu, OTP rõ, token, secret Render hoặc database URL. Video YouTube để Unlisted/Public để giảng viên mở link được.

## Chuẩn bị

- APK production `NguyenHoangVu.apk`, Internet, API public health200.
- Một tài khoản admin hợp lệ và một nhân viên active/emailVerified thuộc chi nhánh test. Nhờ chủ API chung duyệt, không tự nâng quyền.
- Chi nhánh test ở vị trí đang quay và bán kính hợp lý; ca đang trong cửa sổ giờ để vào/ra. Không thay dữ liệu nhân viên thật khác.
- Camera/định vị đã cấp quyền. Máy ảo chỉ chứng minh được phần đang hoạt động; nếu không có nguồn camera/GPS dùng được, ghi rõ giới hạn và quay phần phần cứng sau trên điện thoại thật. Không tắt bảo vệ GPS để tạo bằng chứng giả.
- QR ca trên màn hình khác hoặc ảnh in để camera quét; không hiển thị token trong QR.

## Trình tự và lời giới thiệu

1. **00:00–00:30 — Giới thiệu.** “Em Nguyễn Hoàng Vũ, MSSV 2380602586. App NguyenHoangVu viết bằng Flutter để chấm công nhân viên. Backend Node.js/PostgreSQL dùng chung, API HTTPS public.” Hiển thị link API và phản hồi health, rồi mở app.
2. **00:30–01:45 — Đăng ký, đăng nhập, OTP.** Tạo tài khoản bằng email thật; nhận và nhập OTP ngoài vùng quay. Cho thấy màn chờ duyệt. Dùng tài khoản đã được duyệt để đăng nhập username + password + OTP. Nói rõ không cấp token trước OTP.
3. **01:45–03:30 — Phân quyền và CRUD.** Admin mở Quản lý, tạo/sửa/tìm/xóa một chi nhánh trống, một tài khoản test và một ca chưa có lịch sử. Với ca dùng chấm công, giữ lại để bảo vệ lịch sử. Đổi sang nhân viên, chỉ thấy ca/báo cáo cá nhân; tài khoản nhân viên không có quyền quản trị.
4. **03:30–04:30 — QR và chấm công GPS.** Admin/nhân viên mở QR ca, nhân viên quét chọn đúng ca; nhấn Vào ca với GPS rồi Ra ca. Nói rõ QR chọn ca, GPS và máy chủ kiểm tra người được phân, vị trí/cửa sổ giờ. Thử QR sai không được chọn ca.
5. **04:30–05:30 — Khuôn mặt.** Hồ sơ → đăng ký khuôn mặt, đồng ý gửi ảnh. Đăng xuất, nhập username, chọn Đăng nhập bằng khuôn mặt, chụp lại; so khớp xong nhập OTP email. Nói đây là đối chiếu 2D, vẫn cần OTP; không tuyên bố chống mọi hình ảnh giả.
6. **05:30–06:15 — Chia sẻ vị trí.** Nhân viên chọn TTL, chia sẻ vị trí. Admin/manager thấy đúng phạm vi; mở bản đồ. Nhân viên dừng chia sẻ, tải lại ở quản lý để thấy đã dừng. Nói không chạy theo dõi nền.
7. **06:15–07:15 — Điều chỉnh và báo cáo.** Tạo đơn điều chỉnh, sửa khi pending, admin khác người tạo duyệt. Cho thấy giờ hiệu lực và giờ thiết bị gốc được giữ; báo cáo theo tháng và xuất CSV.
8. **07:15–08:00 — Tính năng đề xuất.** Mở Nhịp cân bằng: nghỉ dưới 11 giờ, ca trên 10 giờ, thiếu công. Nói đây là đề xuất cá nhân hỗ trợ xem lịch; chưa có khảo sát chứng minh mọi app khác chưa có tính năng tương tự.
9. **08:00–08:30 — Kết thúc.** Hiển thị link GitHub frontend/backend, API và `hovaten.txt`. Nói rõ phần đã làm/đã nghiệm thu và phần còn giới hạn, không đọc điểm dự kiến thành điểm được giảng viên chấm.

Sau khi tải video lên YouTube, mở thử link ở cửa sổ chưa đăng nhập; cập nhật cùng URL vào `hovaten.txt` và `docs/NOP_BAI.md`. Không điền URL video giả.

## Máy ảo đang chuẩn bị trên máy này

AVD `NguyenHoangVu_QA` dùng Android 13/API 33, màn hình 720×1280, host OpenGL. APK production đã cài và xác thực OTP email thật. Tài khoản đang chờ admin; sau khi được duyệt, nhấn **Kiểm tra trạng thái duyệt** để vào app. Không dùng AVD Android 36 cũ đang gặp lỗi System UI.

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
