# SOP phát triển PulseForge

## Mục tiêu

Xây dựng mobile music workstation offline với nhạc cụ ảo, sequencer, mixer,
mastering và export. Audio phải phản hồi nhanh và không khóa UI.

## Kiến trúc

- `music_models.dart`: model thuần cho note, pattern và mixer.
- `audio_engine.dart`: synthesis, voice ownership và native playback.
- `music_app.dart`: UI/state; không encode PCM trực tiếp.
- PCM, render mix và waveform chạy isolate/native thread.
- Project âm nhạc lưu local trước; cloud chỉ thêm sau khi MVP ổn định.
- Backing track phải được stream-copy vào app storage trước khi phát hoặc lưu.

## Chuẩn audio

- Preview tối thiểu 22.05 kHz/16-bit; export mục tiêu 44.1 kHz/24-bit.
- Dùng voice-pool cố định, tái sử dụng player và đánh dấu voice trước mọi
  `await`; không tạo một native player mới cho mỗi lần chạm.
- Cache sample preview có giới hạn để tránh render lại WAV cho từng lần bấm.
- WAV tạo trong bộ nhớ dùng chế độ phát mặc định tương thích của plugin cho đến
  khi low-latency `BytesSource` được xác minh trên cả Android và iOS.
- Không tạo buffer dài trên UI isolate.
- Clamp mixer input 0–1 và limiter trước output.
- Phản hồi UI dưới 50 ms; audio mục tiêu dưới 20 ms trên thiết bị.
- Không đóng gói sample hoặc preset thiếu giấy phép.
- Backing track dùng một player riêng; nhạc cụ dùng voice pool độc lập để người
  dùng có thể đánh theo trong lúc bài nhạc đang phát.

## UI nhạc cụ

- Piano: beat guide rơi theo đúng số lane bàn phím chạm; không gọi là nhận diện
  nốt khi chưa có pitch/onset analysis.
- Demo luyện piano dùng timeline nốt xác định, có 4 beat đếm vào, chọn bài,
  play/pause/replay và chỉ tính đúng khi bấm đúng lane trong cửa sổ thời gian.
- Guitar: giao diện thân gỗ, nút hợp âm và 6 dây có thể chạm riêng.
- Dubstep: 16 performance pad và step-grid bật/tắt được từng ô.
- Không dùng lại một generic grid cho cả ba nhạc cụ. Toàn bộ workstation khóa
  landscape để ưu tiên nhiều phím, dây và pad có thể chơi trực tiếp.
- Điều hướng chính dùng menu dropdown góc trái AppBar; không dùng bottom
  navigation làm giảm chiều cao vùng chơi nhạc cụ.

## Function

Mọi API và hàm xử lý PCM, file, recording, MIDI, project hoặc export phải có
`///` mô tả input/output, side effect, thread/isolate, lỗi và ownership.

## Xác minh

Chạy format, `flutter analyze`, `flutter test`, sau đó kiểm tra thiết bị thật:
latency, đa chạm, route audio, interruption, background và thermal throttling.
