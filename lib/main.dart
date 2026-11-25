import 'package:flutter/material.dart';
import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme/app_theme.dart';
import 'features/authentication/presentation/screens/splash_screen.dart';
import 'features/authentication/presentation/screens/login_screen.dart';
import 'features/authentication/data/datasources/auth_local_data_source.dart';
import 'core/network/api_client.dart';
import 'features/runner/data/payment_callbacks.dart';

final navigatorKey = GlobalKey<NavigatorState>();
final messengerKey = GlobalKey<ScaffoldMessengerState>();
bool _handlingExpiredSession = false;

Future<void> _sessionExpired() async {
  if (_handlingExpiredSession) return;
  _handlingExpiredSession = true;
  await AuthLocalDataSourceImpl().clearUserSession();
  navigatorKey.currentState?.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (_) => false,
  );
  messengerKey.currentState?.showSnackBar(
    const SnackBar(
      content: Text('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.'),
    ),
  );
  _handlingExpiredSession = false;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ApiClient.onSessionExpired = _sessionExpired;
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Could not load .env file: $e');
  }
  runApp(const RunnerMobileApp());
}

class RunnerMobileApp extends StatefulWidget {
  const RunnerMobileApp({super.key});

  @override
  State<RunnerMobileApp> createState() => _RunnerMobileAppState();
}

class _RunnerMobileAppState extends State<RunnerMobileApp> {
  StreamSubscription<Uri>? links;
  @override
  void initState() {
    super.initState();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      links = AppLinks().uriLinkStream.listen(
        (uri) {
          final id = PaymentCallbacks.registrationFromLink(uri);
          if (id != null) PaymentCallbacks.pendingReturn.value = id;
        },
        onError: (Object e) =>
            debugPrint('Payment return link unavailable: $e'),
      );
    }
  }

  @override
  void dispose() {
    links?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: messengerKey,
      title: 'RaceDay Runner',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}
