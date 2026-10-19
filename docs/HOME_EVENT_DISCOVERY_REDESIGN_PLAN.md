# Kế hoạch thiết kế lại danh sách sự kiện trên Home mobile

Ngày khảo sát: 19/10/2026. Đây là tài liệu bàn giao triển khai; chưa thay đổi mã ứng dụng trong tác vụ lập kế hoạch này.

## 1. Mục tiêu và phạm vi

Người dùng cần thấy sự kiện sớm khi mở Home, tìm/lọc nhanh và đi đến một phần khác của danh sách mà không phải cuộn qua toàn bộ sự kiện.

Phương án triển khai đã đề xuất trong tài liệu:

- Ô tìm kiếm và nút **Bộ lọc** gọn trên cùng; bốn bộ lọc chi tiết chuyển vào modal bottom sheet.
- Bỏ carousel lớn khỏi Home để dành diện tích cho danh sách.
- Thẻ sự kiện dạng hàng, ảnh nhỏ bên trái và thông tin chính bên phải.
- **10 sự kiện/trang**, chuyển trang thay thế nội dung hiện tại; có đi trực tiếp tới trang mong muốn.
- Giữ tìm kiếm, bộ lọc, trang hiện tại và vị trí đọc khi trở về từ chi tiết hoặc đổi tab.
- Giữ nguyên các quy tắc trạng thái đăng ký đã sửa, đặc biệt hạn đóng và trạng thái chưa xác minh.

Chỉ triển khai trong repo RunnerMobile. Không sửa BE, UserWeb, luồng đăng ký/thanh toán/duyệt/BIB, không thay đổi dữ liệu sự kiện hoặc tạo dữ liệu test trên server. Dùng các thành phần Flutter và màu/theme đang có; không thêm dependency chỉ để dựng bộ lọc hoặc phân trang.

## 2. Hiện trạng đã kiểm tra từ mã nguồn

| Thành phần | Hiện trạng | Hệ quả |
| --- | --- | --- |
| `home_screen.dart` | `ListView(children: [...filteredEvents.map(...)])`, không phân trang | Tạo cấu hình widget cho toàn bộ kết quả; danh sách cuộn dài theo số sự kiện |
| `filter_card.dart` | Ô tìm kiếm + 4 dropdown + nút đặt lại luôn hiện | Chiếm nhiều chiều cao trước khi thấy kết quả |
| `banner_carousel.dart` | Cao 220px, có thêm margin; lấy tối đa 3 sự kiện từ `filteredEvents` | Nội dung bị lặp với danh sách, đẩy kết quả xuống; thay đổi theo bộ lọc |
| `event_card.dart` | Ảnh cao 180px, tên, tagline, địa điểm, ngày và nhiều chip | Mỗi thẻ cao; xem một nhóm sự kiện cần cuộn nhiều |
| `HomeController` | Tìm/lọc ở client, sắp xếp ngày tăng dần | Không có page state; sự kiện cũ có thể nằm trước sự kiện sắp diễn ra |
| Refresh Home | `isLoading` thay cả nội dung bằng spinner | Mất trải nghiệm đọc liên tục trong lúc tải lại |
| API danh sách | `GET /api/v1/event` trả một mảng, không có tham số/page metadata | Chưa thể làm phân trang server chỉ bằng cách thêm query ở mobile |
| Vòng đời sự kiện | Tải thêm chi tiết, tối đa 4 yêu cầu đồng thời, cập nhật từng kết quả | Tổng kết quả theo trạng thái có thể tăng/giảm trong lúc xác minh |

Nguồn kiểm tra backend chỉ để xác nhận hợp đồng API:

- `src/Modules/Event/RaceDay.Modules.Event.Api/EventModule.cs`: public GET gửi `ListPublicEventsQuery()` không có tham số phân trang.
- `src/Modules/Event/RaceDay.Modules.Event.Application/Events/Queries/EventQueries.cs`: query trả `IReadOnlyList<RaceEventListItemDto>`.
- Mobile `lib/features/home/data/datasources/event_remote_data_source.dart`: nhận response kiểu `List`.

**Giới hạn phải nói đúng:** phân trang client giảm chiều dài trang và số thẻ dựng/hiển thị, không giảm kích thước phản hồi danh sách hay tổng số yêu cầu chi tiết. Không mô tả thay đổi này là đã giải quyết khả năng mở rộng của backend.

## 3. Thiết kế màn hình đích

### 3.1. Bố cục

Giữ AppBar và NavigationBar hiện tại. Phần thân tab Khám phá:

```text
┌──────────────────────────────────────────┐
│ RaceDay                      tên user  ↪ │  AppBar hiện có
├──────────────────────────────────────────┤
│ [⌕ Tìm tên giải, địa điểm      ×] [☷ 2] │  tìm kiếm + bộ lọc
│ [10km ×] [TP.HCM ×]       Xóa bộ lọc    │  chỉ có khi đang lọc
│ 11–20 / 86 giải phù hợp                 │  tóm tắt kết quả
├──────────────────────────────────────────┤
│ [ảnh]  RaceDay Mobile Test              │
│        29/11/2026 · địa điểm…           │
│        5km · 10km · 21km                │
│        [Đang mở đăng ký]                │
│ ────────────────────────────────────── │
│ [ảnh]  Tên sự kiện tiếp theo…           │  tối đa 10 sự kiện
│        …                               │  chỉ khu vực này cuộn
├──────────────────────────────────────────┤
│ [Trước]       [Trang 2 / 9 ▾]    [Sau] │  pager cố định
├──────────────────────────────────────────┤
│      Khám phá       Đăng ký của tôi     │  NavigationBar hiện có
└──────────────────────────────────────────┘
```

Kích thước tham chiếu ở cỡ chữ hệ thống mặc định:

- Lề ngang 12–16px, khoảng cách giữa các nhóm 8–12px.
- Hàng tìm kiếm cao khoảng 48–56px; nút bộ lọc có vùng chạm tối thiểu 48px.
- Vùng tìm kiếm + chip + tóm tắt hướng tới không quá khoảng 150px; bỏ hàng chip khi không lọc.
- Pager khoảng 48–56px, nằm trên thanh điều hướng, không chồng lên nội dung.
- Ở 360×800, chữ mặc định, không bật bàn phím: phải thấy trọn ít nhất một thẻ ngay khi vào Home.
- Đây là mục tiêu ở cỡ chữ mặc định, không ép chiều cao chữ khi người dùng tăng font.

Implementation ưu tiên `Column` gồm toolbar, chip/tóm tắt, `Expanded` chứa danh sách, rồi pager. Không cần header ghim bằng sliver vì toolbar/pager nằm ngoài vùng cuộn. Bên trong `Expanded`, dùng `RefreshIndicator` + `CustomScrollView`/`SliverList` với builder; empty/error dùng sliver phù hợp để vẫn kéo làm mới được.

### 3.2. Banner

- Gỡ lời gọi `BannerCarousel` khỏi Home trong thiết kế này; không dành một vùng quảng bá khác thay thế.
- Không tự gọi 3 sự kiện đầu danh sách là “nổi bật” vì chưa có dữ liệu chọn sự kiện nổi bật.
- Có thể giữ file widget cũ nếu còn dùng nơi khác. Tìm toàn repo trước khi xóa class/getter/import không còn dùng.

### 3.3. Thẻ sự kiện gọn

- Toàn thẻ mở `EventDetailScreen` như hiện tại. Không thêm nút đăng ký trực tiếp trên Home.
- Ảnh khoảng 88–96px mỗi chiều, bo góc, `BoxFit.cover`; có placeholder khi URL rỗng/lỗi.
- Tên tối đa 2 dòng ở font mặc định; ngày 1–2 dòng; địa điểm tối đa 2 dòng.
- Nếu ngày bắt đầu/kết thúc giống nhau thì chỉ hiển thị một ngày.
- Tối đa 3 cự ly, phần dư ghi `+N`; không dựng một dãy Chip lớn cho tất cả cự ly. Không thêm giá/slot nếu chưa có yêu cầu.
- Bỏ tagline khỏi thẻ danh sách; nội dung đầy đủ vẫn ở trang chi tiết.
- Nhãn trạng thái lấy từ `controller.statusFor(event)`/resolver chung. Cho phép xuống dòng với nhãn dài như “Đang kiểm tra trạng thái”.
- Dùng `ValueKey(event.id)`; không nhận diện thẻ bằng index.
- Với màn hình hẹp/cỡ chữ lớn, cho phần trạng thái xuống dưới toàn hàng hoặc đổi sang bố cục dọc. Không cố định chiều cao thẻ khiến text overflow.
- Giữ giới hạn rộng tổng thể của Home đang có; không thêm grid hai cột trong lượt này.

## 4. Tìm kiếm và bộ lọc

### 4.1. Toolbar tìm kiếm

- Placeholder: `Tìm tên giải, địa điểm`.
- Giữ phạm vi tìm hiện tại: tên, địa điểm, tagline; trim khoảng trắng và không phân biệt hoa/thường. Không âm thầm thêm chuẩn hóa bỏ dấu trong lượt này.
- Debounce 250ms tại lớp giao diện; áp dụng state của controller một lần sau debounce. Không gọi API theo mỗi ký tự.
- Nút xóa search áp dụng ngay, hủy debounce đang chờ và về trang 1.
- Bấm tìm kiếm trên bàn phím: flush debounce, ẩn bàn phím.
- Trước khi mở sheet/chuyển trang/mở chi tiết: flush search đang chờ để không đổi trang bất ngờ 250ms sau đó.
- Dispose phải hủy debounce và `TextEditingController`. Text field đồng bộ khi reset từ bên ngoài, không ghi đè caret trong lúc gõ bình thường.

### 4.2. Bottom sheet bộ lọc

- `showModalBottomSheet`, `isScrollControlled: true`, `SafeArea`; giới hạn cao khoảng 85% màn hình; thân cuộn, footer luôn truy cập được kể cả bàn phím mở.
- Tiêu đề `Bộ lọc sự kiện`, nút đóng; bốn nhóm có nhãn rõ ràng: Cự ly, Địa điểm, Thời gian, Trạng thái.
- Mỗi nhóm chọn một giá trị, giữ các options/ngữ nghĩa hiện có. Dùng chips cho danh sách ngắn; địa điểm nhiều dùng ô chọn mở danh sách có tìm kiếm cục bộ.
- Khi mở, tạo **bản nháp** từ bộ lọc đang áp dụng. Tương tác trong sheet chỉ thay bản nháp.
- Footer: `Đặt lại` và `Áp dụng`. Đặt lại chỉ đưa 4 nhóm trong bản nháp về mặc định. Áp dụng cập nhật cả 4 trường trong một thao tác controller, về trang 1, cuộn đầu danh sách, đóng sheet.
- Đóng bằng X, Back, vuốt hoặc chạm ngoài: bỏ bản nháp. Không thay đổi danh sách.
- Không dùng text search làm trường trong sheet. Áp dụng/đặt lại bộ lọc không xóa từ khóa tìm kiếm.
- Không để 4 setter nối tiếp phát 4 notifications, tính lại 4 lần và reset trang nhiều lần.
- Option năm/địa điểm đang chọn phải tiếp tục hiển thị được khi refresh/detail update làm nó biến mất khỏi dữ liệu. Kết quả có thể là 0; không tự đổi về “Tất cả”. Áp dụng quy tắc này cho cả bản nháp đang mở.

### 4.3. Chip và badge

- Badge trên nút bộ lọc = số nhóm khác mặc định, từ 0 đến 4; không tính từ khóa.
- Chip thể hiện các bộ lọc đã áp dụng; nếu dài dùng một hàng cuộn ngang, có nhãn đầy đủ khi truy cập bằng trợ năng.
- X trên chip xóa riêng nhóm đó, giữ các nhóm khác và từ khóa, về trang 1.
- `Xóa bộ lọc` xóa cả 4 nhóm nhưng giữ từ khóa. Trong trạng thái không có kết quả, cung cấp `Xóa tìm kiếm và bộ lọc` để xóa tất cả.
- Không thêm một bộ lọc trạng thái nhanh độc lập thứ hai gây hai nguồn state. Nhãn “Đang mở” chỉ là cách trình bày của cùng bộ lọc hiện tại nếu cần rút gọn.

## 5. Phân trang và thứ tự kết quả

### 5.1. Mô hình dữ liệu

Giữ `allEvents` và `filteredEvents` với đúng ý nghĩa hiện tại để không phá các test/consumer cũ. Bổ sung:

```dart
static const int pageSize = 10;
int currentPage = 1; // 1-based; empty vẫn giữ internal page = 1
int get totalFiltered => filteredEvents.length;
int get pageCount => (totalFiltered / pageSize).ceil(); // empty = 0
List<EventEntity> get pagedEvents; // slice của filteredEvents, tối đa 10
void setPage(int page);
void applyFilters(HomeFilterSelection selection); // tên kiểu có thể điều chỉnh
void clearFilter(HomeFilterField field);
void clearFilters(); // giữ search
void resetFilters(); // xóa cả search và filter, tương thích hành vi cũ
```

Quy trình bắt buộc: **toàn bộ dữ liệu → lọc → sắp xếp → đếm → clamp trang → cắt trang → render**. Không lấy 10 item trước rồi mới lọc; không dùng chiều dài `pagedEvents` làm tổng kết quả.

- 0 kết quả: `pageCount = 0`, `pagedEvents = []`, hiển thị `0 giải phù hợp`, ẩn pager. Không hiển thị “Trang 1/0”.
- 1–10 kết quả: chỉ 1 trang, ẩn pager để tiết kiệm diện tích.
- 11 trở lên: pager hiện Trước, Trang X/Y, Sau. Disable nút ở biên.
- Bấm Trang X/Y mở dialog nhập số nguyên trong [1, Y], có kiểm tra giá trị và nút Đi tới. Không dựng hàng trăm nút số trang.
- Dải hiển thị tính theo trang thực: ví dụ 23 kết quả, trang 3 => `21–23 / 23 giải phù hợp`.
- Chuyển trang chỉ đổi slice dữ liệu đang có; không gọi lại API và không nối thêm item vào trang cũ.
- Chuyển trang do người dùng đưa vị trí cuộn về đầu danh sách; không cuộn AppBar/toolbar.
- Đổi search/filter về trang 1. Nếu bộ lọc áp dụng thực tế không đổi thì giữ trang và vị trí đọc.

### 5.2. Sắp xếp mặc định

Đặt các giải còn trong thời gian diễn ra/sắp diễn ra trước, các giải đã qua ngày kết thúc phía sau:

1. Nhóm `endDate ?? date` chưa qua ngày hiện tại theo lịch địa phương: ngày bắt đầu tăng dần.
2. Nhóm đã qua ngày kết thúc: ngày bắt đầu giảm dần, giúp tìm giải vừa kết thúc dễ hơn.
3. Ngày không parse được: cuối danh sách.
4. Cùng nhóm/cùng ngày: dùng `id` làm tie-breaker ổn định.

Nhóm thứ tự này dựa trên ngày, không dựa vào việc request xác minh trạng thái trả về nhanh/chậm. Nó không thay đổi nhãn hay quyền đăng ký. Không dùng thứ tự tải mạng hoặc `loading → ready` để đẩy sự kiện lên đầu.

Dùng clock inject sẵn có, chuẩn hóa về ngày địa phương như resolver. Bổ sung test tại giao ngày. Chưa thêm dropdown “Sắp xếp” để giữ giao diện gọn.

### 5.3. Khi dữ liệu thay đổi trong lúc đang xem

- Khi chi tiết xác minh xong, sự kiện có thể vào/ra bộ lọc hoặc đổi ngày: tính lại danh sách và tổng, giữ `currentPage` nếu còn hợp lệ; chỉ clamp xuống trang cuối khi vượt giới hạn.
- Không tự reset về trang 1 hoặc tự cuộn đầu sau mỗi phản hồi chi tiết/timer.
- Nếu đang trang 3 và tổng giảm từ 23 xuống 19, chuyển về trang 2, cập nhật dải đếm. Clamp scroll offset sau layout nếu vượt maxScrollExtent.
- Đây là danh sách cập nhật trực tiếp: thành phần một trang có thể thay đổi khi trạng thái/ngày thay đổi. Không hứa snapshot cố định; không giữ thẻ hết hạn trong bộ lọc Đang mở chỉ để ổn định trang.
- Ưu tiên giữ event đầu vùng nhìn thấy và offset tương đối khi refresh/navigation quay về nếu event còn trong trang. Nếu nó không còn, giữ page rồi clamp offset. Nếu buộc đổi page do clamp, cuộn về đầu page mới.
- Lưu UI state trong vòng đời Home hiện tại, không cần SharedPreferences cho bộ lọc/trang.

## 6. Tải dữ liệu, xác minh trạng thái và refresh

### 6.1. Không làm hỏng quy tắc vòng đời

- Tiếp tục dùng `lib/core/domain/event_lifecycle.dart` cho nhãn và lọc trạng thái. Không quay lại kiểm tra riêng `event.status == registration-open`.
- `loading` và `failed/unknown` không thuộc bộ lọc Đang mở.
- Chưa xác minh: `Đang kiểm tra trạng thái`; lỗi xác minh: `Chưa xác định trạng thái`. Cả hai vẫn mở được chi tiết.
- Giữ null hợp lệ từ detail khác với chưa tải được các trường hạn.
- Giữ giới hạn tổng cộng tối đa 4 detail requests đồng thời, kể cả khi refresh mới xảy ra trong lúc request cũ còn chạy.
- Giữ generation guard, timer tại mốc thời gian, pause/resume/dispose. Không thêm polling mạng định kỳ cho Home.
- Lượt này giữ cơ chế xác minh toàn bộ sự kiện đủ điều kiện hiện có. **Không chỉ xác minh 10 item đang hiển thị**: làm vậy sẽ khiến lọc Đang mở bỏ sót sự kiện chưa được xem ở trang khác.
- Lỗi một detail không làm mất cả danh sách. Không tự retry vô hạn; người dùng có thể refresh như hiện tại.

### 6.2. Tổng kết quả trong lúc xác minh

- Bổ sung số request lifecycle còn chờ/đang chạy **của generation hiện tại** và getter `isResolvingLifecycle`; không dùng `_activeRequests` gộp các generation để hiển thị tiến độ hiện tại.
- Khi lọc theo trạng thái và còn đang xác minh, hiện dòng phụ `Đang kiểm tra trạng thái các giải…`; tổng/trang là kết quả đã xác định hiện thời, sẽ cập nhật dần.
- Nếu chưa có kết quả và còn xác minh, dùng `Đang tìm giải phù hợp…`; không kết luận ngay là không có sự kiện phù hợp.
- Khi hết pending nhưng có lỗi xác minh, hiện thông báo nhỏ `Một số giải chưa xác định được trạng thái` và hành động thử tải lại. Không đếm các giải lỗi thành đang mở.
- Với bộ lọc không phụ thuộc trạng thái, vẫn hiển thị thẻ chưa xác minh ngay; không chặn danh sách cho tới khi tất cả chi tiết xong.

### 6.3. Refresh và lỗi

- Phân biệt lần đầu tải với refresh đã có dữ liệu: `isInitialLoading`, `isRefreshing` hoặc state tương đương. Có thể giữ getter tương thích nếu test đang dùng `isLoading`.
- Lần đầu: toolbar/pager state hợp lý; vùng kết quả có loading/skeleton. Lỗi lần đầu: thông báo + Thử lại.
- Refresh đã có dữ liệu: giữ danh sách trên màn hình, chỉ hiện progress nhỏ/RefreshIndicator. Không thay toàn bộ thân trang bằng spinner.
- Refresh lỗi: giữ dữ liệu cũ, ghi rõ `Không thể cập nhật danh sách` + Thử lại; không biến lỗi mạng thành danh sách 0 item. Timer địa phương vẫn cập nhật hạn trên dữ liệu đã có.
- Khi list mới tải thành công, áp dụng nguyên tắc xác minh hiện có; không coi cache cũ là bằng chứng trạng thái mới đã được xác minh. Trường hợp list mới rỗng thực sự phải xóa danh sách cũ.
- Kéo làm mới, quay về từ chi tiết, chuyển lại tab Khám phá và app resume vẫn kích hoạt refresh theo luồng đang có.
- Giữ query, filters, page, vị trí đọc. Khi chuyển sang Đăng ký của tôi, dùng PageStorage/scroll state phù hợp để quay lại Khám phá không mất vị trí. Không giữ màn hình con chạy timer ngầm chỉ vì muốn giữ scroll.
- ScrollController thuộc view; hủy khi dispose. Sau await/callback kiểm tra mounted/hasClients. Debounce/search không được chạy sau dispose.
- Khi bàn phím search hiện, ẩn pager tạm thời nếu cần tránh vùng danh sách bị bóp quá nhỏ; khi đóng bàn phím khôi phục nguyên trang.

## 7. Bản đồ file triển khai

Tất cả đường dẫn dưới đây tương đối với repo RunnerMobile.

| File | Công việc |
| --- | --- |
| `lib/features/home/presentation/screens/home_screen.dart` | Bố cục toolbar/list/pager; bỏ carousel khỏi Home; quản lý search debounce, scroll, sheet; giữ navigation/refresh/lifecycle hooks |
| `lib/features/home/presentation/controller/home_controller.dart` | State phân trang, áp dụng filter atomically, giữ selections, comparator ngày, refresh không xóa UI, số lifecycle đang xác minh; giữ queue4/generation/timer |
| `lib/features/home/presentation/widgets/filter_card.dart` | Thay thế hoặc tách thành toolbar + sheet; xóa widget cũ khi hết nơi dùng |
| `lib/features/home/presentation/widgets/event_card.dart` | Card dạng hàng, ảnh nhỏ, thông tin rút gọn, trạng thái đúng, accessible |
| `lib/features/home/presentation/widgets/home_search_toolbar.dart` (mới) | Ô search + nút filter/badge; giao tiếp bằng values/callbacks |
| `lib/features/home/presentation/widgets/event_filter_sheet.dart` (mới) | Draft filter state, hủy/đặt lại/áp dụng, địa điểm có tìm kiếm |
| `lib/features/home/presentation/widgets/event_pagination_bar.dart` (mới) | Trước/Sau/chọn trang; không gọi repository |
| `lib/features/home/presentation/models/home_filter_selection.dart` (mới nếu cần) | Value object cho 4 lựa chọn, equality/copy; chỉ state giao diện |
| `lib/features/home/presentation/widgets/banner_carousel.dart` | Kiểm tra nơi dùng; không cần redesign carousel trong phạm vi này |
| `test/home_discovery_test.dart` (mới) | Tests filter/page/sort/refresh và widget bố cục/tương tác |
| `test/event_lifecycle_test.dart` | Giữ regression, cập nhật finder nếu UI đổi; không nới bỏ assertion nghiệp vụ |

Không cần sửa model/data source/repository/API chỉ để cắt trang phía client. Không thay đổi API endpoint hoặc giả lập `page`/`pageSize` trong request mà server chưa hỗ trợ.

## 8. Trình tự triển khai cho agent nhận bàn giao

1. Đọc `git status`, diff đang có và file hướng dẫn repo nếu có; giữ nguyên thay đổi của người dùng. Đọc lại các file trong bản đồ để đối chiếu code đã thay đổi sau ngày lập kế hoạch.
2. Bổ sung value object/filter atomic, page state, comparator, clamping và refresh state trong controller. Viết test thuần/controller cho các hợp đồng ở mục 5–6.
3. Dựng toolbar, sheet và pager bằng widget nhỏ. Kiểm thử draft cancel/apply, clear semantics và điều hướng trang trước khi ghép vào Home.
4. Thu gọn EventCard; ghép bố cục Home; bỏ banner tại nơi gọi; bảo toàn `_open`, observer và luồng đăng xuất/tab.
5. Hoàn thiện scroll restoration, debounce, pending/unknown/refresh errors và empty state. Kiểm tra các race giữa đổi filter, chuyển trang, refresh và detail trả chậm.
6. Chạy test liên quan, sau đó full tests và static analysis. Kiểm tra giao diện trên emulator/màn hình nhỏ và cỡ chữ lớn. Nếu thiếu môi trường chạy emulator thì báo rõ phần chưa kiểm tra; không khẳng định đã kiểm tra thiết bị thật.
7. Bàn giao danh sách file đổi, kết quả kiểm tra và ảnh chụp Home/sheet/page2 nếu môi trường hỗ trợ. Không commit/push hoặc sửa BE/UserWeb ngoài phạm vi được giao.

## 9. Kiểm thử bắt buộc và tiêu chí đạt

### 9.1. Controller và dữ liệu

- 0/1/10/11/23/101 kết quả: pageCount, range, pagedEvents và trạng thái nút đúng; page cuối không lặp item.
- 101 kết quả: tới trực tiếp trang 11, hiển thị item 101; quay lại trang trước được.
- Lọc tìm được sự kiện vốn ở cuối `allEvents`; chứng minh lọc trước cắt trang.
- Chọn filter/search mới về trang 1; apply cùng giá trị giữ page; bỏ một chip giữ các điều kiện khác.
- Đóng sheet không apply không thay kết quả; đặt lại bản nháp rồi hủy vẫn giữ bộ lọc đang áp dụng.
- Ngày tương lai/quá khứ/cùng ngày/ngày lỗi sắp xếp đúng; order ổn định với `id`; giao ngày dùng clock giả.
- Detail trả về sai thứ tự không làm mất item; bộ lọc trạng thái cập nhật, page clamp đúng khi số kết quả giảm; không tự về trang 1 khi không cần.
- Loading/failed không lọt vào Đang mở; hết hạn đúng mốc rời bộ lọc; existing lifecycle regression vẫn đạt.
- Refresh cũ trả muộn bị bỏ qua; số request đồng thời không vượt 4 qua nhiều generation.
- Page navigation không gọi list API; không sinh đợt detail requests mới chỉ vì chuyển page.
- Refresh lỗi giữ data/query/filter/page; refresh thành công trả [] phải thể hiện danh sách rỗng thực.
- Năm/địa điểm đang chọn không còn trong data vẫn có option hợp lệ, không crash dropdown hoặc tự reset.

### 9.2. Widget và sử dụng thực tế

- Viewport 320×568, 360×800, 390×844; font mặc định và text scale 2.0: không RenderFlex overflow, không che nút áp dụng/pager. Với màn hình thấp dùng body cuộn đúng, không ép số card phải hiện.
- 360×800, font mặc định: nhìn thấy ít nhất một card trọn vẹn ngay khi vào Home, không cần kéo qua bộ lọc.
- Bộ lọc không chiếm 4 dropdown trên màn hình chính; mở sheet, sửa, hủy/áp dụng hoạt động theo hợp đồng.
- Chuỗi tên/địa điểm dài, thiếu ảnh, ảnh lỗi, nhiều cự ly và nhãn trạng thái dài không phá layout.
- Chuyển trang thay toàn bộ tối đa 10 item, cuộn về đầu; footer luôn truy cập được khi bàn phím đóng.
- Search debounce không giật caret; clear/reset không bị callback cũ khôi phục từ khóa; chuyển trang không bị debounce cũ đẩy về trang 1.
- Mở sự kiện ở trang 2, Back: vẫn trang 2 và giữ vị trí hợp lý; không chớp trắng do spinner toàn trang.
- Chuyển tab, app background/resume, pull refresh giữ filter/page; timer/dispose không gây exception.
- 0 kết quả vẫn kéo refresh được; empty vì bộ lọc khác với lỗi API và đang chờ xác minh.
- Nút/icon có tooltip/semantic label tiếng Việt; trạng thái có chữ, không chỉ dựa vào màu; vùng bấm tối thiểu 48px.
- Fixture 100–500 sự kiện trong fake repository: builder chỉ dựng vùng nhìn thấy/cache của trang hiện tại; không tạo `...allEvents.map(...)` trong widget tree. Đo bằng fixture, không tạo hàng trăm sự kiện thật trên API.

Lệnh kiểm tra từ repo mobile (SDK phải có trên PATH, hoặc dùng đường dẫn cài đặt của máy):

```powershell
flutter test test/home_discovery_test.dart test/event_lifecycle_test.dart
flutter test
flutter analyze --no-pub
git diff --check
```

Không cập nhật expected trong test để hợp thức hóa lỗi trạng thái/đăng ký. Các test `userweb_runner_parity_test.dart` và luồng runner phải tiếp tục chạy thành công.

## 10. Hạng mục sau này, không triển khai trong lượt này

Nếu số sự kiện lớn khiến tải mạng/xác minh chi tiết chậm, cần một tác vụ BE riêng: API phân trang thật, search/filter/sort phía server, total count hoặc cursor, và trả đủ dữ liệu vòng đời trong list. Lúc đó phải thống nhất bộ lọc trạng thái trên server và client; không lọc riêng từng trang sau khi server đã phân trang.

Không thêm infinite scroll hoặc nút “Tải thêm” nối danh sách trong kế hoạch hiện tại: chúng vẫn làm trang dài dần và không đáp ứng nhu cầu đi tới một nhóm kết quả cụ thể. Phương án hiện tại giới hạn 10 kết quả mỗi trang và cho phép chọn trang trực tiếp.
