# RunnerMobile — chuyển luồng runner từ UserWeb

Phiên bản 1.5 — 15/10/2026.

**Chỉ sửa RunnerMobile. Giữ nguyên WebAPI, UserWeb và database. Ưu tiên Android emulator; không build hoặc triển khai Flutter Web trong lần này.**

## 1. Nguồn đối chiếu

Đã đọc các màn hình trong repository RaceDay.UserWeb:

- `src/app/(main_user)/events/[id]/register/page.tsx`: đăng ký 4 bước.
- `src/app/(main_user)/events/[id]/payment/page.tsx`: VietQR, thông tin chuyển khoản, test, quay lại/hủy.
- `src/app/(main_user)/events/[id]/pending/page.tsx`: chờ duyệt và cập nhật trạng thái.
- `src/app/(main_user)/my-registrations/[id]/resubmit/page.tsx`: sửa hồ sơ bị từ chối.
- `src/lib/input-rules.ts`, `src/lib/event-lifecycle.ts`: kiểm tra dữ liệu và lịch giải.

Mobile dùng bố cục một cột, nút chuyển bước ở đáy màn hình. Giữ nghiệp vụ của Web, dùng điều hướng và bộ chọn file/ngày của Flutter.

## 2. Các màn hình

| Màn hình | Hành vi |
| --- | --- |
| Đăng nhập | Chỉ tài khoản Runner/User vào luồng này. |
| Home / Khám phá | Hiện tất cả giải API trả về, mặc định “Tất cả thời gian”; tìm/lọc và hiển thị số lượng đang xem/tổng số. |
| Chi tiết giải | Thông tin giải, BTC, ngày tổ chức, cự ly, giá theo đợt, số suất, điều kiện đăng ký. |
| Bước 1: Chọn cự ly | Chọn cự ly còn suất; có giá tham khảo. Có thể kế thừa lựa chọn từ chi tiết giải. |
| Bước 2: Thông tin cá nhân | Họ tên, email, SĐT, giới tính, ngày sinh, CCCD/CMND; size áo và tên trên BIB tùy chọn. |
| Bước 3: Thông tin y tế | Nhóm máu, bệnh lý, phiếu khám, liên hệ khẩn cấp, quan hệ và chấp nhận trách nhiệm. |
| Bước 4: Thanh toán | Xem lại hồ sơ, phương thức PayOS VietQR và chấp nhận điều khoản thanh toán. Bấm Thanh toán mới gửi tạo đăng ký. |
| VietQR | Hiện QR ngân hàng, chủ tài khoản, số tài khoản, BIN, số tiền và nội dung chuyển khoản có nút sao chép. |
| Chờ BTC duyệt | Sau thanh toán; tự đọc trạng thái mỗi 3 giây khi màn hình đang mở. |
| Đăng ký của tôi / Vé | Tiếp tục thanh toán, xem trạng thái, lý do từ chối, sửa/nộp lại hoặc xem BIB và QR vé. |

Giải đã qua ngày vẫn xuất hiện ở Home nếu không lọc, nhưng không cho tạo đăng ký mới. Đối chiếu ngày kết thúc/ngày tổ chức, trạng thái và cửa sổ đăng ký giống UserWeb; API vẫn quyết định kết quả cuối cùng.

## 3. Quy tắc form theo UserWeb

- Bắt buộc: họ tên, email, SĐT, giới tính, ngày sinh, CCCD/CMND.
- Tuổi 5–100; CCCD/CMND 9 hoặc 12 số; kiểm tra email/SĐT theo các quy tắc nhập hiện có.
- Size áo tùy chọn: XS, S, M, L, XL, XXL. Tên trên BIB tối đa 40 ký tự.
- Nhóm máu và ít nhất một lựa chọn tình trạng sức khỏe là bắt buộc.
- “Không mắc bệnh lý đặc biệt” không chọn cùng bệnh lý khác.
- Nếu chỉ chọn “Không mắc bệnh lý đặc biệt”: phiếu khám tùy chọn. Các trường hợp bệnh lý khác: bắt buộc phiếu khám.
- Phiếu khám PDF/JPG/JPEG/PNG, tối đa 5MB; upload khi gửi hồ sơ. Kiểm tra file ngay khi chọn.
- Bắt buộc tên, SĐT và quan hệ của liên hệ khẩn cấp. SĐT không trùng runner, kể cả khi khác cách viết khoảng trắng/+84.
- Bắt buộc đồng ý trách nhiệm ở bước 3 và điều khoản thanh toán ở bước 4.
- Nộp lại hồ sơ bị từ chối: sửa cá nhân/y tế, giữ cự ly và giá, không tạo thanh toán mới.

**Giới hạn API hiện có:** UserWeb gửi `bibName` và `emergencyRelation`, nhưng DTO backend hiện chưa nhận/lưu/trả lại hai trường này. Mobile giữ UI và gửi giống UserWeb, đồng thời giữ trong bản nháp tại máy trước khi hoàn tất. Không cam kết hai trường được lưu trên server hoặc dùng để in BIB. Khi mở hồ sơ đã lưu từ server, có thể cần chọn lại quan hệ. Không thêm trường backend trong lần này.

## 4. Quay lại, tiếp tục và hủy

- Quay lại giữa các bước giữ thông tin đang nhập.
- Bản nháp được lưu theo tài khoản + giải trên máy khi chuyển bước hoặc bắt đầu thanh toán; không lưu bytes của file chưa upload. Nếu đóng app trước khi upload, cần chọn lại file.
- Quay lại từ VietQR giữ form và đơn chờ, có nút “Tiếp tục thanh toán”.
- Tiếp tục dùng thông tin/số tiền backend đã lưu trong đơn. API hiện có có thể trả lại cùng đơn khi đăng ký lại cùng cự ly; sửa form không tự cập nhật đơn chờ đó. Muốn làm lại hồ sơ: vào thanh toán và hủy đơn trước.
- Hủy thanh toán: kiểm tra trạng thái mới nhất; ở mock gọi hủy payment mock rồi hủy đăng ký. Sau khi thành công xóa bản nháp, trả về bước chọn cự ly với form trống.
- Đơn đã trả tiền không được hủy theo luồng đơn chưa thanh toán.
- Nếu thanh toán đã trả tiền nhưng đăng ký vẫn pending_payment/cancelled: hiển thị cần BTC xử lý, không cho trả tiền lại.
- Trường hợp timeout khi tạo đăng ký: đọc đăng ký hiện có trước khi gửi lại để hạn chế tạo lặp.

## 5. Hai loại QR trong app

**QR thanh toán:** xuất hiện ngay ở màn hình VietQR sau khi tạo checkout. Dữ liệu `qrCode`, tài khoản và nội dung lấy trực tiếp từ API PayOS; app không tự dựng nội dung chuyển khoản. Kiểm tra payment mỗi 3,5 giây khi màn hình đang mở; có nút kiểm tra thủ công và kiểm tra khi app trở lại foreground.

**QR vé + BIB:** nằm ở **Đăng ký của tôi → Chi tiết đăng ký / Vé → Vé tham dự**. Chỉ hiển thị khi backend trả trạng thái confirmed và đủ `bibNumber`/`qrPayload`. Backend hiện có cấp BIB khi BTC duyệt; Mobile vẽ QR từ payload vé đó. Thanh toán thành công mới chuyển sang chờ duyệt, chưa có vé ngay.

Nếu checkout cũ không có QR, Mobile dùng nút mở PayOS ngoài app. Callback HTTP/HTTPS tùy cấu hình PAYMENT_RETURN_URL/PAYMENT_CANCEL_URL; khi chưa cấu hình, giữ fallback endpoint read-only /payment/status có sẵn. Đóng trình duyệt và trở lại app để kiểm tra, không dùng query callback làm bằng chứng đã trả tiền. Không cần chạy Flutter Web để dùng luồng VietQR chính.

## 6. Nút test thanh toán

- “Test thanh toán thành công” chỉ hiện khi API `/payment/status` báo `payOsMode=mock`.
- Đọc lại mode và trạng thái trước khi gọi API mock; khóa thao tác lặp.
- Sau test đọc trạng thái thật từ API, chuyển tới chờ BTC duyệt.
- Không tự đặt paid/confirmed trong app; không tự cấp BIB/QR vé.
- Route mock ở backend hiện chưa tự chặn theo mode; kiểm tra trong Mobile không thay thế kiểm tra ở server. Backend giữ nguyên theo yêu cầu.

## 7. API hiện có được dùng

| Chức năng | Route |
| --- | --- |
| Đăng nhập / prefill | POST /api/v1/iam/auth/login; GET /api/v1/iam/me |
| Danh sách / chi tiết giải | GET /api/v1/event; GET /api/v1/event/{id} |
| Upload phiếu khám | POST /api/v1/event/uploads |
| Tạo đăng ký | POST /api/v1/event/{id}/registrations |
| Danh sách / chi tiết đăng ký | GET /api/v1/event/registrations/mine; GET /api/v1/event/registrations/{id} |
| Sửa và nộp lại | PUT /api/v1/event/registrations/{id}/resubmit |
| Hủy đăng ký | POST /api/v1/event/registrations/{id}/cancel |
| Mode / lịch sử payment | GET /api/v1/payment/status; GET /api/v1/payment/mine |
| Tạo hoặc tiếp tục checkout | POST /api/v1/payment/checkout |
| Kiểm tra thanh toán | POST /api/v1/payment/{id}/sync |
| Test thành công / hủy mock | POST /api/v1/payment/mock-checkout/{id}/pay; POST /api/v1/payment/mock-checkout/{id}/cancel |

Giá tham khảo lấy từ ticketPricing hiện có. Số tiền chính thức lấy Registration.price/Payment.amount; không gửi giá do app tự tính. Không cần thêm canRegister/currentPrice hoặc endpoint mới.

## 8. Chạy trên Android emulator

1. Chạy WebAPI development như hiện tại, cổng 5080.
2. Mobile `.env`: `API_URL=http://10.0.2.2:5080` (10.0.2.2 là máy host đối với Android emulator).
3. Chạy `flutter run -d emulator-5554` từ RunnerMobile; không cần chạy Flutter Web.
4. Đăng nhập runner → chọn giải chưa kết thúc, đang mở và còn suất → điền đủ 4 bước.
5. Màn VietQR → nếu backend ở mock, bấm nút test → chờ BTC duyệt.
6. BTC duyệt qua UserWeb/chức năng organizer hiện có → Mobile tự cập nhật BIB/QR khi đang mở chi tiết đăng ký.
7. Thử quay lại thanh toán để kiểm tra giữ form; thử hủy để kiểm tra form trống; thử hồ sơ bị từ chối để kiểm tra nộp lại.

Nếu Home chỉ còn ít giải sau khi lọc: đặt lại bộ lọc. Mặc định hiện tất cả dữ liệu API, kể cả giải đã qua ngày.

## 9. Kiểm chứng

- Unit/widget tests: 35 kiểm thử đạt, gồm 4 bước, trường bắt buộc, điều kiện phiếu khám, VietQR không mất sau sync, quay lại/hủy, mock/live, nộp lại không trả tiền lần nữa và tự cập nhật vé sau duyệt.
- `flutter analyze --no-pub`: No issues found.
- `flutter build apk --debug --no-pub`: thành công; APK tại `build/app/outputs/flutter-apk/app-debug.apk`. Đã cài lên emulator-5554.
- Đã mở APK trên emulator-5554: phiên đăng nhập được giữ, Home kết nối backend đang chạy và hiển thị “5/5 giải chạy”. API hiện báo payOsMode=mock.
- Build có cảnh báo Kotlin Gradle Plugin cũ về tương thích Flutter tương lai; không ảnh hưởng bản build hiện tại.
- Các test dùng repository/HTTP giả lập theo contract backend hiện có; chưa nghiệm thu chuyển khoản ngân hàng thật.
- Chưa gửi hồ sơ mới hoặc giao dịch thanh toán qua API thật trong lần kiểm tra emulator; luồng đăng ký/thanh toán được kiểm chứng bằng unit/widget tests ở trên.
- Không sửa hoặc chạy migration/test WebAPI. Không sửa UserWeb.
- Các giới hạn backend về giữ suất, hủy link live, đồng thời cấp BIB và phục hồi đăng ký khi payment đã paid giữ nguyên.
