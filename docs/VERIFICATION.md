# Kết quả mới — 30/10/2026 — bản 1.3.2+6

Lỗi quan sát được: app mở form OTP với email `null`, hạn `0:00` sau đăng nhập mặt. Source upstream hiện trả `accessToken`, `refreshToken`, `user` trực tiếp từ `/auth/face-login`; app 1.3.1 luôn coi phản hồi là challenge. Bản 1.3.2 chấp nhận phiên trực tiếp, chỉ mở form khi có challenge OTP hợp lệ. Không cần thay mẫu mặt để sửa lỗi xử lý phản hồi này.

| Kiểm tra | Kết quả |
|---|---|
| Flutter analyze | **No issues found** |
| Flutter test | **43/43 đạt**, gồm nhận phiên trực tiếp, nhận challenge OTP và chặn form OTP thiếu dữ liệu; HTTP fixture, không thay nghiệm thu production |
| API | Giữ URL HTTPS chung; đăng nhập mật khẩu/đăng ký vẫn theo luồng OTP. Không cần feature flag `quickFaceLogin` để nhận phiên từ `/auth/face-login` |
| APK release và cài đặt | Build thành công, 124.9 MB; `adb install -r` **Success**, xác nhận versionName **1.3.2** / versionCode **6** trên emulator-5554 |
| Khởi động Android | `am start -W` **Status: ok**, COLD, TotalTime 3336 ms |
| Chưa nghiệm thu | Cần người dùng quét mặt thật lại sau cài APK để xác nhận dashboard và vai trò trên API public. Không công bố đã thành công chỉ từ test fixture |

Log: `dist/face-session-response-analyze.log`, `dist/face-session-response-tests.log`, `dist/face-session-response-release-build.log`. Screenshot lỗi chứa thông tin xác thực được giữ riêng, không đưa vào Git/gói nộp.

Phiên dịch vẫn **chưa thực hiện được** trong bản nộp. `hovaten.txt` tự chấm **7.0/10**, không tính điểm phiên dịch.

---

## Kết quả lịch sử bản 1.3.1+5

Theo yêu cầu dùng lại API chung hôm trước, APK giữ `https://nguyen-hoai-nam-2380601398-api.onrender.com/v1` và hỗ trợ đăng ký mặt với payload cũ `{imageBase64}`. Không yêu cầu migration 006 để đăng ký mặt + OTP. Chỉ gửi `enableQuickLogin:true` khi máy chủ công bố hỗ trợ.

| Kiểm tra | Kết quả |
|---|---|
| Flutter analyze | No issues found |
| Flutter test | **40/40 đạt**; thêm hợp đồng đăng ký mặt cũ/mới, thay/xóa khóa thiết bị, hộp xác nhận mặt + OTP trên API cũ, khóa lưu cũ không gọi face-unlock trên server chưa hỗ trợ |
| API chung | `/v1/health` HTTP 200, status ok, chưa có feature flags mới |
| Route mặt cũ | `POST /v1/auth/face-login` với `{}` trả HTTP 422/VALIDATION_ERROR; endpoint tồn tại và kiểm tra dữ liệu. Không gửi ảnh, mật khẩu hoặc OTP trong phép kiểm tra này |
| APK production | Build release **thành công**, 124.9 MB theo Flutter; versionName 1.3.1/versionCode 5, giữ API chung HTTPS và ba cờ demo/insecure đều false |
| Cài Android | `adb install -r` **Success** trên AVD API33; package đã kiểm tra versionName 1.3.1/versionCode 5 |
| Màn đăng nhập native | Đã thấy màn đăng nhập và nút khuôn mặt trong APK 1.3.1; ảnh `dist/android-legacy-face-login.png`. Lần khởi động lạnh trên máy ảo có timeout rồi giao diện mới hiện; không tính timeout thành đạt tức thì |
| Phạm vi chưa nghiệm thu | Đăng ký/đối chiếu mặt người dùng thật trên API chung cần người dùng chụp ảnh, tài khoản active và OTP email. Không dùng fixture làm bằng chứng production |
| Tính năng cần backend mới | Chỉ quét mặt không OTP, lưu hồ sơ mới và chat realtime chưa được triển khai lên API chung. Camera đối xứng, cỡ chữ, màu nền vẫn chạy trên APK |

Log: `dist/legacy-face-analyze.log`, `dist/legacy-face-tests.log`, `dist/legacy-face-release-build.log`, `dist/legacy-face-release-install.log`. Hướng dẫn dùng API cũ và chế độ backend mới: `SETTINGS_FACE_LOGIN.md`.

---

## Kết quả lịch sử bản 1.3.0+4

Bổ sung Cài đặt, đăng nhập khuôn mặt trên thiết bị đã thiết lập và camera đối xứng. Các kết quả dưới đây là kiểm thử source mới; API public vẫn chưa triển khai chức năng mới.

| Kiểm tra | Kết quả |
|---|---|
| Flutter analyze | No issues found |
| Flutter test | **36/36 đạt**; thêm lưu giao diện, khóa mặt theo API, đăng nhập không OTP, pixel ảnh gương, đồng hồ OTP, form OTP và Cài đặt 320 px/chữ 130%/ba vai trò |
| Node backend | **103/103 đạt**; nhận diện YuNet/SFace thật; mặt/khóa sai không đăng nhập, đăng nhập nhanh không gửi email, thay/xóa mẫu thu hồi phiên, reset mật khẩu vô hiệu khóa, phiên legacy không được đăng ký mới, hồ sơ strict schema cho ba vai trò |
| Dart client → Express thật | **1/1 đạt**, pg-mem/mailbox tách biệt; bổ sung enroll quick → face-unlock → sửa hồ sơ → xóa mẫu/thu hồi phiên; vẫn kiểm tra luồng mặt + OTP cũ |
| Android camera và secure storage | **1/1 đạt** trên AVD API33: plugin camera thật khởi tạo, xem trước và đổi công tắc gương, tùy chọn được lưu/đọc qua secure storage native. Không chụp/lưu/tải lên khuôn mặt người dùng trong test tự động |
| Dọn test Android | Runner báo uninstall Broken pipe ở teardown, nhưng assertions đạt; cần cài APK release lại, không dùng màn test để demo |
| Giao diện Cài đặt | Ảnh `ui-fixture-settings-mobile.png`, fixture rõ phạm vi; không phải hồ sơ production |
| APK release 1.3.0+4 | Build thành công, 124.9 MB theo Flutter; package vn.nguyenhoangvu.nguyen_hoang_vu, versionCode 4, minSdk 24; cấu hình production giữ HTTPS và ba cờ false |
| Cài/chạy release Android | Cài APK **Success**, kiểm tra versionName 1.3.0/versionCode 4; đã thấy màn đăng nhập native, ảnh android-release-1.3-login.png. Cold start lần đầu trên AVD 2 GB có timeout ở am start rồi giao diện lên sau; không tính timeout thành đạt tức thì |
| API public | Health HTTP 200 nhưng `features` chưa có quickFaceLogin/selfProfile/realtimeChat; **chưa deploy** các chức năng mới |
| OTP đồng hồ lệch | Countdown dùng HTTP Date máy chủ + Stopwatch; form không tự từ chối theo giờ máy. Backend vẫn giữ TTL/giới hạn sai/single-use |

Log: `dist/flutter-settings-analyze.log`, `dist/flutter-settings-all-tests.log`, `dist/backend-settings-all-tests.log`, `dist/client-settings-backend-integration.log`, `dist/android-settings-camera-test.log`, `dist/settings-ui-capture.log`, `dist/android-settings-release-build.log`, `dist/android-settings-release-install.log`.

Cần chủ API deploy migration **006** và backend mới; xem `SETTINGS_FACE_LOGIN.md`. Chưa có bằng chứng quét khuôn mặt người dùng thật, cập nhật hồ sơ hoặc đăng nhập không OTP trên API public. Không dùng test cô lập thay nghiệm thu này.

---

## Kết quả lịch sử bản 1.2

# Kết quả kiểm tra — 29/10/2026 — bản 1.2.0

Bản Flutter 1.2.0+3, Android package `vn.nguyenhoangvu.nguyen_hoang_vu`, nhãn `NguyenHoangVu`. Người nộp: **Nguyễn Hoàng Vũ — 2380602586**. Kết quả dưới đây do bản tích hợp này chạy lại, không sao chép kết luận production của tác giả backend gốc.

| Phép kiểm tra | Kết quả và phạm vi |
|---|---|
| Flutter analyze | **No issues found** sau chỉnh sửa tích hợp |
| Flutter test | **30/30 đạt**: chat SSE/cursor/UUID, dịch tự động và bản nháp chống kết quả cũ, API, token, OTP/form/routing, quyền hiển thị, QR, ảnh, CSV, Nhịp cân bằng, bố cục hẹp; HTTP được fixture trong nhóm test này |
| Node.js backend | **100/100 đạt**, Node.js 24.22.1 trên Mac Intel; pg-mem/mailbox riêng; gồm nhận diện YuNet/SFace thật và các regression backend |
| Dart client gọi Express thật | **1/1 đạt** qua `scripts/test_backend_integration.py`; đăng nhập OTP, pending/active, phân quyền, CRUD, chấm công payload GPS, đơn điều chỉnh, vị trí, mặt + OTP, gửi/nhận chat hai client qua SSE, báo cáo/CSV, logout |
| Giới hạn test tích hợp | Express thật, HTTP thật qua loopback **chỉ trong test**, pg-mem và mailbox riêng; tọa độ/ảnh fixture, chưa gửi thư thật, không ghi production |
| Model mặt | Hai file tải từ OpenCV Zoo commit đã ghim; xác minh kích thước/SHA256; ONNX Runtime CPU 1.20.1 nhận dạng/loại mặt khác đạt |
| Dependency production Node | `npm audit --omit=dev --audit-level=high`: **0 vulnerabilities** tại thời điểm kiểm tra |
| API HTTPS Internet | `/v1/health` 200; `/v1/me`, `/v1/employees`, `/v1/attendance` 401 và envelope AUTH_REQUIRED khi không có token |
| Android release APK | **Build thành công**, khoảng 119.9 MB theo Flutter; `dist/NguyenHoangVu.apk`, production config 3 cờ false |
| Máy ảo Android 13/API 33 | AVD riêng `NguyenHoangVu_QA`, 720×1280, host OpenGL; cài APK release 1.2.0+3 **Success**, am start **Status ok**; xác nhận trực quan màn đăng nhập native, ảnh android-production-login.png |
| GitHub Actions trên Ubuntu | **Success** cả hai job trên commit `2b29f8d`: 100 test backend, 30 test Flutter, analyze, Dart–Express và build/upload APK release. Bằng chứng: https://github.com/nguyenvu2803/NguyenHoangVu/actions/runs/40901850254 . Lỗi lint test mới ở run trước đã sửa |
| GitHub source public | Đã push bản chat và sửa test `2b29f8d` lên `nguyenvu2803/NguyenHoangVu`; link thư mục `mobile` và `backend_shared` đều HTTP 200 khi mở không đăng nhập |
| Đăng ký từ APK public | **Đạt đăng ký + OTP email thật**: chủ email xác nhận đã nhập OTP thành công; APK hiển thị “Đã xác thực email.” và trạng thái chờ admin duyệt. Không ghi nhận đã active |
| APK gọi API public | Bản 1.1 trước đó đã gửi một lần username không tồn tại/mật khẩu kiểm thử; app nhận thông báo **Thông tin đăng nhập không hợp lệ.** từ API, không tự vào dashboard |
| Dịch ML Kit Android thật | **1/1 đạt** trên emulator-5554/API33: tải mô hình, Việt→Anh **Hi**, Anh→Việt **Xin chào**, Anh→Trung **你好**. Không mock plugin/mô hình. Lần đầu test kỳ vọng duy nhất Hello nên fail; đã chấp nhận đồng nghĩa Hi và chạy lại đạt |
| Chat backend/SSE | **9/9 đạt**, nằm trong tổng 100: phạm vi chi nhánh, hội thoại riêng, UUID gửi lại, phân trang, hai client mạng thật, logout/hết token/đổi chi nhánh đóng stream |
| Chat API public | **Chưa triển khai**: health public thiếu `features.realtimeChat=true`; `scripts/check_chat_deployment.py` báo chưa deploy. Source/test tách biệt không thay thế bước này |
| Giao diện có dữ liệu | Có 7 màn tham chiếu cũ và một màn chat mobile mới bằng fixture; riêng tool capture chat **1/1 đạt**. Các ảnh `ui-fixture-*` không phải dữ liệu production |
| Android 36 cũ | Gặp treo màn khởi động/DeadSystemException và System UI; đã dừng, chuyển AVD riêng API 33; không tính là kiểm thử đạt |

## Bằng chứng cục bộ

- `dist/flutter-analyze.log`, `dist/flutter-tests.log`, `dist/backend-tests.log`.
- `dist/native-translation-test.log`, `dist/chat-backend-tests.log`, `dist/chat-widget-tests.log`, `dist/chat-ui-capture.log`, `dist/public-chat-check.log`.
- `dist/client-backend-integration.log`, `dist/backend-audit.json`, `dist/android-build.log`, `dist/public-api-check.log`, `dist/ui-capture.log`.
- `docs/android-production-login.png`: màn login từ APK production trên máy ảo.
- `docs/android-production-invalid-login.png`: phản hồi đăng nhập sai từ API public.
- `docs/ui-fixture-chat-mobile.png`: giao diện chat với nội dung/bản dịch fixture, không phải hội thoại production.
- `docs/ui-fixture-*.png`: tham chiếu thiết kế bằng fixture đã ghi nhãn.

Log/credential riêng không tự đưa vào Git. Ba chức năng chọn nộp: **khuôn mặt, định vị, dịch tin nhắn realtime**. Một APK, ba giao diện nhân viên/người dùng, quản lý, admin. QR chỉ là tiện ích phụ.

Source ZIP không chứa node_modules, model, .env, keystore, tài khoản Postman hoặc gói tài liệu API riêng của nhóm.

## Vấn đề đã sửa khi chạy lại

1. API Flutter dùng đúng base `/v1`, camelCase và data/error envelope; form/routing dùng admin/manager/employee, chờ duyệt đúng hợp đồng.
2. ONNX Runtime Node 1.31.1 không chứa binary darwin/x64 trên Mac Intel, gây 503 ở face inference. Ghim 1.20.1 CPU, cập nhật lockfile, chạy lại model và 91 test đều đạt. Không bỏ qua test mặt.
3. Tăng timeout tải model lên 300 giây cho kết nối chậm, giữ xác minh hash và đổi tên file nguyên tử.
4. Thêm mở bản đồ từ vị trí được cấp quyền; kiểm tra tọa độ trước tạo URL, không gửi token/tên/email vào URL bản đồ.
5. Root Render/CI chuyển đúng Node.js backend và APK Android; giữ FastAPI cũ làm tham khảo, không dùng test cũ thay bằng chứng bản mới.
6. Bổ sung chat SSE có kiểm tra phiên/quyền định kỳ, đồng bộ bù bằng cursor bigint và UUID để gửi lại an toàn sau timeout. Sửa cursor ban đầu rỗng thành 0 để không bỏ sót khi nhiều tin đến cùng đợt.
7. ML Kit tải mô hình sau thao tác người dùng, dịch tin đến và debounce 400ms bản nháp; revision loại kết quả cũ. Bản gốc giữ nguyên.
8. Đóng gói loại dependency/model, môi trường bí mật và file riêng. Tool chụp fixture chạy mã render ngoài fake clock để tránh treo.

## Chưa xác nhận trên tài khoản production cá nhân

- Đã đăng ký và xác thực OTP email thật cho tài khoản cá nhân. Tài khoản `hoangvu2380602586` pending ở lần xác nhận gần nhất, APK đã xác nhận màn chờ duyệt. Cần admin API chung chuyển active và gán chi nhánh; không có quyền tự hoàn tất bước duyệt.
- Chưa nghiệm thu CRUD/ba vai trò/chấm công trên dữ liệu production được cấp quyền. Không xóa/sửa dữ liệu chung của người khác để tạo bằng chứng.
- Chưa xác nhận ảnh camera người dùng đăng ký/đăng nhập mặt thật, quét QR camera thật, GPS thật, mở bản đồ/chia sẻ hệ thống trên thiết bị có nguồn dữ liệu phù hợp. Máy ảo không tự chứng minh các mục này.
- Ảnh xác nhận email/chờ duyệt giữ riêng trong `dist/android-email-verified-pending.png` vì chứa email cá nhân; không đưa ảnh này vào Git/gói nộp.
- Test database dùng pg-mem, chưa xác nhận PostgreSQL production transaction/concurrency hay lưu qua restart cho tài khoản cá nhân.
- Sửa backend chỉ có ở source cá nhân, **chưa deploy lên API chung** do chủ khác vận hành. APK đang kết nối URL chung hiện hoạt động.
- Chat mới chưa chạy trên API public: cần chủ dịch vụ triển khai migration 005 và module chat, sau đó hai tài khoản active thử qua APK. Xem DEPLOY_CHAT.md và bản vá trong gói bàn giao.
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
flutter test integration_test/translation_test.dart -d emulator-5554
cd ..
python3 scripts/test_backend_integration.py
bash scripts/build_android.sh
python3 scripts/check_chat_deployment.py
```

Cần Node.js >=22 trên PATH; runner tích hợp chờ cooldown OTP 61 giây có chủ đích và tự dọn server/mailbox test. APK production không dùng endpoint loopback của runner. Build còn cảnh báo plugin KGP từ toolchain; không làm build thất bại. APK ký debug key cho đồ án; chưa ký phát hành Play Store. PowerShell chưa chạy trên Windows.
