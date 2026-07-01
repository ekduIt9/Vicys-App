# Studio Social

Nền móng MVP Flutter cho ứng dụng camera, chỉnh ảnh/video, đồng bộ cloud và mạng
xã hội. Bản hiện tại chạy offline với dữ liệu demo và cung cấp project schema,
autosave, undo/redo, conflict detection, giao diện bốn module và schema Supabase
có Row Level Security.

## Chạy ứng dụng

Yêu cầu Flutter stable với Dart 3.3 trở lên.

```powershell
flutter pub get
flutter run
```

Để bật Supabase:

```powershell
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

Không đưa service-role key vào ứng dụng. Chạy migration
`supabase/migrations/0001_initial_schema.sql` bằng Supabase CLI hoặc dashboard.

## Trạng thái triển khai

- Có: shell ứng dụng, project ảnh/video, lưu local, autosave, undo/redo, manifest
  có version, conflict marker, UI editor/timeline, export giả lập, feed/profile demo,
  schema social/cloud và RLS.
- Cần tích hợp tiếp: camera native, shader/filter, codecs/FFmpeg, chọn media,
  render thật, OAuth, storage upload có resume, Supabase repositories, share-link
  server function, moderation dashboard và telemetry.

## Kiểm tra

```powershell
flutter analyze
flutter test
```

Giới hạn cloud mặc định 2 GB phải được thực thi bằng server function trước khi
cấp signed upload URL; không tin kích thước file do client gửi.
