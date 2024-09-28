import 'package:daylog_launching/api/api_user_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:daylog_launching/providers/theme_provider.dart';
import 'package:intl/intl.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  String _getTitleText(String? title) {
    switch (title) {
      case 'diary':
        return '그림일기';
      case 'schedule':
        return '일정';
      case 'home':
        return '배경화면';
      default:
        return '알림 제목';
    }
  }

  // 날짜 형식 변환 메서드
  String _formatDate(String dateString) {
    final date = DateTime.parse(dateString); // 알림 작성 날짜
    final now = DateTime.now(); // 현재 날짜
    final difference = now.difference(date); // 차이

    if (difference.inDays == 0) {
      return "오늘";
    } else if (difference.inDays > 0 && difference.inDays < 7) {
      return "${difference.inDays}일 전";
    } else if (difference.inDays >= 7 && difference.inDays < 30) {
      int weeks = (difference.inDays / 7).floor();
      return "$weeks주 전";
    } else if (difference.inDays >= 30 && difference.inDays < 365) {
      int months = (difference.inDays / 30).floor();
      return "$months달 전";
    } else if (difference.inDays >= 365) {
      int years = (difference.inDays / 365).floor();
      return "$years년 전";
    } else {
      return DateFormat('yyyy-MM-dd').format(date); // 기본적으로 yyyy-mm-dd 형식으로 출력
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final themeColor = themeProvider.themeColor;
    final backColor = themeProvider.backColor;

    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: backColor,
      appBar: AppBar(
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        backgroundColor: themeColor,
        title: const Text(
          '알림',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: FutureBuilder(
          future: ApiUserService.alarmInfo(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return const Center(child: Text('데이터를 불러오는 중 오류가 발생했습니다.'));
            } else if (snapshot.hasData) {
              final alarmlist = snapshot.data!;
              return ListView.builder(
                itemCount: alarmlist.length,
                itemBuilder: (context, index) {
                  final alarm = alarmlist[index];
                  return SizedBox(
                    width: screenWidth * 0.9, // 고정 너비
                    height: 120, // 고정 높이
                    child: Card(
                      margin: const EdgeInsets.symmetric(vertical: 10.0),
                      child: Stack(
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ListTile(
                                leading: ClipOval(
                                  child: Image.network(
                                    'http://i11b107.p.ssafy.io/api/serve/image?path=${alarm['profileImage']}',
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                title: Text(
                                  _getTitleText(alarm['title']),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(alarm['content'] ?? '알림 내용입니다.'),
                              ),
                            ],
                          ),
                          Positioned(
                            right: 10,
                            top: 10,
                            child: Text(
                              _formatDate(alarm['createdAt']),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ),
                          if (alarm['new'] == true) // 새 알림인 경우에만 "N" 표시
                            Positioned(
                              left: 10,
                              top: 10,
                              child: Container(
                                padding: const EdgeInsets.all(4.0),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Text(
                                  'N',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            } else {
              return const Center(child: Text('표시할 알림이 없습니다.'));
            }
          },
        ),
      ),
    );
  }
}
