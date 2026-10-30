# Cài đặt và đăng nhập khuôn mặt — 1.3.1+5

## API đang dùng: khuôn mặt + OTP

APK tiếp tục dùng `https://nguyen-hoai-nam-2380601398-api.onrender.com/v1`, theo yêu cầu dùng lại API chung. Health chưa công bố `features.quickFaceLogin`; app không chặn đăng ký mặt vì thiếu tính năng này.

1. Đăng nhập bằng mật khẩu và OTP email với tài khoản active.
2. Cài đặt → Thiết lập khuôn mặt → đọc xác nhận **Đăng ký khuôn mặt và OTP email?** → chụp → Dùng ảnh này. App gửi `{imageBase64}` qua HTTPS, không gửi trường mới `enableQuickLogin` đến API cũ.
3. Đăng xuất. Nhập tên đăng nhập đã đăng ký mặt → Đăng nhập bằng khuôn mặt → chụp → Dùng ảnh này.
4. Máy chủ đối chiếu mặt rồi gửi OTP email. Nhập OTP để đăng nhập; không cần mật khẩu ở bước này.

Camera vẫn đối xứng mặc định, có xem lại ảnh trước khi gửi. Chỉ tự động dùng `/auth/face-unlock` khi máy chủ công bố hỗ trợ và thiết bị có khóa đã lưu cho đúng tài khoản. Khóa cũ không khiến app gọi endpoint chưa được triển khai.

API cũ chưa hỗ trợ lưu hồ sơ mới và chat realtime của bản tích hợp. Không coi bản vá tương thích khuôn mặt là đã triển khai các chức năng đó hoặc đã bỏ OTP.

## Khi backend đã cập nhật: chỉ quét mặt trên thiết bị đã thiết lập

1. Đăng nhập bằng tên đăng nhập, mật khẩu và OTP email. Tài khoản phải được kích hoạt.
2. Mở biểu tượng bánh răng **Cài đặt**, hoặc **Hồ sơ → Mở Cài đặt**.
3. Chọn **Thiết lập khuôn mặt**, đọc giới hạn, đồng ý gửi ảnh qua HTTPS. Camera trước mở mặc định; máy không có camera trước dùng camera còn lại.
4. Chọn **Chụp khuôn mặt**, xem ảnh rồi **Dùng ảnh này**. Chỉ khi máy chủ đăng ký thành công và khóa thiết bị được lưu mới hoàn tất.
5. Đăng xuất hoặc đóng/mở ứng dụng. Chọn **Đăng nhập bằng khuôn mặt**, chụp và xác nhận ảnh. Không cần nhập lại tên đăng nhập, mật khẩu hay OTP trên thiết bị đã thiết lập.
6. Khuôn mặt không khớp, thiết bị chưa đăng ký hoặc khóa bị thu hồi: dùng mật khẩu + OTP. Không tự chuyển sang dữ liệu demo.

Nhận diện ảnh 2D YuNet/SFace chưa có kiểm tra người thật; có thể bị giả mạo bằng ảnh. Không tương đương Face ID phần cứng. Người dùng phải chấp nhận giới hạn trước khi bật mở khóa không OTP.

## Cỡ chữ, màu nền, hồ sơ

- Cỡ chữ 85%, 100%, 115%, 130%; nhân với cỡ chữ hệ thống.
- Bốn màu nền: lá nhạt, cát ấm, xanh trời, hồng nhạt; áp dụng toàn ứng dụng.
- Camera đối xứng mặc định bật; xem trước và ảnh xác nhận cùng chế độ gương. Có thể tắt trong Cài đặt hoặc lúc chụp.
- Tùy chọn giao diện lưu trên thiết bị, giữ khi mở lại ứng dụng. Lưu thất bại phải báo lỗi.
- Hồ sơ sửa họ tên, điện thoại, giới thiệu; lưu qua `PATCH /v1/me`. Không cho tự đổi email, tên đăng nhập, quyền, chi nhánh hay trạng thái.

## Backend và khóa thiết bị

- Áp dụng thêm migration `006_face_settings.sql`; giữ nguyên migration 001–005.
- `GET /v1/health`: `features.quickFaceLogin=true`, `features.selfProfile=true`.
- `POST /v1/face/enroll`: `{imageBase64, enableQuickLogin:true}`. Chỉ phiên xác thực mật khẩu + OTP được thiết lập/cập nhật mẫu. Phiên cũ trước migration cần đăng nhập lại.
- Máy chủ trả `deviceKey` ngẫu nhiên 256 bit đúng một lần; DB chỉ giữ SHA-256. Flutter lưu trong Android secure storage, tách theo URL API.
- Một mẫu/khóa thiết bị hiện hành mỗi tài khoản. Thiết lập lại thay khóa cũ và thu hồi phiên mở bằng khóa cũ. Muốn dùng thiết bị khác cần đăng nhập mật khẩu + OTP và thiết lập lại.
- `POST /v1/auth/face-unlock`: `{username,deviceKey,imageBase64}`. Cả khóa thiết bị và mặt phải khớp; tài khoản phải active, email đã xác thực. Trả access/refresh token trực tiếp, không gửi OTP. Giới hạn 10 yêu cầu/15 phút/IP trên mỗi tiến trình, ngoài giới hạn auth chung.
- Giữ `/auth/face-login` cũ với mặt + OTP để tương thích. Không đổi hợp đồng cũ thành tự bỏ OTP.
- Xóa mẫu thu hồi các phiên `face_device`. Đổi mật khẩu/email hoặc khóa tài khoản qua admin cũng vô hiệu khóa thiết bị.
- Đăng xuất thu hồi phiên hiện tại, giữ thiết lập khuôn mặt để lần sau mở lại. Xóa mẫu trong Cài đặt khi không muốn tiếp tục dùng.
- Camera không lưu ảnh vào thư viện; xóa file chụp tạm sau xử lý. DB lưu embedding, không lưu ảnh gốc.

## Triển khai và kiểm tra

Chủ dịch vụ Render cần triển khai source `backend_shared` mới và chạy migration 006. Không cần dịch vụ trả phí mới. API public cũ không tự có tính năng mới khi chỉ cài APK.

```sh
cd backend_shared
npm ci
npm run models:fetch
npm run migrate
npm start
```

Sau deploy: kiểm tra health, đăng nhập mật khẩu/OTP lại, thiết lập mặt trên thiết bị, đăng xuất rồi quét mặt. Thử mặt khác, xóa mẫu và sửa hồ sơ rồi mở lại. Không dùng ảnh fixture thay nghiệm thu camera người dùng thật.

OTP: app dùng HTTP Date của máy chủ và thời gian đơn điệu cho bộ đếm; đồng hồ điện thoại không còn chặn gửi mã. Máy chủ vẫn kiểm tra TTL 10 phút, tối đa 5 lần sai và chỉ dùng một lần.
