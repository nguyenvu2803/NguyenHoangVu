# NguyenHoangVu — Flutter Android

Nguyễn Hoàng Vũ — 2380602586. Bản nộp là ứng dụng di động Flutter, API HTTPS public. Frontend production dùng `live_*.dart` và schema Node.js camelCase; code màn hình demo cũ chỉ mở khi bật riêng `SHOW_DEMO`.

```sh
flutter pub get
cp config/production.example.json config/production.json
flutter run --dart-define-from-file=config/production.json
```

API mẫu: `https://nguyen-hoai-nam-2380601398-api.onrender.com/v1`. Giữ `DEMO_MODE=false`, `SHOW_DEMO=false`, `ALLOW_INSECURE_DEV=false`. Chạy cùng cấu hình trên các máy để dùng chung API. Không thêm secret backend vào Flutter.

```sh
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --release --dart-define-from-file=config/production.json
```

Đăng ký email thật, OTP, chờ admin API chung kích hoạt/gán chi nhánh. Không có admin mặc định. Camera/GPS cần cấp quyền; máy ảo không thay bằng chứng nghiệm thu phần cứng thật. Xem README gốc và `../docs/VERIFICATION.md`.
