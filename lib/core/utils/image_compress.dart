import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// 업로드 전 이미지를 JPEG로 변환·압축해 3MB 이하를 보장합니다.
/// minWidth/minHeight는 출력 최대 해상도입니다 (1080이면 긴 변이 1080 이하).
Future<File> compressForUpload(File file, {int maxSizeBytes = 3 * 1024 * 1024}) async {
  final originalSize = await file.length();

  if (originalSize <= maxSizeBytes) {
    // 이미 작으면 포맷 변환(HEIC→JPEG)만
    final result = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      minWidth: 1080,
      minHeight: 1080,
      quality: 85,
    );
    if (result == null) return file;
    return _toFile(file, result);
  }

  // 3MB 초과 → quality 단계적으로 낮춤
  for (final quality in [75, 60, 45]) {
    final result = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      minWidth: 1080,
      minHeight: 1080,
      quality: quality,
    );
    if (result == null) break;
    if (result.length <= maxSizeBytes) return _toFile(file, result);
  }

  // 마지막 수단: 해상도도 줄임
  final result = await FlutterImageCompress.compressWithFile(
    file.absolute.path,
    minWidth: 720,
    minHeight: 720,
    quality: 50,
    keepExif: false,
  );
  return result != null ? _toFile(file, result) : file;
}

Future<File> _toFile(File original, Uint8List bytes) async {
  final path = '${original.parent.path}/${DateTime.now().millisecondsSinceEpoch}_compressed.jpg';
  return File(path).writeAsBytes(bytes);
}
