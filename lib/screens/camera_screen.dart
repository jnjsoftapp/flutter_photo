import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import 'package:native_exif/native_exif.dart';
import 'package:permission_handler/permission_handler.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async' show unawaited;

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    // 모든 필요한 권한 요청
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.location,
    ].request();

    if (statuses[Permission.camera]!.isDenied ||
        statuses[Permission.location]!.isDenied) {
      print('카메라 또는 위치 권한이 거부되었습니다.');
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      _controller = CameraController(
        cameras[0],
        ResolutionPreset.max,
        enableAudio: false,
      );

      // 카메라 초기화 후 방향 설정
      await _controller?.initialize();
      await _controller?.lockCaptureOrientation(DeviceOrientation.portraitUp);

      if (mounted) {
        setState(() => _isReady = true);
      }
    } catch (e) {
      print('카메라 초기화 실패: $e');
    }
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      // 사진 촬영 전 카메라 초점 맞추기
      await _controller!.setFocusMode(FocusMode.auto);

      // 위치 정보 가져오기 (병렬 처리)
      final Future<Position> positionFuture = Geolocator.getCurrentPosition();

      // 사진 촬영
      final XFile picture = await _controller!.takePicture();

      // 위치 정보 대기
      final position = await positionFuture;

      // 화면 이동 (카메라 리소스 정리 전)
      if (mounted) {
        // 시스템 UI 복원
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.manual,
          overlays: SystemUiOverlay.values,
        );

        // 홈 스크린으로 이동 (pushReplacement 대신 pop 사용)
        Navigator.of(context).popUntil((route) => route.isFirst);
      }

      // 백그라운드에서 사진 저장 처리
      unawaited(_savePicture(picture, position));
    } catch (e) {
      print('사진 촬영 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('사진 촬영에 실패했습니다')),
        );
      }
    }
  }

  // 사진 저장 프로세스를 별도 메서드로 분리
  Future<void> _savePicture(XFile picture, Position position) async {
    try {
      // 저장 경로 설정
      final directory = await getApplicationDocumentsDirectory();
      final String fileName = path.basename(picture.path);
      final String filePath = path.join(directory.path, fileName);

      // 파일 복사
      await File(picture.path).copy(filePath); // copySync 대신 비동기 copy 사용

      // EXIF 데이터 저장
      final exif = await Exif.fromPath(filePath);
      await exif.writeAttributes({
        "GPSLatitude": position.latitude.toString(),
        "GPSLongitude": position.longitude.toString(),
        "GPSLatitudeRef": position.latitude >= 0 ? "N" : "S",
        "GPSLongitudeRef": position.longitude >= 0 ? "E" : "W",
      });
      await exif.close();
    } catch (e) {
      print('사진 저장 실패: $e');
    }
  }

  @override
  void dispose() {
    // dispose 전에 약간의 지연을 주어 진행 중인 작업이 완료되도록 함
    Future.delayed(Duration(milliseconds: 100), () {
      _controller?.dispose();
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 상태바와 네비게이션바 숨기기
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersive,
      overlays: [], // 모든 시스템 UI 숨기기
    );

    final size = MediaQuery.of(context).size;
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    return Scaffold(
      // AppBar 제거
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 카메라 프리뷰
          Container(
            width: size.width,
            height: size.height,
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: size.width,
                height: size.width * _controller!.value.aspectRatio,
                child: RotatedBox(
                  quarterTurns: isPortrait ? 0 : 1,
                  child: CameraPreview(_controller!),
                ),
              ),
            ),
          ),
          // 뒤로가기 버튼 추가
          Positioned(
            top: 40,
            left: 16,
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                // 화면 종료 시 시스템 UI 다시 표시
                SystemChrome.setEnabledSystemUIMode(
                  SystemUiMode.manual,
                  overlays: SystemUiOverlay.values,
                );
                Navigator.pop(context);
              },
            ),
          ),
          // 촬영 버튼
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: _takePicture,
                  child: const Text('사진 촬영'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
