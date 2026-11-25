import 'dart:typed_data';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../domain/runner_models.dart';

class ActivityPage {
  final List<Json> items;
  final int page, total;
  final bool hasMore, published;
  const ActivityPage(
    this.items,
    this.page,
    this.total,
    this.hasMore, {
    this.published = true,
  });
  factory ActivityPage.fromJson(Json data, int page, int size) {
    final total = (data['totalCount'] ?? data['total'] ?? 0) as int;
    return ActivityPage(
      jsonRows(data['items']),
      page,
      total,
      page * size < total,
      published: data['resultsPublished'] != false,
    );
  }
}

List<Json> jsonRows(dynamic raw) =>
    (raw as List).map((e) => Json.from(e as Map)).toList();

String mediaUrl(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '';
  final uri = Uri.tryParse(raw.trim());
  if (uri == null) return '';
  final base = Uri.parse('${ApiEndpoints.baseUrl}/');
  if (uri.hasScheme) {
    if (!['http', 'https'].contains(uri.scheme)) return '';
    if (['localhost', '127.0.0.1', '10.0.2.2'].contains(uri.host) &&
        uri.host != base.host) {
      return uri
          .replace(scheme: base.scheme, host: base.host, port: base.port)
          .toString();
    }
    return uri.toString();
  }
  return base.resolveUri(uri).toString();
}

class RunnerActivityApi {
  final String token;
  final ApiClient client;
  RunnerActivityApi({required this.token, ApiClient? client})
    : client = client ?? ApiClient();
  String url(String path, [Map<String, String>? query]) => Uri.parse(
    '${ApiEndpoints.baseUrl}/api/v1/$path',
  ).replace(queryParameters: query).toString();
  Future<dynamic> get(String path, [Map<String, String>? query]) =>
      client.get(url(path, query), token: token);
  Future<dynamic> post(String path, Json body) =>
      client.post(url(path), token: token, body: body);

  Future<RunnerProfile> uploadAvatar(String name, Uint8List bytes) async =>
      RunnerProfile(
        Json.from(
          await client.upload(
            url('iam/me/avatar'),
            token: token,
            filename: name,
            bytes: bytes,
          ),
        ),
      );

  Future<ActivityPage> photos(
    String eventId,
    String bib, {
    int page = 1,
  }) async => ActivityPage.fromJson(
    Json.from(
      await get('photo/photos', {
        'eventId': eventId,
        'bib': bib.trim(),
        'page': '$page',
        'pageSize': '20',
      }),
    ),
    page,
    20,
  );
  Future<Json> photo(String id) async =>
      Json.from(await get('photo/photos/${Uri.encodeComponent(id)}'));
  Future<Uint8List> downloadPhoto(String id) => client.imageBytes(
    url('photo/photos/${Uri.encodeComponent(id)}/download'),
    token: token,
  );
  Future<void> reportPhoto(String id, String reason) async {
    await post('photo/photos/${Uri.encodeComponent(id)}/disputes', {
      'reason': reason.trim(),
    });
  }

  Future<List<Json>> photoDisputes() async =>
      jsonRows(await get('photo/me/disputes'));
  Future<List<Json>> myResults() async =>
      jsonRows(await get('event/leaderboards/mine'));
  Future<List<Json>> distances(String eventId) async =>
      jsonRows(await get('event/distances', {'eventId': eventId}));
  Future<ActivityPage> leaderboard(
    String eventId,
    String distanceId,
    String gender, {
    int page = 1,
  }) async => ActivityPage.fromJson(
    Json.from(
      await get(
        'event/${Uri.encodeComponent(eventId)}/distances/${Uri.encodeComponent(distanceId)}/leaderboard',
        {'gender': gender, 'page': '$page', 'pageSize': '50'},
      ),
    ),
    page,
    50,
  );
  Future<Json?> certificate(String registrationId) async {
    final data = await get(
      'event/registrations/${Uri.encodeComponent(registrationId)}/certificate',
    );
    return data == false || data == null ? null : Json.from(data);
  }

  Future<Json> course(String eventId, String distanceId) async => Json.from(
    await get(
      'map/events/${Uri.encodeComponent(eventId)}/distances/${Uri.encodeComponent(distanceId)}/course',
    ),
  );
  Future<ActivityPage> complaints({int page = 1}) async =>
      ActivityPage.fromJson(
        Json.from(
          await get('event/complaints/mine', {
            'page': '$page',
            'pageSize': '10',
          }),
        ),
        page,
        10,
      );
  Future<Json> complaint(String id) async =>
      Json.from(await get('event/complaints/detail', {'complaintId': id}));
  Future<void> createComplaint(
    Registration r,
    String title,
    String content,
    List<String> evidence,
  ) async {
    await post('event/complaints', {
      'eventId': r.eventId,
      'distanceId': r.distanceId,
      'title': title.trim(),
      'content': content.trim(),
      'evidenceLinks': evidence,
    });
  }

  Future<List<Json>> payments() async => jsonRows(await get('payment/mine'));
  Future<List<Json>> refunds() async =>
      jsonRows(await get('finance/runner/refunds'));
  Future<Json> refundQuote(String paymentId) async => Json.from(
    await get('finance/runner/refunds/quote', {
      'paymentId': paymentId,
      'systemErrorClaim': 'true',
    }),
  );
  Future<void> requestRefund(String paymentId, String reason) async {
    await post('finance/runner/refunds', {
      'paymentId': paymentId,
      'reason': reason.trim(),
      'systemErrorClaim': true,
    });
  }
}
