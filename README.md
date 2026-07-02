# PulseForge

Ứng dụng Flutter sản xuất âm nhạc offline trên Android/iOS.

## Chạy ứng dụng

Yêu cầu Flutter stable với Dart 3.3 trở lên.

```powershell
flutter pub get
flutter run
```

## Trạng thái triển khai

- Piano đa âm tạo âm thanh trực tiếp.
- Nhập MP3/WAV/M4A từ thiết bị và đánh nhạc cụ đồng thời.
- Transport play/pause/seek và beat guide dạng falling lanes.
- Guitar sáu dây và dubstep bass pads.
- Step sequencer 4 track × 16 step.
- BPM thay đổi khi đang phát.
- Mixer piano, guitar, bass/synth, drums và master drive.
- PCM được tạo trên isolate để không khóa UI.

Nhánh `codex/archive-vicys-media-editor` lưu ứng dụng camera/editor cũ.

## Kiểm tra

```powershell
flutter analyze
flutter test
```
