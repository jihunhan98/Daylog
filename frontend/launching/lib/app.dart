import 'package:daylog_launching/service/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:daylog_launching/providers/alarm_provider.dart';

// Router (nav)
import './screens/user/checkemail_screen.dart';
import './screens/user/findemail_screen.dart';
import './screens/user/findpassword_screen.dart';
import './screens/user/login_screen.dart';
import './screens/user/signup_screen.dart';
import './screens/user/success_screen.dart';
import './screens/user/temppassword_screen.dart';
import 'package:daylog_launching/screens/loading_screen.dart';
import 'package:daylog_launching/screens/mypage/mypage_screen.dart';

// couple
import './screens/couple/couple_connect_screen.dart';

// feature
import 'screens/footer.dart';

// api
import './api/api_user_service.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  _AppState createState() => _AppState();
}

class _AppState extends State<App> {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  String? _initialRoute;

  @override
  void initState() {
    super.initState();

    // 알림 초기화
    NotificationService().initialize();

    // Firebase 메시지 초기화 및 처리
    _initializeFirebaseMessaging();
  }

  void _initializeFirebaseMessaging() {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        NotificationService()
            .handleMessageOpenedApp(message, _setInitialRouteFromMessage);
      });
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      Provider.of<AlaramState>(context, listen: false).fetchAlarmCount();
      NotificationService().handleMessage(message);
    });

    FirebaseMessaging.instance
        .getInitialMessage()
        .then((RemoteMessage? message) {
      if (message != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _setInitialRouteFromMessage(message.data);
        });
      }
    });
  }

  void _setInitialRouteFromMessage(Map<String, dynamic> data) {
    String? page = data['type'];
    if (page != null) {
      switch (page) {
        case 'schedule':
          _initialRoute = '/schedule';
          break;
        case 'call':
          _initialRoute = '/call';
          break;
        case 'diary':
          _initialRoute = '/diary';
          break;
        default:
          _initialRoute = '/home';
          break;
      }
      setState(() {});
    }
  }

  Future<Map<String, dynamic>> _getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token != null && token.isNotEmpty) {
      final userInfo = await ApiUserService.userInfo();
      return {'hasToken': true, 'status': userInfo['status']};
    } else {
      return {'hasToken': false};
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getUserInfo(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasData) {
          final data = snapshot.data!;
          final hasToken = data['hasToken'];
          final status = data['status'];

          String initialRoute;
          if (_initialRoute != null) {
            initialRoute = _initialRoute!;
          } else if (hasToken) {
            switch (status) {
              case 'INACTIVE':
                initialRoute = '/connect';
                break;
              case 'PENDING':
                initialRoute = '/loading';
                break;
              case 'ACTIVE':
                initialRoute = '/home';
                break;
              default:
                initialRoute = '/unknown';
                break;
            }
          } else {
            initialRoute = '/login';
          }

          return MaterialApp(
            debugShowCheckedModeBanner: false,
            routes: {
              '/login': (context) => const LoginScreen(),
              '/signup': (context) => const SignupScreen(),
              '/success': (context) => const SuccessScreen(),
              '/home': (context) => const Footer(),
              '/findemail': (context) => const FindemailScreen(),
              '/findpassword': (context) => const FindpasswordScreen(),
              '/temppassword': (context) => const TemppasswordScreen(),
              '/checkemail': (context) => const CheckemailScreen(),
              '/mypage': (context) => const MypageScreen(),
              '/connect': (context) => const CoupleConnectScreen(),
              '/loading': (context) => const LoadingScreen(),
              '/schedule': (context) => const Footer(selectedIndex: 1),
              '/call': (context) => const Footer(selectedIndex: 2),
              '/diary': (context) => const Footer(selectedIndex: 3),
            },
            initialRoute: initialRoute,
            theme: ThemeData(
              fontFamily: "mongle",
              textTheme: const TextTheme(
                titleLarge: TextStyle(fontSize: 30.0),
                bodyMedium: TextStyle(fontSize: 18.0),
                labelLarge: TextStyle(fontSize: 25.0, height: 0.9),
              ),
            ),
          );
        } else {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            routes: {
              '/login': (context) => const LoginScreen(),
              '/signup': (context) => const SignupScreen(),
              '/success': (context) => const SuccessScreen(),
              '/home': (context) => const Footer(),
              '/findemail': (context) => const FindemailScreen(),
              '/findpassword': (context) => const FindpasswordScreen(),
              '/temppassword': (context) => const TemppasswordScreen(),
              '/checkemail': (context) => const CheckemailScreen(),
              '/mypage': (context) => const MypageScreen(),
              '/connect': (context) => const CoupleConnectScreen(),
              '/loading': (context) => const LoadingScreen(),
            },
            initialRoute: '/login',
            theme: ThemeData(
              fontFamily: "mongle",
              textTheme: const TextTheme(
                titleLarge: TextStyle(fontSize: 30.0),
                bodyMedium: TextStyle(fontSize: 18.0),
                labelLarge: TextStyle(fontSize: 25.0, height: 0.9),
              ),
            ),
          );
        }
      },
    );
  }
}
