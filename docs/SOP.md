# SOP phát triển Studio Social

## 1. Mục đích và phạm vi

Tài liệu này là quy trình chuẩn khi phân tích, viết, review và phát hành mã nguồn
Studio Social. Mọi thay đổi Flutter, native Android/iOS, Supabase, media pipeline
và UI/UX đều phải tuân theo SOP này.

Thứ tự ưu tiên khi có đánh đổi:

1. Không làm mất hoặc lộ dữ liệu người dùng.
2. UI phản hồi nhanh, không giật và không khóa main isolate.
3. Hành vi dễ hiểu, có trạng thái loading/error/retry rõ ràng.
4. Kiến trúc dễ kiểm thử và thay thế.
5. Tiết kiệm pin, RAM, storage và băng thông.

## 2. Definition of Done

Một thay đổi chỉ hoàn thành khi:

- Có yêu cầu và tiêu chí nghiệm thu cụ thể.
- Không trộn UI, business logic, persistence và network trong cùng function.
- Function xử lý mới hoặc thay đổi có documentation theo mục 5.
- Có trạng thái empty, loading, success, error và retry nếu có I/O.
- Không thực hiện decode, checksum, render hoặc thao tác file nặng trên UI isolate.
- Dữ liệu local-first; mất mạng không làm mất draft.
- Có test tương ứng với mức rủi ro.
- Chạy sạch `dart format`, `flutter analyze` và `flutter test`.
- Thay đổi database có migration tiến, RLS và kiểm thử quyền truy cập.
- Không commit secret, service-role key, media cá nhân hoặc file build.
- Đã kiểm tra accessibility, dark theme và kích thước màn hình nhỏ.
- Đã cập nhật SOP/SKILL khi thay đổi quy ước kiến trúc.

## 3. Quy trình thực hiện thay đổi

### 3.1 Khảo sát

1. Đọc `README.md`, `docs/SOP.md` và `.codex/skills/studio-social/SKILL.md`.
2. Tìm model, repository, service và widget liên quan trước khi thêm abstraction.
3. Xác định đường đi của dữ liệu: nguồn → repository/service → state → UI.
4. Ghi nhận ràng buộc về codec, quyền hệ điều hành, dung lượng và trạng thái mạng.
5. Không thêm package nếu SDK hoặc dependency hiện có đã đáp ứng tốt.

### 3.2 Thiết kế

Trước khi code, khóa các điểm sau:

- Input/output và lỗi có thể xảy ra.
- Ownership của file/media và vòng đời tài nguyên.
- Thao tác nào chạy trên UI isolate, background isolate hoặc native thread.
- Dữ liệu nào lưu local, dữ liệu nào đồng bộ và conflict được biểu diễn ra sao.
- Widget nào cần rebuild; tránh state toàn cục cho trạng thái màn hình cục bộ.
- Kế hoạch rollback đối với migration hoặc định dạng project.

### 3.3 Triển khai

1. Thay đổi model/interface trước, implementation sau, UI cuối cùng.
2. Giữ commit logic theo vertical slice nhỏ có thể kiểm thử.
3. Dùng constructor injection cho repository/service; không gọi singleton backend
   trực tiếp từ widget.
4. Luôn đóng stream, timer, controller, subscription và native resource.
5. Thêm cancellation cho render, upload, download hoặc tác vụ kéo dài.
6. Duy trì backward compatibility cho project manifest bằng `schemaVersion`.
7. Không ghi đè phiên bản cloud khi revision bằng nhau nhưng nội dung khác nhau;
   tạo trạng thái conflict và giữ cả hai bản.

### 3.4 Xác minh

Chạy theo thứ tự:

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Với thay đổi UI/media, kiểm tra thêm trên thiết bị thật:

- Android tầm trung và iPhone thấp nhất còn được hỗ trợ.
- Cold start, mở project lớn, scrub timeline, undo/redo và export.
- Mất mạng giữa upload; đóng ứng dụng giữa autosave; thiếu dung lượng khi render.
- Từ chối quyền camera/microphone/photos rồi cấp lại.
- App background/foreground trong lúc quay, render và upload.

## 4. Kiến trúc bắt buộc

### 4.1 Phân lớp

- `features/`: màn hình, widget và state theo tính năng.
- `core/`: model thuần, lỗi dùng chung, config và utility nhỏ.
- `data/`: repository implementation, local database, Supabase và mapper.
- `services/`: camera, render, sync, share và tác vụ nền.
- Native plugin: chỉ chứa khả năng cần CameraX, AVFoundation, GPU hoặc codec.

UI chỉ phụ thuộc interface. Repository chịu trách nhiệm lấy/lưu dữ liệu. Service
điều phối tác vụ nghiệp vụ hoặc native dài hạn. Model không import Flutter,
Supabase hoặc plugin nền tảng.

### 4.2 Quy tắc dependency

- Không import feature A trực tiếp vào feature B; dùng interface/core model.
- Không truyền `BuildContext` vào repository hoặc service.
- Không trả raw Supabase response ra ngoài data layer.
- Chuyển lỗi SDK thành sealed/domain error có thông điệp hành động được.
- Không dùng utility class làm nơi chứa business logic không rõ ownership.

### 4.3 Local-first và đồng bộ

- Ghi project vào local trước rồi enqueue đồng bộ.
- Mỗi mutation tăng `revision`, cập nhật `updatedAt` và đánh dấu `queued`.
- Upload media theo checksum; server xác nhận quota và quyền trước signed URL.
- Retry exponential backoff có jitter; không retry lỗi auth/validation vô hạn.
- Queue phải idempotent và khôi phục được sau khi app khởi động lại.
- Xóa local/cloud dùng tombstone trong thời gian grace period trước khi dọn file.

## 5. Chuẩn mô tả function xử lý

### 5.1 Function nào bắt buộc có doc comment

Mọi function/method thuộc một trong các nhóm sau phải có `///`:

- Public API, repository, service và native bridge.
- Xử lý media, file, network, database, sync, auth hoặc permission.
- Có side effect, retry, cache, timeout, cancellation hoặc transaction.
- Có thuật toán, điều kiện biên hoặc quyết định hiệu năng không hiển nhiên.

Widget builder nhỏ, getter hiển nhiên và callback chỉ gọi một method có thể không
cần comment. Không viết comment lặp lại tên hàm.

### 5.2 Nội dung bắt buộc

Doc comment mô tả ngắn gọn:

- Mục đích và kết quả.
- Ý nghĩa input/output khi không hiển nhiên.
- Side effect: ghi file, database, network, state hoặc analytics.
- Lỗi/exception/domain error có thể trả về.
- Thread/isolate và cancellation đối với tác vụ nặng.
- Giới hạn hiệu năng hoặc ownership của resource nếu liên quan.

Ví dụ:

```dart
/// Tạo checksum SHA-256 để khử trùng lặp trước khi upload.
///
/// Đọc file trên background isolate và không sửa file nguồn. Trả về
/// [MediaReadFailure] nếu file biến mất hoặc không còn quyền truy cập.
/// Caller có thể hủy qua [cancelToken]; không giữ toàn bộ file trong RAM.
Future<Result<String, MediaFailure>> checksumMedia(
  File source,
  CancelToken cancelToken,
);
```

Với function private phức tạp, comment giải thích **vì sao** dùng thuật toán hoặc
trade-off, không diễn giải từng dòng lệnh.

### 5.3 Quy tắc kích thước

- Một function nên làm một việc và có tên thể hiện kết quả.
- Mục tiêu dưới 30 dòng logic; tách khi có nhiều mức abstraction hoặc nhánh lỗi.
- Tối đa 4 positional parameters; dùng object có tên cho cấu hình phức tạp.
- Không dùng boolean parameter mơ hồ như `process(true, false)`.
- Function có I/O phải bất đồng bộ; tên không cần hậu tố `Async` trong Dart.

## 6. Hiệu năng

### 6.1 UI

- Mục tiêu 60 fps; frame UI/raster dưới 16,7 ms, ưu tiên 120 fps khi thiết bị hỗ trợ.
- Dùng `const` widget, chia widget nhỏ và giới hạn vùng rebuild.
- Không decode ảnh/video, đọc file, hash, JSON lớn hoặc query network trong `build`.
- Virtualize feed/timeline bằng builder; không dựng toàn bộ item ngoài viewport.
- Cache thumbnail đúng kích thước hiển thị; không đưa ảnh nguyên bản vào grid.
- Debounce autosave/search; throttle scrub/timeline updates theo frame.
- Tránh opacity, clip, blur và saveLayer diện rộng trong animation.
- Giữ gesture phản hồi ngay; công việc nền không được chặn animation.

### 6.2 Media và bộ nhớ

- Preview dùng proxy/thumbnail; render cuối mới đọc media độ phân giải đầy đủ.
- Stream file theo chunk; không gọi `readAsBytes` với video lớn.
- Giới hạn số decoder đồng thời và giải phóng controller ngoài viewport.
- Render, checksum, waveform và thumbnail chạy isolate/native worker.
- Có backpressure và cancellation khi người dùng scrub hoặc đổi project.
- Theo dõi RAM peak, render time, dropped frames, nhiệt độ và dung lượng tạm.

### 6.3 Network và cloud

- Feed phân trang cursor, không offset; prefetch có giới hạn.
- Upload resumable, checksum-idempotent và chỉ khi chính sách mạng cho phép.
- Signed URL ngắn hạn; cache metadata, không log URL chứa token.
- Batch request hợp lý nhưng không trì hoãn tương tác trực tiếp.
- Không tải media bị block, private hoặc ngoài viewport.

## 7. UI/UX và accessibility

- Mỗi thao tác phải có phản hồi trong 100 ms; nếu lâu hơn hiển thị progress.
- Không xóa/hủy render im lặng; thao tác phá hủy cần xác nhận hoặc undo.
- Autosave hiển thị trạng thái: đang lưu, đã lưu, offline, conflict, lỗi.
- Permission phải giải thích lợi ích trước system prompt và có đường dẫn Settings.
- Editor giữ canvas là trọng tâm; công cụ dùng icon kèm label dễ hiểu.
- Touch target tối thiểu 48×48 dp; hỗ trợ text scaling và screen reader.
- Không chỉ dùng màu để truyền đạt trạng thái.
- Giữ draft khi crash, hết dung lượng, mất mạng hoặc đăng xuất.
- Error message gồm vấn đề, dữ liệu có an toàn không và hành động tiếp theo.

## 8. Bảo mật và quyền riêng tư

- Chỉ dùng anon key ở client; service-role key chỉ ở server environment.
- RLS áp dụng cho mọi bảng và kiểm thử cả truy cập trái phép.
- Server tự xác nhận owner, quota, MIME, byte size và trạng thái share link.
- Private bucket mặc định; cấp signed URL sau kiểm tra quyền.
- Không log token, email, caption riêng tư, đường dẫn signed hoặc media bytes.
- Xóa tài khoản dùng job server có audit và dọn object storage.
- Report/moderation không cho client tự đổi trạng thái xử lý.
- Kiểm tra license trước khi đóng gói font, nhạc, sticker, model và FFmpeg.

## 9. Chiến lược kiểm thử

- Unit test: model migration, edit history, sync conflict, retry và validation.
- Widget test: loading/empty/error, editor controls, accessibility và navigation.
- Integration test: capture/import → edit → autosave → export → upload → post.
- RLS test: owner, follower, stranger, blocked user và anonymous.
- Golden test cho UI ổn định; không dùng golden thay cho behavior test.
- Performance test với project lớn và video 10 phút ở 1080p.
- Regression test bắt buộc cho mọi lỗi mất dữ liệu, quyền hoặc privacy.

Tên test mô tả `điều kiện → hành vi mong đợi`. Không mock model thuần; fake tại
ranh giới repository/service để test luồng thực.

## 10. Review checklist

- Function xử lý đã có doc comment đúng mục 5 chưa?
- Có I/O hoặc CPU nặng trên UI isolate không?
- Widget rebuild và media decode có bị khuếch đại theo số item không?
- Tác vụ dài có progress, retry, timeout và cancellation không?
- Mọi controller/subscription/file handle đã được dispose/close chưa?
- Offline, conflict, file mất và thiếu dung lượng được xử lý chưa?
- RLS/server có tự xác minh thay vì tin client không?
- Thay đổi schema/project có migration và backward compatibility không?
- Test có chứng minh tiêu chí nghiệm thu và nhánh lỗi quan trọng không?

Nếu bất kỳ câu trả lời nào là “chưa”, thay đổi chưa đủ điều kiện merge.
