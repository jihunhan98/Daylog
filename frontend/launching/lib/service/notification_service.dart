import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    _createNotificationChannel();
  }

  void _createNotificationChannel() {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'daylog',
      'DayLog',
      description: 'DayLog 알림 채널입니다.',
      importance: Importance.high,
    );

    flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> showNotification(RemoteMessage message) async {
    // 큰 아이콘과 이미지 설정
    const String largeIconPath = 'assets/logo/Logo1.png'; // 프로필 이미지 경로
    const String bigPicturePath = 'assets/logo/Logo1.png'; // 큰 이미지 경로

    final BigPictureStyleInformation bigPictureStyleInformation =
        BigPictureStyleInformation(
      const FilePathAndroidBitmap(bigPicturePath),
      largeIcon: const FilePathAndroidBitmap(largeIconPath),
      contentTitle: '<b>${message.notification?.title}</b>',
      summaryText: message.notification?.body,
      hideExpandedLargeIcon: false,
    );

    AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'daylog',
      'DayLog',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      styleInformation: bigPictureStyleInformation,
      largeIcon: const DrawableResourceAndroidBitmap(
          '@mipmap/ic_launcher'), // 기본 아이콘 또는 커스텀 아이콘
    );

    NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      message.notification.hashCode,
      message.notification?.title,
      message.notification?.body,
      platformChannelSpecifics,
      payload: message.data['title'],
    );
  }

  void handleMessage(RemoteMessage message) {
    showNotification(message);
  }

  void handleMessageOpenedApp(
      RemoteMessage message, Function(Map<String, dynamic>) onMessageOpened) {
    if (message.data.isNotEmpty) {
      onMessageOpened(message.data);
    }
  }
}
