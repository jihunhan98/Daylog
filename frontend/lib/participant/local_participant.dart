import 'dart:typed_data';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:openvidu_flutter/utils/session.dart';
import 'participant.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';

class LocalParticipant extends Participant {
  List<RTCIceCandidate> localIceCandidates = [];
  RTCSessionDescription? localSessionDescription;
  bool isFrontCameraActive = true;
  Timer? _frameCaptureTimer;
  final FlutterSoundRecorder _audioRecorder = FlutterSoundRecorder();
  @override
  RTCVideoRenderer renderer = RTCVideoRenderer();
  StreamSubscription? _recorderSubscription;
  final List<int> _audioBuffer = [];
  String? _audioFilePath;
  int? _cachedUserId; // UserId 캐시를 위한 변수
  int? _couplepk;
  String? _token; // 토큰 캐시를 위한 변수_cachedUserId
  bool _audioSent = false; // 오디오 전송 여부 플래그
  DateTime? _audioStartTime;
  DateTime? _audioEndTime;
  // String? apiAddress = '172.20.10.9'; //핸드폰 핫스팟
  // String? apiAddress = 'http://192.168.31.208:8000'; // 싸피
  // String? apiAddress = '172.30.1.11'; // 탐탐
  // String? apiAddress = '192.168.219.107'; //집
  String? apiAddress = 'http://i11b107.p.ssafy.io:8000'; // ec2 서버

  LocalParticipant(String participantName, Session session)
      : super(participantName, session) {
    session.localParticipant = this;
    _initializeTokenAndUserId(); // 초기화 시 토큰과 userId를 가져옴
    _initializeAudioRecorder();
    _initializeRenderer();
  }

  Future<void> _initializeAudioRecorder() async {
    await _audioRecorder.openRecorder();
  }

  Future<void> _initializeRenderer() async {
    await renderer.initialize();
  }

  Future<void> _initializeTokenAndUserId() async {
    _token = await _getToken();
    if (_token != null) {
      final data = await _fetchUserInfo(_token!);
      _cachedUserId = data['userId'];
      _couplepk = data['coupleId'];
    }
  }

  // SharedPreferences에서 토큰을 가져오는 함수
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  // 토큰을 사용하여 API를 통해 userId를 가져오는 함수
  Future<Map<String, dynamic>> _fetchUserInfo(String token) async {
    final response = await http.get(
      Uri.parse('http://i11b107.p.ssafy.io:8080/api/users'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data;
    } else {
      throw Exception('Failed to fetch userId: ${response.statusCode}');
    }
  }

  Future<void> switchCamera() async {
    if (videoTrack != null) {
      isFrontCameraActive = await Helper.switchCamera(videoTrack!);
    }
  }

  toggleVideo() {
    if (videoTrack != null) {
      videoTrack!.enabled = !videoTrack!.enabled;
      isVideoActive = videoTrack!.enabled;
    }
  }

  toggleAudio() {
    if (audioTrack != null) {
      audioTrack!.enabled = !audioTrack!.enabled;
      isAudioActive = audioTrack!.enabled;
    }
  }

  Future<void> startLocalCamera() async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': {
        'mandatory': {
          'minWidth': '320',
          'minHeight': '240',
          'minFrameRate': '30',
        },
        'facingMode': 'user',
        'optional': [],
      }
    };
    mediaStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    mediaStream!.getAudioTracks().forEach((track) {
      audioTrack = track;
    });
    mediaStream!.getVideoTracks().forEach((track) {
      videoTrack = track;
    });

    renderer.srcObject = mediaStream;

    // 서버에 통화 시작 시간 알림
    await _notifyServerOfCallStart();
  }

  Future<void> _notifyServerOfCallStart() async {
    if (_couplepk != null) {
      var url = Uri.parse('$apiAddress/start_call');
      try {
        final response =
            await http.post(url, body: {'coupleId': _couplepk.toString()});
        if (response.statusCode == 200) {
          print('통화 시작 시간 서버에 알림 성공');
        } else {
          print('Failed to notify server: ${response.statusCode}');
        }
      } catch (e) {
        print('Error notifying server: $e');
      }
    } else {
      print('Couple ID가 초기화되지 않았습니다.');
    }
  }

  Future<void> captureFrame() async {
    if (videoTrack != null) {
      try {
        final frame = await videoTrack!.captureFrame();
        if (_cachedUserId != null) {
          final captureTime = DateTime.now().toIso8601String();
          await _sendFrameToServer(
              frame.asUint8List(), _cachedUserId!, captureTime);
        } else {
          print("User ID is not initialized");
        }
        _audioBuffer.clear();
      } catch (e) {
        print("Error capturing frame: $e");
      }
    }
  }

  Future<void> _sendFrameToServer(
      Uint8List videoFrame, int userId, String captureTime) async {
    var url = Uri.parse('$apiAddress/send');

    try {
      final request = http.MultipartRequest('POST', url)
        ..fields['coupleId'] = _couplepk.toString()
        ..fields['userId'] = userId.toString()
        ..fields['captureTime'] = captureTime
        ..files.add(http.MultipartFile.fromBytes('videoFrame', videoFrame,
            filename: 'videoFrame.raw'));

      final response = await request.send();

      if (response.statusCode == 200) {
        print('Frames sent successfully');
      } else {
        print('Failed to send frames: ${response.statusCode}');
      }
    } catch (e) {
      print('Error sending frames: $e');
    }
  }

  void startFrameCapture() {
    // 초당 30 프레임 캡처
    _frameCaptureTimer =
        Timer.periodic(const Duration(milliseconds: 33), (timer) {
      captureFrame();
    });
  }

  Future<void> startAudioRecord() async {
    _audioFilePath = await _getAudioFilePath();
    _audioStartTime = DateTime.now();
    await _audioRecorder.startRecorder(toFile: _audioFilePath);
  }

  Future<void> stopAudioRecord() async {
    await _audioRecorder.stopRecorder();
    _audioEndTime = DateTime.now();
    await _sendAudioToServer();
  }

  Future<String> _getAudioFilePath() async {
    dynamic appDocDirectory = await getExternalStorageDirectory();
    String filePath = '${appDocDirectory.path}/audio.aac';
    return filePath;
  }

  Future<void> _sendAudioToServer() async {
    print("오디오 전송 시도");
    if (_audioFilePath == null || _audioSent) {
      print("오디오 파일 경로가 없거나 이미 전송됨");
      return;
    }

    var url = Uri.parse('$apiAddress/upload_audio');

    try {
      print("오디오 전송 준비 중");
      var request = http.MultipartRequest('POST', url)
        ..fields['coupleId'] = _couplepk.toString()
        ..fields['userId'] = _cachedUserId.toString()
        ..files
            .add(await http.MultipartFile.fromPath('audio', _audioFilePath!));

      print("오디오 전송 중...");
      var response = await request.send();
      if (response.statusCode == 200) {
        _audioSent = true; // 오디오 전송 후 플래그 설정
        // 전송 후 파일 삭제
        File(_audioFilePath!).deleteSync();
        print("오디오 전송 성공");
      } else {
        print('Failed to upload audio: ${response.statusCode}');
      }
    } catch (e) {
      print('Error uploading audio: $e');
    }
  }

  void stopFrameCapture() {
    _frameCaptureTimer?.cancel();
  }

  @override
  Future<void> dispose() async {
    _frameCaptureTimer?.cancel();
    _recorderSubscription?.cancel();
    renderer.dispose();
    await super.dispose();
  }
}
