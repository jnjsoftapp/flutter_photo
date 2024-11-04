import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:native_exif/native_exif.dart';
import 'dart:io';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  List<Map<String, dynamic>> _images = [];

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    final directory = await getApplicationDocumentsDirectory();
    final List<FileSystemEntity> files = directory.listSync();

    List<Map<String, dynamic>> images = [];

    for (var file in files) {
      if (file.path.endsWith('.jpg')) {
        try {
          final exif = await Exif.fromPath(file.path);
          final tags = await exif.getAttributes();

          images.add({
            'path': file.path,
            'datetime': tags?['DateTime'] ?? '시간 정보 없음',
            'latitude': tags?['GPSLatitude'] ?? '위도 정보 없음',
            'latitudeRef': tags?['GPSLatitudeRef'] ?? '',
            'longitude': tags?['GPSLongitude'] ?? '경도 정보 없음',
            'longitudeRef': tags?['GPSLongitudeRef'] ?? '',
          });
        } catch (e) {
          print('이미지 로드 실패: $e');
        }
      }
    }

    setState(() {
      _images = images;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('사진 목록')),
      body: ListView.builder(
        itemCount: _images.length,
        itemBuilder: (context, index) {
          final image = _images[index];
          return Card(
            margin: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Image.file(
                  File(image['path']),
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('촬영 시간: ${image['datetime']}'),
                      Text('위치: ${image['latitudeRef']} ${image['latitude']}, '
                          '${image['longitudeRef']} ${image['longitude']}'),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
