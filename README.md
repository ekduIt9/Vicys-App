# Vicys

Nền móng MVP Flutter cho ứng dụng camera, chỉnh ảnh/video, đồng bộ cloud và mạng
xã hội. Ứng dụng chạy local-first với SQLite; Firebase đảm nhiệm Authentication,
Firestore, Storage, Cloud Functions và thông báo FCM.

UI sử dụng hệ thiết kế Obsidian Edit: nền OLED tối, lavender cho trạng thái chủ
động, media-first canvas và điều khiển tập trung trong vùng thao tác một tay.

## Chạy ứng dụng

Yêu cầu Flutter stable với Dart 3.3 trở lên.

```powershell
flutter pub get
flutter run
```

## Cấu hình Firebase

Tạo Firebase project phát triển, sau đó chạy:

```powershell
firebase login
dart pub global activate flutterfire_cli
flutterfire configure
firebase use YOUR_FIREBASE_PROJECT_ID
firebase deploy --only firestore:rules,firestore:indexes,storage,functions
```

Khi chưa cấu hình Firebase, ứng dụng vẫn chạy offline bằng SQLite.
Sau khi `flutterfire configure` tạo file native Android/iOS, bật Firebase bằng:

```powershell
flutter run --dart-define=FIREBASE_ENABLED=true
```

Chạy backend local:

```powershell
cd functions
npm install
npm run build
cd ..
firebase emulators:start
```

Chạy app kết nối emulator Android:

```powershell
flutter run `
  --dart-define=USE_FIREBASE_EMULATORS=true `
  --dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2 `
  --dart-define=FIREBASE_API_KEY=demo-key `
  --dart-define=FIREBASE_APP_ID=1:123:android:demo `
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=123 `
  --dart-define=FIREBASE_PROJECT_ID=demo-vicys
```

Trên iOS Simulator dùng host `127.0.0.1`. Firebase không cung cấp FCM emulator;
push notification thật phải kiểm tra bằng Firebase project phát triển và thiết bị.

## Trạng thái triển khai

- Có: shell ứng dụng, project ảnh/video, SQLite local có migration và sync queue,
  camera chụp ảnh/quay video, nhập nhiều ảnh/video từ thư viện, lưu media bền vững,
  hiệu ứng ảnh GPU không phá hủy (preset, sáng, tương phản, bão hòa, nhiệt độ,
  blur, vignette), autosave, undo/redo, manifest có version, UI editor/timeline,
  Firestore/Storage Rules và FCM Functions.
- Shell Camera–Library–Studio, tìm kiếm project, thumbnail media thật, camera
  filter carousel và timeline video nhiều track.
- Cần tích hợp tiếp: shader/filter, codecs/FFmpeg, preview video hoàn chỉnh,
  render thật, OAuth, storage upload có resume, Firebase repositories, share-link
  server function, moderation dashboard và telemetry.

Sau khi chạy `flutter create .`, thêm vào iOS `Info.plist`:
`NSCameraUsageDescription`, `NSMicrophoneUsageDescription` và
`NSPhotoLibraryUsageDescription`. Android dùng CameraX và system Photo Picker.

## Kiểm tra

```powershell
flutter analyze
flutter test
```

Giới hạn cloud mặc định 2 GB phải được Cloud Function kiểm tra trước upload;
không tin ownership, MIME hoặc kích thước do client gửi.
