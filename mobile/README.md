# NguyenHoangVu mobile

Ứng dụng Flutter Android/iOS và Flutter Web xem trước.

```bash
flutter pub get
flutter run --dart-define=DEMO_MODE=true
```

Bản kết nối server:

```bash
cp config/production.example.json config/production.json
# Điền API HTTPS thật.
flutter run --dart-define-from-file=config/production.json
```

Xem `../README.md`, `../docs/DEPLOY.md`, `../docs/DEMO.md` để chạy nhóm và nghiệm thu. Không dùng APK demo thay bằng chứng deploy.
