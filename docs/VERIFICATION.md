# Kết quả kiểm tra — 29/10/2026 21:38 +07

Bản Flutter 1.1.0+2, Android package `vn.nguyenhoangvu.nguyen_hoang_vu`, nhãn `NguyenHoangVu`. Người nộp: **Nguyễn Hoàng Vũ — 2380602586**. Kết quả dưới đây do bản tích hợp này chạy lại, không sao chép kết luận production của tác giả backend gốc.

| Phép kiểm tra | Kết quả và phạm vi |
|---|---|
| Flutter analyze | **No issues found** sau chỉnh sửa tích hợp |
| Flutter test | **22/22 đạt**: API, token, OTP/form/routing, quyền hiển thị, QR, ảnh, CSV, Nhịp cân bằng, bố cục hẹp; HTTP được fixture trong nhóm test này |
| Node.js backend | **91/91 đạt**, Node.js 24.22.1 trên Mac Intel; pg-mem/mailbox riêng; gồm nhận diện YuNet/SFace thật và các regression backend |
| Dart client gọi Express thật | **1/1 đạt** qua `scripts/test_backend_integration.py`; đăng nhập OTP, pending/active, phân quyền, CRUD, chấm công payload GPS, đơn điều chỉnh, vị trí, mặt + OTP, báo cáo/CSV, logout |
| Giới hạn test tích hợp | Express thật, HTTP thật qua loopback **chỉ trong test**, pg-mem và mailbox riêng; tọa độ/ảnh fixture, chưa gửi thư thật, không ghi production |
| Model mặt | Hai file tải từ OpenCV Zoo commit đã ghim; xác minh kích thước/SHA256; ONNX Runtime CPU 1.20.1 nhận dạng/loại mặt khác đạt |
| Dependency production Node | `npm audit --omit=dev --audit-level=high`: **0 vulnerabilities** tại thời điểm kiểm tra |
| API HTTPS Internet | `/v1/health` 200; `/v1/me`, `/v1/employees`, `/v1/attendance` 401 và envelope AUTH_REQUIRED khi không có token |
| Android release APK | **Build thành công**, khoảng 74.1 MB theo Flutter; `dist/NguyenHoangVu.apk`, production config 3 cờ false |
| Máy ảo Android 13/API 33 | AVD riêng `NguyenHoangVu_QA`, 720×1280, host OpenGL; cài APK **Success**, màn đăng nhập native hiển thị được |
| GitHub source public | Đã push `61b5775` lên `nguyenvu2803/NguyenHoangVu`; link thư mục `mobile` và `backend_shared` đều HTTP 200 khi mở không đăng nhập |
| Đăng ký từ APK public | **Đạt đăng ký + OTP email thật**: chủ email xác nhận đã nhập OTP thành công; APK hiển thị “Đã xác thực email.” và trạng thái chờ admin duyệt. Không ghi nhận đã active |
| APK gọi API public | Gửi một lần username không tồn tại/mật khẩu kiểm thử; app nhận thông báo **Thông tin đăng nhập không hợp lệ.** từ API, không tự vào dashboard |
| Giao diện có dữ liệu | Chụp 7 màn tham chiếu bằng HTTP fixture; tool capture **1/1 đạt**. Các ảnh `ui-fixture-*` không phải dữ liệu production |
| Android 36 cũ | Gặp treo màn khởi động/DeadSystemException và System UI; đã dừng, chuyển AVD riêng API 33; không tính là kiểm thử đạt |

## Bằng chứng cục bộ

- `dist/flutter-analyze.log`, `dist/flutter-tests.log`, `dist/backend-tests.log`.
- `dist/client-backend-integration.log`, `dist/backend-audit.json`, `dist/android-build.log`, `dist/public-api-check.log`, `dist/ui-capture.log`.
- `docs/android-production-login.png`: màn login từ APK production trên máy ảo.
- `docs/android-production-invalid-login.png`: phản hồi đăng nhập sai từ API public.
- `docs/ui-fixture-*.png`: tham chiếu thiết kế bằng fixture đã ghi nhãn.

Log/credential riêng không tự đưa vào Git. Source ZIP không chứa node_modules, model, .env, keystore, tài khoản Postman hoặc gói tài liệu API riêng của nhóm.

## Vấn đề đã sửa khi chạy lại

1. API Flutter dùng đúng base `/v1`, camelCase và data/error envelope; form/routing dùng admin/manager/employee, chờ duyệt đúng hợp đồng.
2. ONNX Runtime Node 1.31.1 không chứa binary darwin/x64 trên Mac Intel, gây 503 ở face inference. Ghim 1.20.1 CPU, cập nhật lockfile, chạy lại model và 91 test đều đạt. Không bỏ qua test mặt.
3. Tăng timeout tải model lên 300 giây cho kết nối chậm, giữ xác minh hash và đổi tên file nguyên tử.
4. Thêm mở bản đồ từ vị trí được cấp quyền; kiểm tra tọa độ trước tạo URL, không gửi token/tên/email vào URL bản đồ.
5. Root Render/CI chuyển đúng Node.js backend và APK Android; giữ FastAPI cũ làm tham khảo, không dùng test cũ thay bằng chứng bản mới.
6. Đóng gói loại dependency/model, môi trường bí mật và file riêng. Tool chụp fixture chạy mã render ngoài fake clock để tránh treo.

## Chưa xác nhận trên tài khoản production cá nhân

- Đã đăng ký và xác thực OTP email thật cho tài khoản cá nhân. Tài khoản `hoangvu2380602586` đang pending, APK đã xác nhận màn chờ duyệt. Cần admin API chung chuyển active và gán chi nhánh; không có quyền tự hoàn tất bước duyệt.
- Chưa nghiệm thu CRUD/ba vai trò/chấm công trên dữ liệu production được cấp quyền. Không xóa/sửa dữ liệu chung của người khác để tạo bằng chứng.
- Chưa xác nhận ảnh camera người dùng đăng ký/đăng nhập mặt thật, quét QR camera thật, GPS thật, mở bản đồ/chia sẻ hệ thống trên thiết bị có nguồn dữ liệu phù hợp. Máy ảo không tự chứng minh các mục này.
- Ảnh xác nhận email/chờ duyệt giữ riêng trong `dist/android-email-verified-pending.png` vì chứa email cá nhân; không đưa ảnh này vào Git/gói nộp.
- Test database dùng pg-mem, chưa xác nhận PostgreSQL production transaction/concurrency hay lưu qua restart cho tài khoản cá nhân.
- Sửa backend chỉ có ở source cá nhân, **chưa deploy lên API chung** do chủ khác vận hành. APK đang kết nối URL chung hiện hoạt động.
- Chưa quay/tải video YouTube. Đây là bước chủ bài sẽ thực hiện sau nghiệm thu; không có URL video giả.
- Tính mới của Nhịp cân bằng chưa được khảo sát thị trường/giảng viên xác nhận. Không bảo đảm điểm tối đa chỉ từ source.

API public: https://nguyen-hoai-nam-2380601398-api.onrender.com/v1 . Render Free có cold start; theo tài liệu upstream, database hiện tại hết hạn 28/11/2026. Chủ dịch vụ cần xác nhận tồn tại đến ngày chấm bài.

## Lệnh chạy lại

```sh
python3 scripts/check_deployment.py
cd backend_shared
npm ci
npm run models:fetch
npm test
cd ../mobile
flutter analyze --no-pub
flutter test --no-pub
cd ..
python3 scripts/test_backend_integration.py
bash scripts/build_android.sh
```

Cần Node.js >=22 trên PATH; runner tích hợp chờ cooldown OTP 61 giây có chủ đích và tự dọn server/mailbox test. APK production không dùng endpoint loopback của runner. Build còn cảnh báo plugin KGP từ toolchain; không làm build thất bại. APK ký debug key cho đồ án; chưa ký phát hành Play Store. PowerShell chưa chạy trên Windows.
