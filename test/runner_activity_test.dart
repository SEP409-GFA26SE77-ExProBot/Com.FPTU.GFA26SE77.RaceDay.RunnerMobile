import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:runner_mobile/core/errors/app_exceptions.dart';
import 'package:runner_mobile/core/network/api_client.dart';
import 'package:runner_mobile/features/authentication/domain/entities/user_entity.dart';
import 'package:runner_mobile/features/authentication/presentation/screens/account_screen.dart';
import 'package:runner_mobile/features/runner/data/payment_callbacks.dart';
import 'package:runner_mobile/features/runner/data/runner_activity_api.dart';
import 'package:runner_mobile/features/runner/domain/runner_models.dart';
import 'package:runner_mobile/features/runner/presentation/screens/certificates_screen.dart';
import 'package:runner_mobile/features/runner/presentation/screens/complaints_screen.dart';
import 'package:runner_mobile/features/runner/presentation/screens/course_screen.dart';
import 'package:runner_mobile/features/runner/presentation/screens/payment_history_screen.dart';
import 'package:runner_mobile/features/runner/presentation/screens/photos_screen.dart';
import 'package:runner_mobile/features/runner/presentation/screens/results_screen.dart';
import 'package:runner_mobile/features/runner/presentation/screens/registration_detail_screen.dart';
import 'package:runner_mobile/features/runner/presentation/screens/runner_activity_screen.dart';
import 'package:runner_mobile/features/runner/presentation/widgets/activity_widgets.dart';
import 'support/fake_runner_repository.dart';

http.Response response(Object? body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
RunnerActivityApi service(
  FutureOr<http.Response> Function(http.Request) handler,
) => RunnerActivityApi(
  token: 'runner-token',
  client: ApiClient(client: MockClient((request) async => handler(request))),
);
Finder input(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);
Future<void> fill(WidgetTester tester, String label, String value) async {
  await tester.ensureVisible(input(label));
  await tester.pumpAndSettle();
  await tester.enterText(input(label), value);
}

Future<void> tapText(WidgetTester tester, String label) async {
  final finder = find
      .ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      )
      .first;
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> show(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(MaterialApp(home: screen));
  await tester.pumpAndSettle();
}

const user = UserEntity(
  id: 'u1',
  username: 'runner',
  role: 'Runner',
  token: 'runner-token',
);

class FinishedWithoutQrRepository extends FakeRunnerRepository {
  @override
  Registration get reg => Registration({
    ...super.reg.data,
    'status': 'finished',
    'raceStatus': 'finished',
    'bibNumber': '50001',
    'qrPayload': null,
  });
}

class RecordingFilePicker extends FilePickerPlatform {
  String? name, mime;
  Uint8List? savedBytes;
  Uri? result = Uri.parse('content://test/saved');
  final saved = Completer<void>();
  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    name = fileName;
    mime = mimeType;
    savedBytes = bytes;
    if (!saved.isCompleted) saved.complete();
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    dotenv.loadFromString(envString: 'API_URL=http://192.168.1.10:5080');
    ApiClient.onSessionExpired = null;
  });

  test(
    'photo search encodes BIB and pagination and uses bearer authentication',
    () async {
      final api = service((request) {
        expect(request.headers['Authorization'], 'Bearer runner-token');
        expect(request.url.path, '/api/v1/photo/photos');
        expect(request.url.queryParameters, {
          'eventId': 'event-1',
          'bib': 'A+001',
          'page': '2',
          'pageSize': '20',
        });
        return response({
          'items': [
            {'id': 'photo'},
          ],
          'total': 41,
        });
      });
      final result = await api.photos('event-1', ' A+001 ', page: 2);
      expect(result.total, 41);
      expect(result.hasMore, isTrue);
    },
  );

  test(
    'binary image downloads preserve bytes and reject error bodies and expired sessions',
    () async {
      final bytes = Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0]);
      final api = service((r) {
        expect(r.url.path, '/api/v1/photo/photos/p1/download');
        return http.Response.bytes(
          bytes,
          200,
          headers: {'content-type': 'image/jpeg'},
        );
      });
      expect(await api.downloadPhoto('p1'), bytes);
      final invalid = service((_) => response({'error': 'storage error'}));
      await expectLater(
        invalid.downloadPhoto('p1'),
        throwsA(isA<AppException>()),
      );
      var expired = false;
      ApiClient.onSessionExpired = () => expired = true;
      await expectLater(
        service((_) => response({}, 401)).downloadPhoto('p1'),
        throwsA(isA<AuthException>()),
      );
      expect(expired, isTrue);
    },
  );

  test(
    'photo disputes and refund requests send server-owned identities and policy fields',
    () async {
      final calls = <String>[];
      final api = service((r) {
        calls.add(r.url.path);
        final body = jsonDecode(r.body) as Map;
        expect(body.containsKey('userId'), isFalse);
        if (r.url.path.endsWith('/disputes')) {
          expect(body, {'reason': 'Sai BIB'});
        } else {
          expect(body, {
            'paymentId': 'p1',
            'reason': 'Thanh toán bị ghi nhận hai lần',
            'systemErrorClaim': true,
          });
        }
        return response({});
      });
      await api.reportPhoto('photo1', ' Sai BIB ');
      await api.requestRefund('p1', ' Thanh toán bị ghi nhận hai lần ');
      expect(calls, [
        '/api/v1/photo/photos/photo1/disputes',
        '/api/v1/finance/runner/refunds',
      ]);
    },
  );

  test(
    'leaderboard handles unpublished results and certificates handle false eligibility',
    () async {
      final api = service((r) {
        if (r.url.path.endsWith('/certificate')) return response(false);
        expect(r.url.queryParameters['gender'], 'Female');
        return response({
          'items': [],
          'totalCount': 0,
          'resultsPublished': false,
        });
      });
      expect((await api.leaderboard('e1', 'd1', 'Female')).published, isFalse);
      expect(await api.certificate('r1'), isNull);
    },
  );

  test('avatar upload sends image MIME and reads updated profile', () async {
    final api = service((r) {
      expect(r.url.path, '/api/v1/iam/me/avatar');
      expect(r.headers['content-type'], startsWith('multipart/form-data'));
      expect(r.body.toLowerCase(), contains('content-type: image/png'));
      expect(r.body, contains('name="file"; filename="avatar.png"'));
      return response({'avatarUrl': '/uploads/avatars/new.png'});
    });
    expect(
      (await api.uploadAvatar(
        'avatar.png',
        Uint8List.fromList([1, 2, 3]),
      )).fields['avatarUrl'],
      contains('new.png'),
    );
  });

  test('media URLs work on a phone and retain external CDN URLs', () {
    expect(
      mediaUrl('/uploads/a.jpg'),
      'http://192.168.1.10:5080/uploads/a.jpg',
    );
    expect(
      mediaUrl('http://localhost:5080/uploads/a.jpg'),
      'http://192.168.1.10:5080/uploads/a.jpg',
    );
    expect(
      mediaUrl('https://cdn.example.com/a.jpg'),
      'https://cdn.example.com/a.jpg',
    );
    expect(mediaUrl('javascript:alert(1)'), '');
    expect(imageExtension(Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0])), 'jpg');
  });

  test(
    'race status does not overwrite registration workflow or grant DQ certificates',
    () {
      final base = FakeRunnerRepository().reg.data;
      final dq = Registration({
        ...base,
        'status': 'finished',
        'raceStatus': 'dq',
      });
      expect(dq.status, 'finished');
      expect(dq.displayStatus, 'dq');
      expect(dq.finished, isFalse);
      final rejected = Registration({
        ...base,
        'status': 'rejected',
        'raceStatus': 'finished',
      });
      expect(rejected.displayStatus, 'rejected');
      expect(rejected.finished, isFalse);
      final finished = Registration({
        ...base,
        'status': 'finished',
        'raceStatus': 'finished',
        'bibNumber': '01',
        'qrPayload': {'bib': '01'},
      });
      expect(finished.finished, isTrue);
      expect(finished.hasTicket, isTrue);
    },
  );

  test(
    'payment return accepts only a registration reference and ignores claimed success',
    () {
      const id = '5eed2026-0000-4000-8000-000000000100';
      expect(
        PaymentCallbacks.registrationFromLink(
          Uri.parse('raceday://payment-return?registrationId=$id&status=PAID'),
        ),
        id,
      );
      expect(
        PaymentCallbacks.registrationFromLink(
          Uri.parse('https://evil.example/payment-return?registrationId=$id'),
        ),
        isNull,
      );
      expect(
        PaymentCallbacks.registrationFromLink(
          Uri.parse('raceday://payment-return?registrationId=../other'),
        ),
        isNull,
      );
      final callbacks = PaymentCallbacks.forRegistration(
        'http://api.example.com',
        id,
      );
      expect(
        Uri.parse(callbacks.returnUrl).queryParameters['registrationId'],
        id,
      );
      expect(Uri.parse(callbacks.returnUrl).queryParameters['native'], '1');
    },
  );

  testWidgets(
    'image save keeps JPEG extension and cancellation does not claim success',
    (tester) async {
      final original = FilePickerPlatform.instance;
      final picker = RecordingFilePicker()..result = null;
      FilePickerPlatform.instance = picker;
      addTearDown(() => FilePickerPlatform.instance = original);
      await show(
        tester,
        Scaffold(
          body: Builder(
            builder: (c) => TextButton(
              onPressed: () => saveImage(
                c,
                Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0]),
                'raceday-photo',
              ),
              child: const Text('Lưu'),
            ),
          ),
        ),
      );
      await tapText(tester, 'Lưu');
      expect(picker.name, 'raceday-photo.jpg');
      expect(picker.mime, 'image/jpeg');
      expect(find.text('Đã lưu ảnh.'), findsNothing);
    },
  );

  testWidgets(
    'eligible certificate exports actual PNG artwork to the file picker',
    (tester) async {
      final original = FilePickerPlatform.instance;
      final picker = RecordingFilePicker();
      FilePickerPlatform.instance = picker;
      addTearDown(() => FilePickerPlatform.instance = original);
      final api = service(
        (_) => response({
          'runnerName': 'Nguyễn An',
          'eventName': 'RaceDay 5K',
          'distance': '5K',
          'raceDate': '2026-11-25',
          'bib': '50001',
          'finishTime': '00:30:00',
          'pace': '06:00',
        }),
      );
      await show(tester, CertificateScreen(api: api, registrationId: 'r1'));
      final button = find.widgetWithText(FilledButton, 'Lưu chứng nhận PNG');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      for (var frame = 0; frame < 20 && picker.savedBytes == null; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
      }
      await tester.pumpAndSettle();
      expect(
        find.text('Không xuất được chứng nhận. Vui lòng thử lại.'),
        findsNothing,
      );
      expect(picker.name, 'raceday-certificate-r1.png');
      expect(picker.mime, 'image/png');
      expect(picker.savedBytes!.take(8).toList(), [
        137,
        80,
        78,
        71,
        13,
        10,
        26,
        10,
      ]);
      expect(find.text('Đã lưu ảnh.'), findsOneWidget);
    },
  );

  testWidgets(
    'registration validates confirmation, creates an account, then verifies via OTP',
    (tester) async {
      final requests = <http.Request>[];
      final client = ApiClient(
        client: MockClient((r) async {
          requests.add(r);
          return r.url.path.endsWith('/verify-email')
              ? response({'message': 'OTP không đúng'}, 400)
              : response({});
        }),
      );
      await show(
        tester,
        AccountScreen(action: AccountAction.register, client: client),
      );
      await fill(tester, 'Email', 'runner@example.com');
      await fill(tester, 'Tên đăng nhập', 'runner1');
      await fill(tester, 'Họ và tên', 'Nguyễn An');
      await fill(tester, 'Mật khẩu mới', 'Password123');
      await fill(tester, 'Xác nhận mật khẩu', 'different');
      await tapText(tester, 'Tạo tài khoản');
      expect(requests, isEmpty);
      await fill(tester, 'Xác nhận mật khẩu', 'Password123');
      await tapText(tester, 'Tạo tài khoản');
      expect(requests.single.url.path, '/api/v1/iam/auth/register');
      expect(find.text('Xác thực email'), findsWidgets);
      expect(input('Mã OTP'), findsOneWidget);
      expect(jsonDecode(requests.single.body)['email'], 'runner@example.com');
      await fill(tester, 'Mã OTP', '123456');
      await tapText(tester, 'Xác thực email');
      expect(requests.last.url.path, '/api/v1/iam/auth/verify-email');
      expect(jsonDecode(requests.last.body), {
        'email': 'runner@example.com',
        'otp': '123456',
      });
      expect(find.text('OTP không đúng'), findsOneWidget);
      expect(
        tester.widget<TextField>(input('Mã OTP')).controller!.text,
        '123456',
      );
    },
  );

  testWidgets(
    'OTP resend does not require OTP or password and throttles repeat taps',
    (tester) async {
      var calls = 0;
      final client = ApiClient(
        client: MockClient((r) async {
          calls++;
          expect(r.url.path, '/api/v1/iam/auth/resend-otp');
          return response({});
        }),
      );
      await show(
        tester,
        AccountScreen(action: AccountAction.verify, client: client),
      );
      await fill(tester, 'Email', 'runner@example.com');
      await tapText(tester, 'Gửi lại mã OTP');
      expect(calls, 1);
      await tapText(tester, 'Gửi lại mã OTP');
      expect(calls, 1);
      expect(find.textContaining('60 giây'), findsOneWidget);
    },
  );

  testWidgets(
    'forgot password moves to reset; server failure preserves entered values',
    (tester) async {
      final paths = <String>[];
      final client = ApiClient(
        client: MockClient((r) async {
          paths.add(r.url.path);
          return r.url.path.endsWith('reset-password')
              ? response({'message': 'OTP không đúng'}, 400)
              : response({});
        }),
      );
      await show(
        tester,
        AccountScreen(action: AccountAction.forgot, client: client),
      );
      await fill(tester, 'Email', 'runner@example.com');
      await tapText(tester, 'Quên mật khẩu');
      await fill(tester, 'Mã OTP', '123456');
      await fill(tester, 'Mật khẩu mới', 'Password123');
      await fill(tester, 'Xác nhận mật khẩu', 'Password123');
      await tapText(tester, 'Đặt lại mật khẩu');
      expect(paths, [
        '/api/v1/iam/auth/forgot-password',
        '/api/v1/iam/auth/reset-password',
      ]);
      expect(find.text('OTP không đúng'), findsOneWidget);
      expect(
        tester.widget<TextField>(input('Email')).controller!.text,
        'runner@example.com',
      );
      expect(
        tester.widget<TextField>(input('Mã OTP')).controller!.text,
        '123456',
      );
    },
  );

  testWidgets(
    'photo search starts with the runner BIB and supports page navigation',
    (tester) async {
      final pages = <String>[];
      final repo = FakeRunnerRepository()..status = 'confirmed';
      final api = service((r) {
        expect(r.url.queryParameters['bib'], '1001');
        pages.add(r.url.queryParameters['page']!);
        return response({'items': [], 'total': 21});
      });
      await show(tester, PhotosScreen(api: api, repository: repo));
      expect(find.text('21 ảnh · BIB 1001'), findsOneWidget);
      await tester.tap(find.byTooltip('Trang sau'));
      await tester.pumpAndSettle();
      expect(pages, ['1', '2']);
      expect(find.text('Trang 2 · 21 mục'), findsOneWidget);
    },
  );

  testWidgets(
    'photo report failure retains reason; retry prevents duplicate submission',
    (tester) async {
      var attempts = 0;
      final gate = Completer<void>();
      await show(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<bool>(
                context: context,
                builder: (_) => ActivityReasonDialog(
                  title: 'Báo ảnh sai',
                  submit: (text) async {
                    attempts++;
                    if (attempts == 1) throw Exception('Mất mạng');
                    await gate.future;
                  },
                ),
              ),
              child: const Text('Báo sai'),
            ),
          ),
        ),
      );
      await tapText(tester, 'Báo sai');
      await fill(tester, 'Lý do', 'Ảnh không đúng BIB');
      await tapText(tester, 'Gửi');
      expect(find.textContaining('Mất mạng'), findsOneWidget);
      expect(
        tester.widget<TextField>(input('Lý do')).controller!.text,
        'Ảnh không đúng BIB',
      );
      await tapText(tester, 'Gửi');
      expect(attempts, 2);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      gate.complete();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('unpublished leaderboard is distinct from an empty result', (
    tester,
  ) async {
    final api = service(
      (r) => response(
        r.url.path.endsWith('/distances')
            ? [
                {'id': 'd1', 'type': '5K', 'distanceKm': 5},
              ]
            : {'items': [], 'totalCount': 0, 'resultsPublished': false},
      ),
    );
    await show(
      tester,
      LeaderboardScreen(api: api, eventId: 'e1', eventName: 'Giải chạy'),
    );
    expect(find.text('BTC chưa công bố kết quả cự ly này.'), findsOneWidget);
    expect(find.text('Chưa có kết quả phù hợp.'), findsNothing);
  });

  testWidgets('ineligible certificate cannot be exported', (tester) async {
    await show(
      tester,
      CertificateScreen(
        api: service((_) => response(false)),
        registrationId: 'r1',
      ),
    );
    expect(
      find.text('Đăng ký chưa đủ điều kiện nhận chứng nhận.'),
      findsOneWidget,
    );
    expect(find.text('Lưu chứng nhận PNG'), findsNothing);
  });

  testWidgets(
    'complaints reject invalid evidence before posting and preserve content',
    (tester) async {
      var posts = 0;
      await show(
        tester,
        CreateComplaintScreen(
          api: service((_) {
            posts++;
            return response({});
          }),
          repository: FakeRunnerRepository(),
        ),
      );
      await fill(tester, 'Tiêu đề', 'Sai kết quả');
      await fill(tester, 'Nội dung', 'Xin kiểm tra lại kết quả của tôi.');
      await fill(tester, 'Bằng chứng (1–5 liên kết)', 'javascript:alert(1)');
      await tapText(tester, 'Gửi khiếu nại');
      expect(posts, 0);
      expect(find.text('Liên kết phải là HTTP/HTTPS hợp lệ.'), findsOneWidget);
      expect(
        tester.widget<TextField>(input('Nội dung')).controller!.text,
        contains('kiểm tra'),
      );
    },
  );

  testWidgets(
    'failed refund history cannot be mistaken for no existing request',
    (tester) async {
      await show(
        tester,
        PaymentHistoryScreen(
          api: service(
            (r) => r.url.path.endsWith('/refunds')
                ? response({'message': 'Không tải được yêu cầu hoàn'}, 503)
                : response([
                    {'id': 'p1', 'status': 'paid'},
                  ]),
          ),
          repository: FakeRunnerRepository(),
          user: user,
        ),
      );
      expect(find.text('Không tải được yêu cầu hoàn'), findsOneWidget);
      expect(find.text('Yêu cầu hoàn do lỗi hệ thống'), findsNothing);
    },
  );

  testWidgets('refund reason must describe a system error before posting', (
    tester,
  ) async {
    var posts = 0;
    final api = service((r) {
      if (r.method == 'POST') posts++;
      return response({
        'paidAmount': 100000,
        'refundAmount': 100000,
        'policyNote': 'Chờ xác minh lỗi hệ thống.',
      });
    });
    await show(tester, RefundScreen(api: api, paymentId: 'p1'));
    await fill(tester, 'Mô tả lỗi hệ thống', 'Đổi ý');
    await tapText(tester, 'Gửi yêu cầu xác minh');
    expect(posts, 0);
    expect(find.text('Mô tả ít nhất 20 ký tự.'), findsOneWidget);
  });

  testWidgets(
    'missing course displays an availability message rather than a fake route',
    (tester) async {
      await show(
        tester,
        CourseScreen(
          api: service((_) => response({'polyline': [], 'checkpoints': []})),
          eventId: 'e1',
          distanceId: 'd1',
          title: '5K',
        ),
      );
      expect(
        find.text('BTC chưa thiết lập tuyến chạy cho cự ly này.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'finished API registration without a QR retains its BIB and certificate access',
    (tester) async {
      await show(
        tester,
        RegistrationDetailScreen(
          registrationId: 'r1',
          user: user,
          repository: FinishedWithoutQrRepository(),
        ),
      );
      expect(find.text('BIB 50001'), findsOneWidget);
      expect(
        find.text(
          'Vé chưa đủ dữ liệu BIB/QR. Vui lòng tải lại hoặc liên hệ BTC.',
        ),
        findsNothing,
      );
      await tester.scrollUntilVisible(
        find.text('Chứng nhận'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Chứng nhận'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final width in [375.0, 768.0]) {
    testWidgets(
      'activity hub fits width $width with all feature destinations',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await show(
          tester,
          Scaffold(
            body: RunnerActivityScreen(
              user: user,
              repository: FakeRunnerRepository(),
            ),
          ),
        );
        for (final text in [
          'Ảnh sự kiện',
          'Thành tích',
          'Chứng nhận',
          'Thanh toán',
          'Khiếu nại',
        ]) {
          expect(find.text(text), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
